# Notepad for macOS v1.2.6

If **Notes** / another app also hits Gatekeeper while Notepad is the default for `.txt` / `.md`, Finder is assessing the **default handler**, not the app you picked.

메모장가 `.txt`/`.md` 기본 앱인 동안 **메모**로 열어도 Gatekeeper가 뜨면, Finder가 고른 앱이 아니라 **기본 핸들러**를 검사하는 것입니다.

**Download:** [Notepad-v1.2.6.dmg](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.6)

### Reset first (required)
1. Eject every disk named Notepad.
2. Delete `/Applications/Notepad.app` and empty Trash.
3. In Terminal:

```
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
killall Finder
```

4. Confirm a `.md` opens in Notes or TextEdit **without** Gatekeeper.
5. Then install this DMG: drag to Applications, **eject**, launch Applications → Notepad once.

Do not set Always Open With while the DMG is open.

### Change
- Stop claiming `public.text` / `public.source-code` as document types.

### Version
- Marketing: **1.2.6**
- Build: **11**
