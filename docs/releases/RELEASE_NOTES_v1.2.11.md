# Notepad for macOS v1.2.11

Opening a document from Finder while Notepad is closed no longer shows extra empty windows beside the file's window.

메모장이 꺼진 상태에서 Finder로 문서를 열어도 파일 창 옆에 빈 창이 더 생기지 않습니다.

**Download:** [Notepad-v1.2.11.dmg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.11)
**Site:** https://kimmingul.github.io/NotepadforMacOS/

---

## English

### Fixed
- **Launching Notepad by opening a document showed three windows: two empty and one with the file.** (Reported against v1.2.10.) Two causes, both in the launch path.

  v1.2.10 started listening for document-open events only after the first window existed. On a cold launch that was too late: SwiftUI had already answered the event by creating a window of its own, beside the default one. The event handler is now installed before the app finishes launching, so the framework never creates a document window. A document launch then produces no window at all — SwiftUI expects the event to make one — so Notepad asks the system to reopen it, which creates the single default window, and the document lands in it as a tab.

  The second empty window was Notepad's own doing: a fallback that opens a window when "no window is on screen" fired in the brief gap between a window's view appearing and its attachment to a real window. It now fires only when no editor window is known at all.

- **The restorable session could be handed to a window that never appeared.** SwiftUI can build a window's state without showing it. If that instance took the session that is restored on the next launch, nothing kept it current, and a file opened from Finder could be written to a session that is never restored. Every window now starts on its own session, and the first window that actually reaches the screen adopts the restorable one — with its tabs and unsaved text.

### Verified
- Driven through the real interface, five clean runs each, on the reporter's exact sequence: launch with a saved session → open a document from Finder → close every tab (the app quits) → open a document from Finder again. Result each time: **one window, one tab**.
- Cold launch with two documents: one window, two tabs. Document launch onto a session with unsaved text: one window, the unsaved tab kept, the document beside it. Opening while running, reopening a file another window holds, `.png`, New Window, quit-on-last-window, session restore on/off — all as in v1.2.10.
- 137 unit tests.

### Version
- Marketing version: **1.2.11**
- Build: **16**

---

## 한국어

### 수정
- **문서를 열어 메모장을 시작하면 창이 3개 나타나던 문제(빈 창 2개 + 파일 창 1개).** v1.2.10에 대한 보고입니다. 원인은 실행 경로에 둘 있었습니다.

  v1.2.10은 첫 창이 생긴 **뒤에야** 문서 열기 이벤트를 받기 시작했습니다. 콜드 런치에서는 그때 이미 SwiftUI가 이벤트에 응답해 기본 창 옆에 창을 하나 더 만든 뒤였습니다. 이제 앱이 실행을 마치기 전에 핸들러를 설치해 프레임워크가 문서 창을 만들지 못하게 합니다. 그러면 문서로 시작할 때 창이 하나도 만들어지지 않으므로(SwiftUI는 이벤트가 창을 만들 거라 기대합니다) 메모장이 시스템에 자신을 reopen 해 달라고 요청해 기본 창 하나를 만들고, 문서는 그 창의 탭으로 들어갑니다.

  두 번째 빈 창은 메모장 자체의 문제였습니다. "화면에 창이 없으면 창을 연다"는 보조 경로가, 창의 뷰가 나타난 뒤 실제 창에 붙기까지의 짧은 틈에 실행됐습니다. 이제 편집기 창이 하나도 알려져 있지 않을 때만 동작합니다.

- **복원 대상 세션이 화면에 뜨지 않은 창에 배정될 수 있던 문제.** SwiftUI는 창의 상태만 만들고 띄우지 않는 경우가 있습니다. 그 인스턴스가 다음 실행에 복원될 세션을 차지하면 아무 창도 그 세션을 갱신하지 않고, Finder로 연 파일이 복원되지 않는 세션에 기록될 수 있었습니다. 이제 모든 창은 자기 세션으로 시작하고, 실제로 화면에 뜬 첫 창이 복원 대상 세션을 — 탭과 미저장 내용까지 — 넘겨받습니다.

### 검증
- 보고해 주신 순서 그대로 실제 화면을 조작해 깨끗한 상태에서 5회씩 확인했습니다: 저장된 세션으로 실행 → Finder에서 문서 열기 → 탭 전부 닫기(앱 종료) → 다시 Finder에서 문서 열기. 매번 **창 1개, 탭 1개**.
- 문서 2개로 콜드 런치 → 창 1개 탭 2개. 미저장 내용이 있는 세션에 문서로 시작 → 창 1개, 미저장 탭 유지 + 문서 탭. 실행 중 열기, 다른 창이 가진 파일 다시 열기, `.png`, New Window, 마지막 창 닫으면 종료, 세션 복원 켬/끔 — v1.2.10과 동일.
- 단위 테스트 137개.

### 버전
- 표시 버전: **1.2.11**
- 빌드: **16**

---

**Developer:** Min-Gul Kim, MD, PhD — Jeonbuk National University Medical School
License: MIT · © 2026 Min-Gul Kim
