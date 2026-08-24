# Notepad for macOS v1.2.8

Closing the last tab now closes the window, like Notepad on Windows 11. Before, it looked as though nothing happened.

마지막 탭을 닫으면 창이 닫힙니다(Windows 11 메모장과 동일). 이전에는 아무 일도 일어나지 않는 것처럼 보였습니다.

**Download:** [Notepad-v1.2.8.pkg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.8) — recommended · [Notepad-v1.2.8.dmg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.8)
**Site:** https://kimmingul.github.io/NotepadforMacOS/

---

## English

### Fixed
- **The last tab would not close.** With a single Untitled tab open, clicking the tab's close button appeared to do nothing: the tab was removed and an identical empty tab was created in its place. Closing the last tab now closes the window, and quitting follows when it was the last window — the behaviour of Notepad on Windows 11.

  Closing a tab when others remain is unchanged: only that tab goes and the neighbouring tab is selected.

  If the last tab has unsaved text you are still asked to save first, and choosing not to save no longer leaves that text behind in the restored session.

### Verified
- Driven through the real interface, not only unit tests: one Untitled tab, click the tab's close button, the application quits. Three tabs, click a tab's close button, two remain and the application keeps running.
- 123 unit tests.

### Version
- Marketing version: **1.2.8**
- Build: **13**

---

## 한국어

### 수정
- **마지막 탭이 닫히지 않던 문제.** '제목 없음' 탭 하나만 열린 상태에서 탭의 닫기 버튼을 누르면 아무 일도 일어나지 않는 것처럼 보였습니다. 실제로는 탭을 지운 뒤 똑같이 생긴 빈 탭을 그 자리에 새로 만들고 있었습니다. 이제 마지막 탭을 닫으면 창이 닫히고, 그것이 마지막 창이었다면 앱이 종료됩니다 — Windows 11 메모장과 같은 동작입니다.

  다른 탭이 남아 있을 때 탭을 닫는 동작은 그대로입니다. 해당 탭만 닫히고 인접 탭이 선택됩니다.

  마지막 탭에 저장하지 않은 내용이 있으면 여전히 저장 여부를 먼저 묻고, '저장하지 않음'을 선택한 내용이 복원된 세션에 남지 않습니다.

### 검증
- 단위 테스트만이 아니라 실제 화면을 조작해 확인했습니다. '제목 없음' 탭 1개에서 닫기 버튼 클릭 → 앱 종료. 탭 3개에서 닫기 버튼 클릭 → 2개 남고 앱 유지.
- 단위 테스트 123개 통과.

### 버전
- 표시 버전: **1.2.8**
- 빌드: **13**

---

**Developer:** Min-Gul Kim, MD, PhD — Jeonbuk National University Medical School
License: MIT · © 2026 Min-Gul Kim
