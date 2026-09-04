# Notepad for macOS v1.2.10

Opening a file from Finder while Notepad is running now adds a tab to the window you are using, instead of opening a second window with a copy of every tab.

메모장이 실행 중일 때 Finder에서 파일을 열면, 탭이 복제된 새 창이 아니라 지금 쓰고 있는 창의 새 탭으로 열립니다.

**Download:** [Notepad-v1.2.10.pkg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.10) — recommended · [Notepad-v1.2.10.dmg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.10)
**Site:** https://kimmingul.github.io/NotepadforMacOS/

---

## English

### Fixed
- **Opening a file from Finder created a second window that showed a copy of every open tab.** Notepad is a tabbed editor, so a file handed over by Finder belongs in a tab of the window you are already using.

  Two faults were stacked here. SwiftUI's window group answers a document-open event by creating a *new window*, so no routing logic could prevent it — measured directly: opening a `.png`, a type Notepad never opens, still added an empty window. Notepad now receives the document-open Apple Event itself, so no window is created and the file lands in the front window as a tab.

  The new window also carried no window value, which made it reuse the *first* window's session directory. That is why every tab reappeared, and why two windows then wrote the same `session.json` in turn — the last writer won, so tabs could vanish and a save-authorised bookmark could be reverted to read-only (the re-authorisation panel would reappear on the next launch). Each window now owns its own session, and only one window owns the session that is restored on the next launch.

- **The same file could be open in two windows at once.** Duplicate detection only looked inside a single window, so two windows could edit one file and the save order decided what ended up on disk. Detection is now app-wide: opening a file that another window already has switches to that window and brings it to the front. Files are matched by filesystem identity, so two files with the same name in different folders are still different files.

- **A restored session could end up owned by no window.** SwiftUI can build a window's state and then never show that window. If that instance claimed the restorable session, nothing kept it up to date and a file opened from Finder was written to a session that is never restored. The session is now handed to a window that is actually on screen.

### Verified
- Driven through the real interface with the accessibility API, five consecutive runs from a clean state per scenario: opening a file while running adds a tab with **no** change in window count; reopening a file that another window holds adds no tab and brings that window forward; opening two files at once yields two tabs in one window; opening a `.png` does nothing; closing the last tab closes the window and quitting follows for the last window; the restored session holds every tab.
- 136 unit tests (nine new: session ownership, same-name-different-folder matching, and the rules that protect a window holding unsaved text).

### Known
- Launching Notepad by opening a document from Finder can still leave one empty window beside the file's window. Closing it programmatically was implemented and then withdrawn: it races with document routing, and one measured run lost the opened file entirely. An extra empty window is preferable to a file that silently fails to open.

### Version
- Marketing version: **1.2.10**
- Build: **15**

---

## 한국어

### 수정
- **Finder에서 파일을 열면 기존 탭이 전부 복제된 새 창이 열리던 문제.** 이 앱은 다중 탭 편집기이므로 Finder가 넘긴 파일은 지금 쓰고 있는 창의 탭이어야 합니다.

  원인이 두 겹이었습니다. SwiftUI의 창 그룹이 문서 열기 이벤트에 **새 창을 만들어** 응답하기 때문에, 앱의 라우팅 코드로는 막을 수 없었습니다(실측: 이 앱이 열지도 않는 `.png`를 Finder에서 열어도 빈 창이 하나 늘었습니다). 이제 문서 열기 Apple Event를 앱이 직접 받아서 창을 만들지 않고 최전면 창의 탭으로 엽니다.

  또한 그 새 창에는 창 값이 없어서 **첫 창의 세션 디렉터리를 그대로 다시 복원**했습니다. 기존 탭이 전부 다시 보인 이유이고, 그 뒤로 두 창이 같은 `session.json`에 번갈아 써서 마지막에 쓴 창이 이겼습니다. 그래서 탭이 사라지거나, 저장 승인으로 얻은 쓰기 권한 북마크가 읽기 전용으로 되돌아가(다음 실행의 첫 저장에서 재승인 패널이 다시 뜨는) 문제로 이어졌습니다. 이제 창마다 자기 세션을 갖고, 다음 실행에서 복원되는 세션은 한 창만 소유합니다.

- **같은 파일이 두 창에 동시에 열릴 수 있던 문제.** 중복 감지가 한 창 안에서만 동작해, 두 창이 같은 파일을 각자 편집하고 저장 순서가 디스크 내용을 결정했습니다. 이제 앱 전체에서 감지합니다. 다른 창이 이미 가진 파일을 열면 그 창으로 전환하고 앞으로 가져옵니다. 같은 파일 판정은 파일 시스템 신원 기준이므로, **이름이 같아도 폴더가 다르면 다른 파일**입니다.

- **복원 대상 세션의 주인이 없어질 수 있던 문제.** SwiftUI는 창의 상태만 만들고 그 창을 띄우지 않는 경우가 있습니다. 그 인스턴스가 복원 대상 세션을 차지하면 아무 창도 그 세션을 갱신하지 않고, Finder로 연 파일이 복원되지 않는 세션에 기록됐습니다. 이제 실제로 화면에 뜬 창이 그 세션을 넘겨받습니다.

### 검증
- 접근성 API로 실제 화면을 조작해, 시나리오마다 깨끗한 상태에서 5회 연속 확인했습니다. 실행 중 파일 열기 → 창 수 변화 **없음**, 탭만 추가 / 다른 창이 가진 파일 다시 열기 → 탭 중복 없이 그 창이 앞으로 / 파일 두 개 동시 열기 → 한 창에 탭 두 개 / `.png` 열기 → 아무 변화 없음 / 마지막 탭 닫기 → 창 닫힘, 마지막 창이면 앱 종료 / 재실행 → 세션의 모든 탭 복원.
- 단위 테스트 136개 통과(신규 9개: 세션 소유권, 같은 이름 다른 폴더 구분, 미저장 내용이 있는 창을 보호하는 규칙).

### 알려진 사항
- Finder에서 문서를 열어 앱이 시작되는 경우, 파일 창 옆에 빈 창이 하나 남을 수 있습니다. 이 창을 프로그램으로 닫는 처리를 구현했다가 철회했습니다. 문서 라우팅과 경합해서, 측정 중 한 번은 연 파일이 아예 열리지 않았습니다. 빈 창이 하나 남는 편이 파일을 잃는 것보다 낫습니다.

### 버전
- 표시 버전: **1.2.10**
- 빌드: **15**

---

**Developer:** Min-Gul Kim, MD, PhD — Jeonbuk National University Medical School
License: MIT · © 2026 Min-Gul Kim
