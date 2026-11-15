-- ============================================================================
--  우리 가족 달력 · Supabase 설정
-- ----------------------------------------------------------------------------
--  사용법
--   1) https://supabase.com 에서 새 프로젝트를 만듭니다 (무료).
--   2) 왼쪽 메뉴 SQL Editor > New query 에 이 파일 전체를 붙여넣고 RUN.
--   3) Project Settings > API 에서
--        Project URL   -> index.html 의 CONFIG.SUPABASE_URL
--        anon public   -> index.html 의 CONFIG.SUPABASE_ANON_KEY
--      에 넣으면 끝입니다. (앱 > 설정 > API keys 의 anon/publishable key)
--   4) 가족 비밀번호를 바꾸려면 맨 아래 set_passcode 한 줄만 고쳐 다시 RUN.
--
--  보안 구조
--   · anon 키로는 public.schedules 테이블을 직접 읽거나 쓸 수 없습니다.
--     (RLS 켜짐 + 정책 없음 + 테이블 권한 회수)
--   · 일정 조회/저장/삭제는 아래 RPC 함수로만 가능하고, 모든 함수는
--     먼저 가족 비밀번호를 검증합니다 (bcrypt 해시와 비교).
--   · 따라서 가족 비밀번호를 모르면 anon 키가 노출되어도 일정을 볼 수 없습니다.
--   · 비밀번호는 DB에 해시로만 저장됩니다.
-- ============================================================================

-- 1) 암호화 확장 -------------------------------------------------------------
create extension if not exists pgcrypto with schema extensions;

-- 2) 비밀 정보 전용 스키마 ---------------------------------------------------
create schema if not exists private;
revoke all on schema private from public;
revoke all on schema private from anon, authenticated;

create table if not exists private.family_secrets (
  family_id     text primary key,
  passcode_hash text not null,
  updated_at    timestamptz not null default now()
);

revoke all on table private.family_secrets from public, anon, authenticated;

-- 3) 일정 테이블 -------------------------------------------------------------
create table if not exists public.schedules (
  id         uuid primary key default gen_random_uuid(),
  family_id  text not null default 'family',
  author     text not null check (author in ('mom', 'dad', 'meri')),
  title      text not null check (char_length(btrim(title)) between 1 and 60),
  event_date date not null,
  event_time time,
  memo       text check (char_length(memo) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists schedules_family_date_idx
  on public.schedules (family_id, event_date, event_time);

-- RLS를 켜고 정책을 하나도 만들지 않습니다 => anon/authenticated 는 직접 접근 불가
alter table public.schedules enable row level security;
revoke all on table public.schedules from public, anon, authenticated;

-- 4) 비밀번호 검증 (내부용) --------------------------------------------------
create or replace function private.check_passcode(p_family_id text, p_passcode text)
returns boolean
language sql
security definer
set search_path = private, extensions, pg_catalog
as $$
  select exists (
    select 1
      from private.family_secrets s
     where s.family_id = p_family_id
       and p_passcode is not null
       and s.passcode_hash = extensions.crypt(p_passcode, s.passcode_hash)
  );
$$;

revoke all on function private.check_passcode(text, text) from public, anon, authenticated;

-- 5) 앱이 부르는 함수들 (public) --------------------------------------------
-- 5-1) 비밀번호 확인
create or replace function public.family_unlock(
  p_passcode  text,
  p_family_id text default 'family'
)
returns boolean
language sql
security definer
set search_path = private, public, extensions, pg_catalog
as $$
  select private.check_passcode(p_family_id, p_passcode);
$$;

-- 5-2) 일정 전체 읽기
create or replace function public.family_load_schedules(
  p_passcode  text,
  p_family_id text default 'family'
)
returns jsonb
language plpgsql
security definer
set search_path = private, public, extensions, pg_catalog
as $$
declare
  v_items jsonb;
begin
  if not private.check_passcode(p_family_id, p_passcode) then
    raise exception '가족 비밀번호가 달라요.' using errcode = '28000';
  end if;

  select coalesce(
           jsonb_agg(to_jsonb(t) order by t.event_date, t.event_time nulls last, t.created_at),
           '[]'::jsonb
         )
    into v_items
    from public.schedules t
   where t.family_id = p_family_id;

  return jsonb_build_object('items', v_items);
end;
$$;

-- 5-3) 일정 저장 (새 일정 / 수정 모두)
create or replace function public.family_save_schedule(
  p_passcode   text,
  p_id         uuid,
  p_author     text,
  p_title      text,
  p_event_date date,
  p_event_time time default null,
  p_memo       text default null,
  p_family_id  text default 'family'
)
returns jsonb
language plpgsql
security definer
set search_path = private, public, extensions, pg_catalog
as $$
declare
  v_row public.schedules;
  v_memo text;
begin
  if not private.check_passcode(p_family_id, p_passcode) then
    raise exception '가족 비밀번호가 달라요.' using errcode = '28000';
  end if;

  if p_author is null or p_author not in ('mom', 'dad', 'meri') then
    raise exception '작성자를 확인해 주세요.' using errcode = '22023';
  end if;

  if p_title is null or char_length(btrim(p_title)) = 0 then
    raise exception '일정 제목을 입력해 주세요.' using errcode = '22023';
  end if;

  v_memo := nullif(btrim(coalesce(p_memo, '')), '');

  if p_id is null then
    insert into public.schedules (family_id, author, title, event_date, event_time, memo)
    values (p_family_id, p_author, btrim(p_title), p_event_date, p_event_time, v_memo)
    returning * into v_row;
  else
    update public.schedules s
       set author     = p_author,
           title      = btrim(p_title),
           event_date = p_event_date,
           event_time = p_event_time,
           memo       = v_memo,
           updated_at = now()
     where s.id = p_id
       and s.family_id = p_family_id
    returning * into v_row;

    if not found then
      insert into public.schedules (id, family_id, author, title, event_date, event_time, memo)
      values (p_id, p_family_id, p_author, btrim(p_title), p_event_date, p_event_time, v_memo)
      returning * into v_row;
    end if;
  end if;

  return to_jsonb(v_row);
end;
$$;

-- 5-4) 일정 삭제
create or replace function public.family_delete_schedule(
  p_passcode  text,
  p_id        uuid,
  p_family_id text default 'family'
)
returns jsonb
language plpgsql
security definer
set search_path = private, public, extensions, pg_catalog
as $$
declare
  v_deleted boolean := false;
begin
  if not private.check_passcode(p_family_id, p_passcode) then
    raise exception '가족 비밀번호가 달라요.' using errcode = '28000';
  end if;

  delete from public.schedules s
   where s.id = p_id
     and s.family_id = p_family_id;

  v_deleted := found;

  return jsonb_build_object('deleted', v_deleted);
end;
$$;

-- 6) 앱(anon 키)에 함수 실행 권한만 부여 --------------------------------------
revoke all on function public.family_unlock(text, text) from public;
revoke all on function public.family_load_schedules(text, text) from public;
revoke all on function public.family_save_schedule(text, uuid, text, text, date, time, text, text) from public;
revoke all on function public.family_delete_schedule(text, uuid, text) from public;

grant execute on function public.family_unlock(text, text) to anon, authenticated;
grant execute on function public.family_load_schedules(text, text) to anon, authenticated;
grant execute on function public.family_save_schedule(text, uuid, text, text, date, time, text, text) to anon, authenticated;
grant execute on function public.family_delete_schedule(text, uuid, text) to anon, authenticated;

-- 7) 가족 비밀번호 설정 ------------------------------------------------------
create or replace function private.set_passcode(
  p_passcode  text,
  p_family_id text default 'family'
)
returns void
language sql
security definer
set search_path = private, extensions, pg_catalog
as $$
  insert into private.family_secrets (family_id, passcode_hash, updated_at)
  values (p_family_id, extensions.crypt(p_passcode, extensions.gen_salt('bf', 10)), now())
  on conflict (family_id) do update
     set passcode_hash = excluded.passcode_hash,
         updated_at    = now();
$$;

revoke all on function private.set_passcode(text, text) from public, anon, authenticated;

-- ↓↓↓ 아래 한 줄의 '여기에_가족_비밀번호_입력' 을 우리 가족만 아는 비밀번호로 바꿔 실행하세요 ↓↓↓
select private.set_passcode('여기에_가족_비밀번호_입력');

-- 나중에 비밀번호를 바꾸고 싶으면 위 한 줄만 고쳐서 다시 실행하면 됩니다.

-- ----------------------------------------------------------------------------
-- 확인용 (선택): 아래 주석을 풀고 실행하면 설정이 잘 됐는지 볼 수 있습니다.
--   select public.family_unlock('여기에_가족_비밀번호_입력');          -- true 가 나오면 정상
--   select public.family_load_schedules('여기에_가족_비밀번호_입력');  -- {"items": []} 가 나오면 정상
-- ----------------------------------------------------------------------------
