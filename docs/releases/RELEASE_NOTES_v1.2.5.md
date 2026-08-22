# Notepad for macOS v1.2.5

Finder **Always Open With** was bound to `/Volumes/Notepad/Notepad.app`. Every new DMG remounted that same path, so Gatekeeper kept assessing the disk-image copy.

‘항상 이 앱으로 열기’가 `/Volumes/Notepad/Notepad.app`에 묶여 있었습니다. DMG를 다시 받아도 같은 경로가 살아나서 Gatekeeper가 디스크 이미지 복사본을 검사합니다.

**Download:** [Notepad-v1.2.5.dmg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.5)

### Install
1. Delete `/Applications/Notepad.app`.
2. Eject every mounted **Notepad** disk image.
3. Download this DMG (volume name is **Notepad 1.2.5**).
4. Drag **Notepad** to **Applications**.
5. Eject the disk.
6. Open **Applications → Notepad** once.
7. Right-click a `.md` → Open With → Other… → Applications/Notepad → Always Open With.

Do not set Always Open With while the DMG window is still open.

### Version
- Marketing: **1.2.5**
- Build: **10**
