# Notepad for macOS v1.2.4

Fixes the Gatekeeper check dialog when opening files from Finder. Opening a document now only reads it — Notepad writes to your file only when you save.

Finder에서 파일을 열 때 Gatekeeper 경고가 뜨던 문제를 수정했습니다. 문서를 열 때는 읽기만 하고, 파일에 쓰는 건 저장할 때뿐입니다.

**Download:** [Notepad-v1.2.4.dmg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.4) (Developer ID signed · notarized)  
**Site:** https://kimmingul.github.io/NotepadforMacOS/

---

## English

### Fixed
- **Gatekeeper check dialog when opening files from Finder.** Reading a document no longer marks it with the `com.apple.quarantine` attribute.

  Notepad used to create a *writable* security-scoped bookmark while opening a document. That Foundation API opens the target file with `O_RDWR` to obtain a write token, and the App Sandbox propagates a quarantine record to any file opened with write intent. The file contents never changed (the modification date stayed the same), but the quarantine attribute stuck to it. From then on, opening that file from Finder — with Notepad *or* TextEdit — showed a Gatekeeper document check dialog, and cancelling it left the file unopened.

  Opening a document now requests a **read-only** security-scoped bookmark, so no write-intent open happens. A writable bookmark is created only after a save succeeds.

### Changed
- The first save of a document that was opened in an earlier launch may ask you to confirm the location once. Sandbox write permission is granted at that point, and later saves go straight to disk.

### Note
- Files that were already marked before this update keep their quarantine attribute. Notepad does not modify attributes on your files.

### Version
- Marketing version: **1.2.4**
- Build: **9**

---

## 한국어

### 수정
- **Finder에서 파일을 열 때 뜨던 Gatekeeper 검사 대화상자.** 문서를 읽기만 해도 `com.apple.quarantine` 속성이 붙던 문제를 고쳤습니다.

  이전에는 문서를 여는 과정에서 *쓰기 가능한* 보안 스코프 북마크를 만들었습니다. 이 Foundation API는 쓰기 토큰을 얻기 위해 대상 파일을 `O_RDWR`로 열고, App Sandbox는 쓰기 의도로 열린 파일에 격리 기록을 전파합니다. 파일 내용은 전혀 바뀌지 않아(수정 날짜도 그대로) 겉보기엔 멀쩡했지만 격리 속성만 남았습니다. 그 뒤로는 그 파일을 Finder에서 열 때마다 — Notepad든 TextEdit이든 — Gatekeeper 문서 검사 대화상자가 뜨고, 취소하면 파일이 열리지 않았습니다.

  이제 문서를 열 때는 **읽기 전용** 보안 스코프 북마크를 요청하므로 쓰기 의도 open이 발생하지 않습니다. 쓰기 가능 북마크는 저장이 성공한 뒤에만 만듭니다.

### 변경
- 이전 실행에서 열어둔 문서를 다시 실행한 뒤 **처음 저장**할 때, 위치를 한 번 확인하는 저장 패널이 나올 수 있습니다. 그 시점에 샌드박스 쓰기 권한이 부여되며, 이후 저장은 패널 없이 바로 진행됩니다.

### 참고
- 이번 업데이트 이전에 이미 격리 속성이 붙은 파일은 그대로 남습니다. Notepad는 사용자 파일의 속성을 건드리지 않습니다.

### 버전
- 표시 버전: **1.2.4**
- 빌드: **9**

---

**Developer:** Min-Gul Kim, MD, PhD — Jeonbuk National University Medical School  
License: MIT · © 2026 Min-Gul Kim
