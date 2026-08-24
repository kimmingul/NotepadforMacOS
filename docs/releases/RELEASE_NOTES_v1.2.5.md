# Notepad for macOS v1.2.5

Adds a signed installer package. Installing from the `.pkg` leaves the app without a quarantine record, so macOS stops running its Gatekeeper quarantine check when you open documents.

서명된 설치 패키지를 추가했습니다. `.pkg`로 설치하면 앱에 격리 기록이 남지 않아, 문서를 열 때 macOS가 Gatekeeper 격리 검사를 돌리지 않습니다.

**Download:** [Notepad-v1.2.5.pkg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.5) — recommended · [Notepad-v1.2.5.dmg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.5)
**Site:** https://kimmingul.github.io/NotepadforMacOS/

---

## English

### Added
- **Installer package (`.pkg`), Developer ID signed, notarized, stapled.** Prefer it over the DMG.

  A browser marks whatever it downloads with `com.apple.quarantine`. With a drag-install DMG that record travels onto the copy you drop into Applications, so the app bundle itself stays quarantined — macOS then runs its quarantine resolver every time the app is asked to open a document, and a copy left inside the DMG or in Downloads can be App-Translocated to a fresh random path, which stops your approval from ever sticking. Only the `.pkg` file itself receives the download record; the app that `installd` writes to Applications does not, and it always lands at one stable path.

  Verify after installing:
  ```
  xattr -p com.apple.quarantine /Applications/Notepad.app   # expect: no such xattr
  ```

### Fixed
- Save failures are now told apart. A failed write used to be reported as "needs authorization" whenever the tab held a read-only bookmark, so a full disk opened a pointless save panel instead of showing the error. The outcome is now decided from the actual error and an `access(2)` writability check.
- The re-authorization save panel explains itself. Confirming the location once lets later saves go straight to disk.

### Note
- Documents that were marked before v1.2.4 keep their quarantine record, and Finder keeps asking to check them — with any app, Notepad or TextEdit. v1.2.4 stopped Notepad from adding new records; it does not remove existing ones. To see which of your files still carry one:
  ```
  find ~/Documents ~/Desktop -type f \( -name '*.md' -o -name '*.txt' \) -print0 \
  | xargs -0 -I{} sh -c 'v=$(xattr -p com.apple.quarantine "{}" 2>/dev/null); case "$v" in *Notepad*) echo "$v  {}";; esac'
  ```
- Saving a file still adds a quarantine record. Every sandboxed third-party app does this; it is macOS behavior, not a choice Notepad makes.

### Version
- Marketing version: **1.2.5**
- Build: **10**

---

## 한국어

### 추가
- **설치 패키지(`.pkg`)** — Developer ID 서명 · 공증 · 스테이플 완료. DMG보다 이쪽을 권장합니다.

  브라우저는 다운로드한 파일에 `com.apple.quarantine`을 붙입니다. DMG를 드래그해서 설치하면 그 기록이 응용 프로그램으로 옮긴 사본에 그대로 따라붙어, 앱 번들이 격리 상태로 남습니다. 그러면 문서를 열 때마다 macOS가 격리 해석기를 돌리고, DMG 안이나 다운로드 폴더에 남은 사본은 App Translocation으로 매번 임의 경로에 실행돼 승인이 축적되지 않습니다. `.pkg`는 패키지 파일 자체에만 기록이 붙고, `installd`가 응용 프로그램에 배치하는 앱에는 붙지 않으며 항상 같은 경로에 놓입니다.

  설치 후 확인:
  ```
  xattr -p com.apple.quarantine /Applications/Notepad.app   # 아무것도 안 나와야 정상
  ```

### 수정
- 저장 실패 원인을 구분합니다. 이전에는 읽기 전용 북마크를 가진 탭에서 쓰기가 실패하면 원인 불문 "재승인 필요"로 처리해, 디스크가 꽉 찬 상황에서도 엉뚱한 저장 패널이 떴습니다. 이제 실제 오류와 `access(2)` 쓰기 권한 확인으로 판정합니다.
- 재승인 저장 패널이 이유를 설명합니다. 위치를 한 번 확인하면 다음 저장부터는 바로 저장됩니다.

### 참고
- v1.2.4 이전에 격리 기록이 붙은 문서는 그대로 남아 있어, Finder에서 열 때 계속 검사 확인이 뜹니다 — Notepad든 텍스트 편집기든 마찬가지입니다. v1.2.4는 새 기록이 생기지 않게 막은 것이고, 이미 붙은 기록을 지우지는 않습니다. 어떤 파일에 남아 있는지 확인:
  ```
  find ~/Documents ~/Desktop -type f \( -name '*.md' -o -name '*.txt' \) -print0 \
  | xargs -0 -I{} sh -c 'v=$(xattr -p com.apple.quarantine "{}" 2>/dev/null); case "$v" in *Notepad*) echo "$v  {}";; esac'
  ```
- 파일을 **저장**하면 격리 기록이 붙습니다. 샌드박스 서드파티 앱 공통이며 macOS 동작입니다.

### 버전
- 표시 버전: **1.2.5**
- 빌드: **10**

---

**Developer:** Min-Gul Kim, MD, PhD — Jeonbuk National University Medical School
License: MIT · © 2026 Min-Gul Kim
