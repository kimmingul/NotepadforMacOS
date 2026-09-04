# Notepad for macOS  
### Also on the Mac App Store as **[Notepad Classic](https://apps.apple.com/app/notepad-classic/id6782928983)**

[![Release](https://img.shields.io/github/v/release/kimmingul/NotepadforMacOS?label=release)](https://github.com/kimmingul/NotepadforMacOS/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Mac App Store](https://img.shields.io/badge/Mac%20App%20Store-Notepad%20Classic-blue)](https://apps.apple.com/app/notepad-classic/id6782928983)

**Private plain-text notepad for Mac.**  
No AI. No account. No cloud. Multi-tab editing with **session restore** (including unsaved notes), local spell check, optional Markdown/HTML preview, and solid encodings (UTF-8, EUC-KR, UTF-16).

Built natively with Swift + SwiftUI for **Apple Silicon**.

| | |
|--|--|
| **Mac App Store** | [Notepad Classic](https://apps.apple.com/app/notepad-classic/id6782928983) (free) |
| **Direct download** | [v1.2.12 DMG](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.2.12) (Developer ID · notarized) |
| **Website** | [GitHub Pages](https://kimmingul.github.io/NotepadforMacOS/) |
| **Release notes** | [v1.2.12](docs/releases/RELEASE_NOTES_v1.2.12.md) · [v1.2.11](docs/releases/RELEASE_NOTES_v1.2.11.md) · [v1.2.10](docs/releases/RELEASE_NOTES_v1.2.10.md) · [v1.2.9](docs/releases/RELEASE_NOTES_v1.2.9.md) · [v1.2.8](docs/releases/RELEASE_NOTES_v1.2.8.md) |


**Developer:** Min-Gul Kim, MD, PhD (Jeonbuk National University Medical School)

---

## Why this instead of TextEdit?

| | TextEdit | Notepad Classic |
|--|--------|-----------------|
| Multi-tab | Limited / awkward | First-class tabs, drag reorder |
| Unsaved session restore | No | Yes (including reboot) |
| Encodings (EUC-KR, etc.) | Basic | Open / reopen / convert + warnings |
| Spell check | System | On by default; per-extension off for code |
| AI / account / network | — | **None by default.** Network only if you allow remote images/CSS in a preview tab |

---

## Features

- **Private by design** — sandbox, no ads, no tracking; network only if you allow remote images in a Markdown preview  
- **Session restore** — unsaved tabs come back; or start fresh from Settings  
- **Tabs** — drag reorder, Ctrl-Tab, `*` on dirty documents  
- **Spell check** — local system dictionary; optional autocorrect; disable for `.log` / `.json` / `.swift`…  
- **Encodings** — UTF-8, UTF-8 BOM, EUC-KR, UTF-16 LE/BE  
- **Syntax highlight** — Markdown, JSON, XML, HTML, and logs; `.txt` stays plain  
- **Preview** — optional side/full preview for `.md` and `.html`; remote images/CSS per-tab; open in default browser  
- Find & replace, go to line, date/time (F5), print, page setup  
- English & Korean UI  

### Intentional non-goals

- AI rewrite / summarize / chat  
- WYSIWYG / Typora-style inline editing, math, Mermaid  
- Accounts, cloud sync, telemetry  

---

## v1.2 highlights

| | |
|--|--|
| Preview | Optional side/full preview for `.md` and `.html` |
| Highlight | Markdown, JSON, XML, HTML, logs |
| Safety | No script execution; remote assets per-tab allow |
| Browser | Open the current file in the default browser |
| Toggle | Tab-bar preview icon stays visible while the pane is open |

Details: [RELEASE_NOTES_v1.2.md](docs/releases/RELEASE_NOTES_v1.2.md)

---

## 한국어 요약

**Notepad for macOS**는 Windows 11 기본 메모장에 익숙한 사용자를 위해 만든 **플레인 텍스트 전용** 편집기입니다.  
AI·계정·클라우드 없이, **탭 + 미저장 세션 복원**, **맞춤법 검사**, **EUC-KR 등 인코딩**, **Markdown/JSON/XML/HTML 하이라이트**, **선택적 .md/.html 미리보기**를 지원합니다.

Mac App Store 이름: **Notepad Classic** · [받기](https://apps.apple.com/app/notepad-classic/id6782928983)

---

## Store & marketing materials

- English App Store fields: [`store/listing-en.md`](store/listing-en.md)  
- Korean App Store fields: [`store/listing-ko.md`](store/listing-ko.md)  
- Screenshot captions (6 frames): [`store/screenshot-copy.md`](store/screenshot-copy.md)  
- Submission checklist: [`store/submission-checklist.md`](store/submission-checklist.md)  

---

## Development

- Swift 5 / SwiftUI + AppKit (`NSTextView`)  
- Apple Silicon (arm64) · Xcode 26+  

```bash
./build.sh          # Debug
./build.sh release  # Release
./build.sh test     # Unit tests
./build.sh dist     # Developer ID DMG (set DEVID_APP / NOTARY_PROFILE)
./build.sh open     # Xcode
```

```
notepad_macOS/
├── README.md  index.html  build.sh
├── docs/releases/
├── store/                 # listings, screenshots, privacy
└── NotepadForMacOS/       # Xcode project (file-system sync groups)
```

### Shortcuts (selection)

| Action | Shortcut |
|--------|----------|
| New tab | `Cmd+T` |
| Save | `Cmd+S` |
| Find | `Cmd+F` |
| Go to line | `Cmd+L` |
| Preview / hide | `Cmd+Option+P` |
| Full-screen preview | `Cmd+Option+Return` |
| Word wrap | `Cmd+Shift+W` |
| Next / previous tab | `Ctrl+Tab` / `Ctrl+Shift+Tab` |

---

## License

[MIT License](LICENSE) · Copyright © 2026 Min-Gul Kim.
