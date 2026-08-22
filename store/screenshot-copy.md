# App Store screenshot copy (6 frames)

Use **English** on the first frames for global ASO.  
Target size: **2560 × 1600** (macOS). Overlay short headlines; keep UI readable.

**Visual recipe:** real app window (light or dark), large type at top or left band, max **2 lines** headline + optional **1 line** subhead.

**Brand line (optional footer on all):** `Notepad Classic · Private plain text for Mac`

---

## Frame 1 — Hero / Privacy (FIRST — highest impact)

| | |
|--|--|
| **Headline** | No AI. No account. No cloud. |
| **Subhead** | Private plain-text notepad for Mac |
| **Show in UI** | Clean editor, empty or short English note |
| **Why** | Stops the scroll; defines category against AI notepads |

---

## Frame 2 — Session restore

| | |
|--|--|
| **Headline** | Unsaved tabs come back |
| **Subhead** | After quit, restart, even reboot |
| **Show in UI** | 2–3 tabs, one titled with `*` (dirty), sample text visible |
| **Why** | #1 product differentiator vs TextEdit |

---

## Frame 3 — Tabs

| | |
|--|--|
| **Headline** | Multiple files, one window |
| **Subhead** | Drag to reorder · Ctrl-Tab to switch |
| **Show in UI** | Tab bar with 3+ tabs, English file names (`notes.txt`, `todo.txt`, `readme.txt`) |
| **Why** | Instantly understandable productivity |

---

## Frame 4 — Spell check (local)

| | |
|--|--|
| **Headline** | Spell check without the cloud |
| **Subhead** | System dictionary · optional autocorrect |
| **Show in UI** | English sentence with a red underline; status/settings if possible |
| **Why** | v1.1 feature; reinforces “local, not AI” |

---

## Frame 5 — Encodings

| | |
|--|--|
| **Headline** | UTF-8 · EUC-KR · UTF-16 |
| **Subhead** | Reopen or convert from the status bar |
| **Show in UI** | Status bar encoding menu open; mix of Latin + Hangul sample |
| **Why** | Niche power users + East Asia; still useful globally for “does encodings right” |

---
## Frame 6 — Preview / trust

| | |
|--|--|
| **Headline** | Preview when you want it |
| **Subhead** | .md / .html side pane · scripts never run |
| **Show in UI** | Markdown or HTML tab with preview open; tab-bar + / preview / appearance still visible |
| **Why** | v1.2 feature; still plain text; privacy intact |


---

## Overlay style tips

- Font: SF Pro / system sans, **bold** headline 48–72 pt equivalent at 2560 width  
- Color: white text on dark translucent bar, or dark text on light bar  
- Avoid walls of text; **≤ 8 words** on headline  
- Don’t cover the tab bar or status bar—those sell the product  
- Export sRGB PNG; no device chrome required for Mac screenshots  

## Optional Korean set (secondary localization)

If you add `ko` screenshot set later:

1. AI 없음 · 계정 없음 · 클라우드 없음  
2. 저장 안 한 탭도 다시 열립니다  
3. 여러 파일을 한 창에서  
4. 네트워크 없는 맞춤법 검사  
5. UTF-8 · EUC-KR · UTF-16  
6. 원할 때만 미리보기 · 파일은 Mac 안에  

## Production command

Existing helper (if still valid):

```bash
./store/make-screenshots.sh
```

Then add text overlays in Keynote / Figma / Preview. Final files go under `store/screenshots/` (e.g. `01-privacy.png` … `06-trust.png`).
