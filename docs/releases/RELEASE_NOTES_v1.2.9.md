# Notepad for macOS v1.2.9

Opening a file no longer leaves an empty Untitled tab beside it.

파일을 열 때 빈 '제목 없음' 탭이 함께 남지 않습니다.

**Download:** [Notepad-v1.2.9.pkg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.9) — recommended · [Notepad-v1.2.9.dmg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.9)
**Site:** https://kimmingul.github.io/NotepadforMacOS/

---

## English

### Fixed
- **An empty Untitled tab appeared next to a file opened from Finder.** After closing every tab, opening `A.txt` gave two tabs: an empty **Untitled** and **A.txt**.

  A window with no session to restore always starts with one empty Untitled tab. The document handed over by Finder then arrived as a second tab, and the placeholder stayed. Opening a file now takes that placeholder's place when it is the only tab and nothing has been typed into it.

  A tab you typed into is never discarded, and an empty tab you created yourself while other tabs are open stays where it is.

### Verified
- Driven through the real interface: with no session to restore, opening `A.txt` from Finder gives exactly one tab, `A.txt`, with the file's text loaded.
- 127 unit tests, four of them covering the placeholder rules.

### Version
- Marketing version: **1.2.9**
- Build: **14**

---

## 한국어

### 수정
- **Finder에서 연 파일 옆에 빈 '제목 없음' 탭이 생기던 문제.** 모든 탭을 닫은 뒤 `A.txt`를 열면 빈 **'제목 없음'** 탭과 **A.txt** 탭 두 개가 생겼습니다.

  복원할 세션이 없는 창은 항상 빈 '제목 없음' 탭 하나로 시작합니다. 그 뒤 Finder가 넘긴 문서가 두 번째 탭으로 들어오면서 자리표시자가 그대로 남았습니다. 이제 파일을 열 때, 그 탭이 유일한 탭이고 아무 것도 입력되지 않았다면 그 자리를 대신 씁니다.

  입력한 내용이 있는 탭은 버리지 않으며, 다른 탭이 열려 있는 상태에서 직접 만든 빈 탭도 그대로 유지됩니다.

### 검증
- 실제 화면을 조작해 확인했습니다. 복원할 세션이 없는 상태에서 Finder로 `A.txt`를 열면 탭은 `A.txt` 하나이며 파일 내용이 로드됩니다.
- 단위 테스트 127개 통과(자리표시자 규칙 4개 포함).

### 버전
- 표시 버전: **1.2.9**
- 빌드: **14**

---

**Developer:** Min-Gul Kim, MD, PhD — Jeonbuk National University Medical School
License: MIT · © 2026 Min-Gul Kim
