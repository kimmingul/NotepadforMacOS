# Notepad for macOS v1.2.12

Fast cursor navigation shortcuts are now fully supported: `fn + Arrow` keys (Home, End, Page Up, Page Down) move the cursor and extend selections as expected in standard text editors.

빠른 커서 이동 단축키가 기본 지원됩니다: MacBook의 `fn + 화살표` 및 외장 키보드의 Home, End, Page Up, Page Down 키로 줄/문서/페이지 단위 이동 및 선택이 가능합니다.

**Download:** [Notepad-v1.2.12.dmg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.12)  
**Site:** https://kimmingul.github.io/NotepadforMacOS/

---

## English

### Added / Improved
- **Fast cursor navigation with `fn + Arrow` (Home, End, Page Up, Page Down):**
  - `fn + Left Arrow` (Home): Moves the cursor to the beginning of the current line.
  - `fn + Right Arrow` (End): Moves the cursor to the end of the current line.
  - `fn + Shift + Left Arrow` (Shift + Home): Extends text selection to the beginning of the line.
  - `fn + Shift + Right Arrow` (Shift + End): Extends text selection to the end of the line.
  - `fn + Cmd + Left / Right Arrow` (Cmd + Home / End) and `Ctrl + Home / End`: Moves the cursor to the beginning or end of the document.
  - `fn + Cmd + Shift + Left / Right Arrow` and `Ctrl + Shift + Home / End`: Extends selection to the beginning or end of the document.
  - `fn + Up / Down Arrow` (Page Up / Page Down): Scrolls and advances the cursor position by one page.
  - `fn + Shift + Up / Down Arrow` (Shift + Page Up / Page Down): Extends text selection page by page.
- Native macOS cursor shortcuts (`Cmd + Left/Right/Up/Down`, `Option + Left/Right`, `Ctrl + A/E`) remain fully intact and functional.

### Verified
- 147 unit tests covering keyboard navigation, file routing, markdown rendering, encodings, and session management.

### Version
- Marketing version: **1.2.12**
- Build: **17**

---

## 한국어

### 추가 및 개선
- **`fn + 화살표` (Home, End, Page Up, Page Down) 빠른 커서 이동 지원:**
  - `fn + ←` (Home): 커서를 현재 줄의 맨 앞으로 이동합니다.
  - `fn + →` (End): 커서를 현재 줄의 맨 끝으로 이동합니다.
  - `fn + Shift + ←` (Shift + Home): 현재 줄 시작 지점까지 텍스트를 선택합니다.
  - `fn + Shift + →` (Shift + End): 현재 줄 끝 지점까지 텍스트를 선택합니다.
  - `fn + ⌘(Cmd) + ← / →` (Cmd + Home / End) 및 `⌃(Ctrl) + Home / End`: 커서를 문서 맨 처음 또는 맨 끝으로 이동합니다.
  - `fn + ⌘ + Shift + ← / →` 및 `⌃ + Shift + Home / End`: 문서 맨 처음 또는 맨 끝까지 전체 선택합니다.
  - `fn + ↑ / ↓` (Page Up / Page Down): 한 페이지씩 스크롤하며 커서도 함께 이동합니다.
  - `fn + Shift + ↑ / ↓` (Shift + Page Up / Page Down): 페이지 단위로 텍스트 선택을 확장합니다.
- 기존 macOS 표준 단축키(`⌘ + 화살표`, `⌥ + 화살표`, `⌃ + A/E` 등)도 100% 정상 유지됩니다.

### 검증
- 키보드 탐색, 파일 라우팅, 마크다운 렌더링, 인코딩, 세션 복원 등 147개 단위 테스트 통과.

### 버전
- 표시 버전: **1.2.12**
- 빌드: **17**

---

**Developer:** Min-Gul Kim, MD, PhD — Jeonbuk National University Medical School  
License: MIT · © 2026 Min-Gul Kim
