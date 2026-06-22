#!/bin/bash
#
# Generate Mac App Store screenshots from the built Release app — with real,
# saved file names showing in the tabs.
#
# How it works (and why):
#   • Document text is injected via the Accessibility API (set value of the
#     text area). Synthetic keystrokes do NOT reliably reach the editor, but AX does.
#   • A second tab is created via the File ▸ 새 탭 menu item (AX click).
#   • To give each tab a real file name, the doc is saved through the standard
#     Save panel: the panel's name field is sandbox/Powerbox-hosted and not
#     reachable via AX, so the file name is typed with a keystroke (ASCII only —
#     the panel field does not run the Korean IME, so names are English) and
#     confirmed with Return. Files land in ~/Documents and are cleaned up after.
#
# MUST be run in a foreground GUI session (keystrokes are required for the Save
# panel). Requires Screen Recording + Accessibility permission for the terminal.
#
# Usage:  ./store/make-screenshots.sh
#
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP="$PWD/build/DerivedData/Build/Products/Release/Notepad.app"
BID="com.nanumspace.mgkim.NotepadForMacOS"
OUT="store/screenshots"; RAW="$OUT/raw"
SAVE_DIR="$HOME/Documents"            # default Save-panel location
TARGET_W=2560; TARGET_H=1600
mkdir -p "$RAW"
[ -d "$APP" ] || { echo "Build the app first: ./build.sh release"; exit 1; }
if [ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" = "Dark" ]; then PAD=1E1E1E; else PAD=FFFFFF; fi

WELCOME='Notepad for macOS

A fast, plain-text editor — just like the Windows Notepad, rebuilt for Mac.

  •  Multiple tabs, with drag-to-reorder
  •  Automatic session restore — even unsaved tabs come back
  •  EUC-KR · UTF-8 · UTF-8 BOM · UTF-16 encodings
  •  Inline find & replace — match count, wrap, case
  •  Print & Page Setup

Tip: just quit. Your tabs and text return on the next launch.'

KOREAN='한글 메모 — EUC-KR까지 든든하게

레거시 .txt도 깨짐 없이 열고, 다른 인코딩으로
다시 열거나 변환할 수 있어요.

오늘 할 일
  ☐  논문 초안 정리
  ☐  회의 노트 백업
  ☑  Notepad 설치 완료

상태바에서 인코딩을 바꿔 다시 열 수 있습니다.
한/영 혼용과 IME 조합도 안전하게 처리합니다.'

set_text(){ # $1 = content -> active tab's text area, via AX
  osascript - "$1" <<'OSA' >/dev/null 2>&1
on run argv
  tell application "System Events" to tell process "Notepad"
    set frontmost to true
    set value of (text area 1 of scroll area 2 of group 1 of window 1) to (item 1 of argv)
  end tell
end run
OSA
  sleep 0.4
}

save_as(){ # $1 = base name (ASCII). Saves <name>.txt to ~/Documents.
  osascript - "$1" <<'OSA' >/dev/null 2>&1
on run argv
  tell application "System Events" to tell process "Notepad"
    set frontmost to true
    click menu item 8 of menu 1 of menu bar item 3 of menu bar 1  -- 다른 이름으로 저장…
    delay 1.2
    keystroke (item 1 of argv)   -- replaces the pre-selected default name
    delay 0.4
    keystroke return
    delay 1.3
  end tell
end run
OSA
}

new_tab(){ osascript -e 'tell application "System Events" to tell process "Notepad" to click menu item 1 of menu 1 of menu bar item 3 of menu bar 1' >/dev/null 2>&1; sleep 0.6; }

size_window(){
  osascript <<'OSA' >/dev/null 2>&1 || true
tell application "System Events" to tell process "Notepad"
  set frontmost to true
  set position of window 1 to {120, 90}
  set size of window 1 to {1280, 800}
end tell
OSA
  sleep 0.5
}

capture(){ # $1=output
  osascript -e 'tell application "System Events" to set frontmost of process "Notepad" to true' >/dev/null 2>&1
  sleep 0.4
  local f x y w h
  f=$(osascript -e 'tell application "System Events" to tell process "Notepad" to get {position, size} of window 1' 2>/dev/null)
  x=$(echo "$f"|awk -F', *' '{print $1}'); y=$(echo "$f"|awk -F', *' '{print $2}')
  w=$(echo "$f"|awk -F', *' '{print $3}'); h=$(echo "$f"|awk -F', *' '{print $4}')
  screencapture -x -R"${x},${y},${w},${h}" "$1"
}

normalize(){ # $1=raw $2=out -> exactly TARGET_W x TARGET_H, no distortion
  local w h nw nh
  w=$(sips -g pixelWidth "$1"  | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$1" | awk '/pixelHeight/{print $2}')
  read -r nw nh < <(awk -v w="$w" -v h="$h" -v TW="$TARGET_W" -v TH="$TARGET_H" \
    'BEGIN{s=TW/w; if (TH/h<s) s=TH/h; printf "%d %d", int(w*s+0.5), int(h*s+0.5)}')
  cp "$1" "$2"
  sips --resampleHeightWidth "$nh" "$nw" "$2" >/dev/null 2>&1
  sips --padToHeightWidth "$TARGET_H" "$TARGET_W" --padColor "$PAD" "$2" >/dev/null 2>&1
}

# --- clean slate (app session + any prior sample files so Save won't prompt to replace) ---
pkill -x Notepad 2>/dev/null || true
sleep 1
rm -rf "$HOME/Library/Containers/$BID/Data/Library/Application Support"/* 2>/dev/null || true
rm -f "$SAVE_DIR/Welcome.txt" "$SAVE_DIR/Memo.txt" 2>/dev/null || true

# --- launch & wait ---
open "$APP"
for _ in $(seq 1 40); do
  n=$(osascript -e 'tell application "System Events" to tell process "Notepad" to count windows' 2>/dev/null || echo 0)
  [ "${n:-0}" -ge 1 ] && break
  sleep 0.5
done
sleep 1
size_window

# --- shot 01: Welcome.txt (single tab) ---
set_text "$WELCOME"
save_as "Welcome"
capture "$RAW/01.png"

# --- shot 02: two tabs (Welcome.txt + Memo.txt), Korean tab active ---
new_tab
set_text "$KOREAN"
save_as "Memo"
capture "$RAW/02.png"

normalize "$RAW/01.png" "$OUT/01-welcome.png"
normalize "$RAW/02.png" "$OUT/02-tabs-korean.png"

# --- cleanup: quit app, wipe session refs, remove the sample files we created ---
pkill -x Notepad 2>/dev/null || true
sleep 1
rm -rf "$HOME/Library/Containers/$BID/Data/Library/Application Support"/* 2>/dev/null || true
rm -f "$SAVE_DIR/Welcome.txt" "$SAVE_DIR/Memo.txt" 2>/dev/null || true

echo "=== generated ==="
for f in "$OUT/01-welcome.png" "$OUT/02-tabs-korean.png"; do
  echo "$f -> $(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{printf "%s ",$2}')"; echo
done
echo "DONE"
