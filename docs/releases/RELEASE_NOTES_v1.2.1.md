# Notepad for macOS v1.2.1

Patch on 1.2 preview. Install from this **notarized Developer ID DMG** on other Macs — do not copy a Debug build.

1.2 미리보기 패치. **다른 Mac에는 이 공증 DMG만** 설치하세요. Debug 빌드를 복사하면 Gatekeeper가 막습니다.

**Download:** [Notepad-v1.2.1.dmg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.1) (Developer ID signed · notarized)  
**Site:** https://kimmingul.github.io/NotepadforMacOS/

---

## English

### Fixes
- HTML comments (`<!-- -->`) are hidden in Markdown preview instead of showing as escaped code.
- Fenced code follows GFM: a closing fence must be at least as long as the opener. Nested ` ``` ` inside ` ````md ` no longer breaks highlight.
- Fence info strings use the first token as the language label (` ```md id="..." ` → `md`). Attributes are ignored. Body stays code, not re-rendered Markdown.

### Install on another Mac
1. Download the DMG from the link above (not a copy of Notepad.app from AirDrop/USB Debug).
2. Open the DMG and drag **Notepad** into **Applications**.
3. Launch Notepad once, then open `.md` files.

Requires Apple Silicon (arm64).

### Version
- Marketing version: **1.2.1**
- Build: **5**

---

## 한국어

### 수정
- HTML 주석(`<!-- -->`)은 미리보기에서 숨깁니다. 코드 상자로 보이지 않습니다.
- 코드 펜스는 GFM: 닫는 백틱이 연 개수 이상이어야 합니다. ` ````md ` 안의 ` ``` `에서 하이라이트가 끊기지 않습니다.
- info string은 첫 토큰만 언어 라벨로 씁니다 (` ```md id="..." ` → `md`). 본문은 코드 그대로입니다.

### 다른 Mac에 설치
1. 위 DMG를 받습니다. Debug 앱이나 AirDrop으로 복사한 `.app`은 쓰지 마세요.
2. DMG를 열고 **Notepad**를 **응용 프로그램**으로 드래그합니다.
3. Notepad를 한 번 실행한 뒤 `.md`를 엽니다.

Apple Silicon(arm64) 필요.

### 버전
- 표시 버전: **1.2.1**
- 빌드: **5**

---

**Developer:** Min-Gul Kim, MD, PhD — Jeonbuk National University Medical School  
License: MIT · © 2026 Min-Gul Kim
