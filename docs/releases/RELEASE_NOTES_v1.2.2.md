# Notepad for macOS v1.2.2

Preview hardening. Install from this **notarized Developer ID DMG** on other Macs — do not copy a Debug build.

미리보기 보안 패치. **다른 Mac에는 이 공증 DMG만** 설치하세요. Debug 빌드를 복사하면 Gatekeeper가 막습니다.

**Download:** [Notepad-v1.2.2.dmg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.2) (Developer ID signed · notarized)  
**Site:** https://kimmingul.github.io/NotepadforMacOS/

---

## English

### Security
- HTML preview is parsed and rebuilt from a tag allowlist. Scripts, forms, frames, and event handlers never run.
- Preview documents are always app-owned, with CSP in `<head>`.
- The `notepad-md` scheme is resource-only. Main-frame navigations are cancelled. Local `.html` / `.md` / `.svg` are not served as images.
- Remote preview assets stay on public `https`, skip private/loopback hosts and resolved IPs, and cap at 8 MB.

### Fixes
- Folder-access bookmarks refresh after a move or reboot.
- Preview no longer waits on Korean IME composition in other windows.

### Install on another Mac
1. Download the DMG from the link above (not a copy of Notepad.app from AirDrop/USB Debug).
2. Open the DMG and drag **Notepad** into **Applications**.
3. Launch Notepad once, then open `.md` / `.html` files.

Requires Apple Silicon (arm64).

### Version
- Marketing version: **1.2.2**
- Build: **6**

---

## 한국어

### 보안
- HTML 미리보기는 허용 태그 목록으로만 다시 그립니다. 스크립트·폼·프레임·이벤트 핸들러는 실행하지 않습니다.
- 미리보기 문서는 항상 앱이 만든 HTML이고, CSP는 `<head>`에 있습니다.
- `notepad-md` 스킴은 리소스 전용입니다. 메인 프레임 이동은 취소합니다. 로컬 `.html` / `.md` / `.svg`는 이미지로 주지 않습니다.
- 원격 미리보기 자원은 공개 `https`만, 사설/루프백 호스트와 해석된 IP는 거부, 8MB 제한.

### 수정
- 폴더 접근 북마크는 이동·재부팅 후에도 다시 고칩니다.
- 다른 창에서 한글을 조합 중이어도 이 탭 미리보기는 멈추지 않습니다.

### 다른 Mac에 설치
1. 위 DMG를 받습니다. Debug 앱이나 AirDrop으로 복사한 `.app`은 쓰지 마세요.
2. DMG를 열고 **Notepad**를 **응용 프로그램**으로 드래그합니다.
3. Notepad를 한 번 실행한 뒤 `.md` / `.html`을 엽니다.

Apple Silicon(arm64) 필요.

### 버전
- 표시 버전: **1.2.2**
- 빌드: **6**

---

**Developer:** Min-Gul Kim, MD, PhD — Jeonbuk National University Medical School  
License: MIT · © 2026 Min-Gul Kim
