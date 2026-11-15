# 우리 가족 달력

엄마 · 아빠 · 메리 세 사람이 폰으로 함께 쓰는 공유 달력입니다.
지금은 Supabase에 연결되어 있어서, 세 사람이 같은 일정을 함께 봅니다.
가족 비밀번호를 한 번 넣으면 그 폰에서는 다시 묻지 않아요.

- 주소: <https://taetae9595.github.io/family-calendar/>
- 화면 코드는 이 저장소에, **일정 내용은 Supabase에** 따로 저장됩니다.
  가족 비밀번호는 화면 코드에 들어 있지 않고 Supabase에만(암호화된 해시로) 있습니다.

## 1. 먼저 화면만 볼 때 (설치 없이)

`index.html` 파일을 브라우저로 열면 바로 보입니다.
이 단계에서는 일정이 **그 기기의 브라우저(localStorage)에만** 저장되고,
처음 열었을 때 디자인을 보여주려고 넣어 둔 **예시 일정**이 함께 보입니다
(예시 일정은 눌러서 지우면 됩니다).

## 2. 폰 홈 화면에 앱처럼 추가하기

- **안드로이드(Chrome)** — 주소창의 `⋮` → `앱 설치` 또는 `홈 화면에 추가`
- **아이폰(Safari)** — 아래 `공유` 버튼 → `홈 화면에 추가`

추가하면 달력 아이콘이 생기고, 누르면 주소창 없이 앱처럼 열립니다.
(진짜 바탕화면 위젯은 웹으로는 만들 수 없어 홈 화면 아이콘 방식으로 만들었습니다.)

## 3. 세 사람이 같은 일정을 함께 보는 구조 (이미 연결됨)

이 달력은 화면(HTML)과 저장소(Supabase)가 나뉘어 있습니다. 화면 코드는 공개되어 있어도
일정 내용은 가족 비밀번호를 통과해야만 읽을 수 있어서, 링크를 알아도 내용은 보이지 않습니다.

연결은 이미 끝나 있어서 아래는 다시 만들 때를 위한 메모입니다.
지금 연결된 프로젝트: Supabase `family-calendar` (Northeast Asia · Seoul), 주소 `https://tuejokazctxejnpjmwwt.supabase.co`

1. <https://supabase.com> 에서 구글 계정으로 가입 → `New project` (이름은 아무거나, 무료 플랜)
2. 프로젝트가 열리면 왼쪽 `SQL Editor` → `New query` →
   이 폴더의 **`supabase-setup.sql` 전체를 붙여넣고 `RUN`** (맨 아래 한 줄의 비밀번호를 먼저 바꿔 두세요)
3. 왼쪽 `Project Settings` → `API` 에서 두 값을 복사
   - `Project URL` → `index.html` 의 `CONFIG.SUPABASE_URL`
   - `anon public` 키 → `index.html` 의 `CONFIG.SUPABASE_ANON_KEY`
4. `index.html` 을 다시 올리면 끝. 이제 세 사람이 같은 일정을 봅니다.

`CONFIG` 는 `index.html` 맨 아래 `<script>` 의 가장 위에 있습니다.

```js
const CONFIG = {
  SUPABASE_URL: '',            // ← 3번에서 복사한 Project URL
  SUPABASE_ANON_KEY: '',       // ← 3번에서 복사한 anon public 키
  ...
};
```

> `FAMILY_PASSCODE` 는 비워 두세요(이미 빈 값입니다).
> 그러면 비밀번호가 페이지 소스에 남지 않고, Supabase가 서버에서 확인합니다.

## 4. 인터넷에 올려서 링크로 공유하기

폴더(`family-calendar`)를 통째로 올리면 됩니다.

- **Netlify Drop** — <https://app.netlify.com/drop> 에 폴더를 끌어다 놓으면 바로 주소가 생깁니다 (가장 간단)
- **GitHub Pages** — 저장소에 폴더를 올리고 `Settings > Pages` 에서 `main / root` 선택

올린 주소를 가족에게 보내고, 각자 폰에서 한 번 열어 홈 화면에 추가하면 됩니다.

## 5. 가족 비밀번호 바꾸기

- **이 기기 모드** — `index.html` 의 `FAMILY_PASSCODE` 값만 바꾸면 됩니다.
- **Supabase 연결 후(지금 방식)** — `supabase-setup.sql` 맨 아래
  `select private.set_passcode('여기에_가족_비밀번호_입력');` 의 따옴표 안을 새 비밀번호로 바꿔
  SQL Editor에서 다시 실행하면 됩니다. `index.html` 은 그대로 두세요.

비밀번호를 바꾸면 이미 잠금을 풀어 둔 폰도 다시 입력해야 합니다
(상단의 🔒 버튼을 눌러 잠그고 새 비밀번호로 열면 됩니다).

## 6. 파일 설명

| 파일 | 역할 |
| --- | --- |
| `index.html` | 달력 앱 전체 (화면·기능·저장). 고칠 곳은 위쪽 `CONFIG` 뿐입니다. |
| `manifest.json` | 홈 화면에 앱으로 추가할 때 쓰는 정보 |
| `icon.svg`, `icon-192.png`, `icon-512.png`, `apple-touch-icon.png` | 앱 아이콘 |
| `sw.js` | 한 번 열면 인터넷이 약해도 화면이 뜨도록 도와주는 파일 |
| `supabase-setup.sql` | 가족 모두가 같은 일정을 보게 해 주는 저장소 설정 |

## 7. 알아 두면 좋은 점

- 일정은 **가족 비밀번호를 아는 사람만** 볼 수 있습니다.
  Supabase에 저장된 일정은 비밀번호 확인을 통과해야만 읽을 수 있게 잠겨 있어,
  링크를 알아도 비밀번호가 없으면 내용이 보이지 않습니다.
- 비밀번호는 숫자 4자리라 가족끼리만 쓰기 좋지만, 링크를 아주 공개된 곳에 올리는 것은 피해 주세요.
- 화면 코드는 공개 저장소에 있어도 되고, 일정 내용과 비밀번호는 Supabase 안에만 있습니다.
- 인터넷이 끊기면 마지막으로 받아 둔 일정을 보여 주고, 그동안 적은 일정은
  연결이 돌아왔을 때 자동으로 저장소에 반영됩니다.
