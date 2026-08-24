# Notepad for macOS v1.2.6

Fixes a file that would not open. If a tab could not be restored at launch, opening that file from Finder switched to the blank tab instead of reading it — so that one file stayed empty no matter how many times you opened it.

열리지 않던 파일 문제를 수정했습니다. 실행 시 복원되지 못한 탭이 있으면, Finder에서 그 파일을 열어도 내용을 다시 읽지 않고 빈 탭으로 전환만 했습니다. 그래서 그 파일만 몇 번을 열어도 계속 비어 있었습니다.

**Download:** [Notepad-v1.2.6.pkg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.6) — recommended · [Notepad-v1.2.6.dmg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.6)
**Site:** https://kimmingul.github.io/NotepadforMacOS/

---

## English

### Fixed
- **A single file that refused to open.** Session restore reads each file-backed tab through its security-scoped bookmark. When a tab had no usable bookmark — for example one saved by an older version — the sandbox denied the read and the tab came back empty. Opening that same file from Finder then found the existing tab and merely switched to it, without reading anything, so the document stayed blank forever while every other file opened normally.

  Measured with an instrumented build: `open("…/file.txt", O_RDONLY) = -1` at restore, and no read at all on the later open. A tab that failed to load is now replaced by a freshly read one in the same position, using the access Launch Services grants for that open.

- **Korean and other non-ASCII filenames could open twice.** The check for "this file is already open" compared path strings. The file system hands out decomposed names (NFD) while a path stored in the session may be composed (NFC), so the same file looked like two different ones and got a second tab. Paths are now compared with canonical mapping and symlinks resolved.

### Known limitation
- When a broken tab is replaced this way, minting its read-only bookmark occasionally fails, so after the next relaunch that one tab can come back empty again — opening the file once more fills it in. Every other path stores its bookmark normally.

### Version
- Marketing version: **1.2.6**
- Build: **11**

---

## 한국어

### 수정
- **특정 파일 하나가 열리지 않던 문제.** 세션 복원은 파일 탭마다 보안 스코프 북마크로 내용을 읽습니다. 쓸 수 있는 북마크가 없는 탭(예: 예전 버전이 저장한 탭)은 샌드박스가 읽기를 거부해 빈 상태로 복원됩니다. 그 뒤 Finder에서 같은 파일을 열면 이미 있는 탭을 찾아 **전환만** 하고 내용을 읽지 않아서, 다른 파일은 다 정상인데 그 파일만 계속 빈 화면이었습니다.

  계측 빌드로 측정한 결과: 복원 시 `open("…/file.txt", O_RDONLY) = -1`, 이후 열기에서는 읽기 호출이 아예 없었습니다. 이제 복원에 실패한 탭은 같은 자리에서 새로 읽은 탭으로 교체되며, 그때 Launch Services가 부여한 접근 권한을 사용합니다.

- **한글 등 비ASCII 파일명이 두 번 열리던 문제.** "이미 열려 있는 파일인지" 판단을 경로 문자열 비교로 했습니다. 파일 시스템은 이름을 분해형(NFD)으로 넘기고 세션에 저장된 경로는 조합형(NFC)일 수 있어, 같은 파일이 다른 파일로 보여 탭이 하나 더 생겼습니다. 이제 정규화를 맞추고 심볼릭 링크까지 해소해 비교합니다.

### 알려진 제한
- 이렇게 교체된 탭은 읽기 전용 북마크 발급이 간헐적으로 실패합니다. 그 경우 다음 실행에서 그 탭 하나가 다시 비어 있을 수 있고, 파일을 한 번 더 열면 채워집니다. 다른 경로는 북마크가 정상 저장됩니다.

### 버전
- 표시 버전: **1.2.6**
- 빌드: **11**

---

**Developer:** Min-Gul Kim, MD, PhD — Jeonbuk National University Medical School
License: MIT · © 2026 Min-Gul Kim
