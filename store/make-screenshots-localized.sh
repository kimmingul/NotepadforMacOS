#!/bin/bash
#
# Generate Mac App Store screenshots for every shipped UI language.
#
# Produces store/screenshots/<locale>/01-editor.png and 02-preview.png at exactly
# 2560x1600, with the app's interface — tab bar, status bar, menus — in that language
# and sample documents whose names and text are in that language too.
#
# How it works, and why each choice:
#   • UI language comes from a launch argument: `open -n -a <app> --args -AppleLanguages "(de)"`.
#     The argument domain outranks the app's own stored preference, so the app's
#     AppLanguagePreferences.applyStored() cannot override it and nothing has to be
#     written into the sandbox container (writing there is slow and needs cfprefsd
#     to notice).
#   • Tab titles come from real files on disk, opened via Launch Services. The Save
#     panel is Powerbox-hosted and its name field cannot be filled through the
#     Accessibility API, and it does not run an IME, so saving localized names by
#     keystroke is not possible. Opening prepared files avoids the panel entirely.
#   • Window geometry and the second shot's preview toggle go through the
#     Accessibility API; synthetic keystrokes do not reliably reach this app.
#   • Capture is `screencapture -R` over the window frame, then sips normalizes to
#     the App Store size. On a 2x display a 1280x800 window captures as 2560x1600.
#
# MUST run in a foreground GUI session. The terminal needs Screen Recording and
# Accessibility permission (System Settings ▸ Privacy & Security). Without Screen
# Recording, screencapture produces nothing and this script reports it per shot.
#
# Usage:
#   ./build.sh release                     # the app under test
#   ./store/make-screenshots-localized.sh            # all languages
#   ./store/make-screenshots-localized.sh ko ja      # only these
#
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP="$PWD/build/DerivedData/Build/Products/Release/Notepad.app"
BID="com.nanumspace.mgkim.NotepadForMacOS"
CONTAINER="$HOME/Library/Containers/$BID/Data"
SESSIONS="$CONTAINER/Library/Application Support/NotepadForMacOS/Sessions"
OUT="store/screenshots"
WORK="/tmp/notepad-shots"
TARGET_W=2560; TARGET_H=1600
WIN_W=1280; WIN_H=800; WIN_X=120; WIN_Y=90

[ -d "$APP" ] || { echo "Build first:  ./build.sh release"; exit 1; }
if [ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" = "Dark" ]; then PAD=1E1E1E; else PAD=FFFFFF; fi

# App Store locale  ->  app UI language code (lproj)
declare -a LOCALES=(
  "ko:ko" "ja:ja" "zh-Hans:zh-Hans" "zh-Hant:zh-Hant" "es-ES:es" "fr-FR:fr"
  "de-DE:de" "pt-BR:pt-BR" "it:it" "ru:ru" "vi:vi" "id:id" "th:th" "pl:pl"
  "nl-NL:nl" "en-US:en"
)

# Sample documents per locale: <plain file name>|<markdown file name>
# The bodies live in store/screenshot-content/<locale>-{notes,readme}. Missing files
# fall back to the English pair so a new language still produces usable shots.
content_dir="store/screenshot-content"

osa() { osascript -e "$1" >/dev/null 2>&1; }

app_running() { pgrep -f "Products/Release/Notepad.app" >/dev/null 2>&1; }

stop_app() {
  pkill -f "Products/Release/Notepad.app" >/dev/null 2>&1
  pkill -x Notepad >/dev/null 2>&1
  local n=0
  while app_running && [ "$n" -lt 20 ]; do sleep 0.5; n=$((n+1)); done
  sleep 1
}

window_frame() {
  osascript -e 'tell application "System Events" to tell process "Notepad" to get {position, size} of window 1' 2>/dev/null
}

# AppKit does not recreate this directory, and without it the persistent-UI manager
# waits for a restoration that never completes: the app runs with no window at all
# and nothing — not "New Window", not a document from Finder — can produce one.
# Never delete it; make sure it exists.
ensure_state_dir() {
  mkdir -p "$CONTAINER/Library/Saved Application State"
}

# One window with predictable content: drop the app's own session so the launch below
# opens exactly the documents we pass. The window *state* AppKit keeps is left alone.
reset_state() {
  ensure_state_dir
  rm -f  "$SESSIONS"/*.txt 2>/dev/null
  rm -rf "$SESSIONS/Windows" 2>/dev/null
  mkdir -p "$SESSIONS"
  printf '{"version":2,"selectedTabID":"","timestamp":0,"tabs":[]}' > "$SESSIONS/session.json"
}

# Wait for an accessible window, then bring it to the front. Every later step reads
# "window 1", so give up loudly instead of letting osascript block on a missing window.
await_window() {
  local n=0 count
  while [ "$n" -lt 30 ]; do
    count=$(osascript -e 'tell application "System Events" to tell process "Notepad" to return count of windows' 2>/dev/null)
    [ "${count:-0}" -gt 0 ] 2>/dev/null && break
    sleep 0.5; n=$((n+1))
  done
  if [ "${count:-0}" -lt 1 ] 2>/dev/null; then
    echo "     ! no window appeared — is '$CONTAINER/Library/Saved Application State' present?"
    return 1
  fi
  osa 'tell application "System Events" to tell process "Notepad"
        set frontmost to true
        perform action "AXRaise" of window 1
      end tell'
  sleep 0.5
}

# A document is open when the window title carries the file name ("Notepad - X.md").
# Launch Services does not always hand the documents to the instance we just started —
# when it does not, the captured window shows a single empty Untitled tab, which is
# useless as a store screenshot. Verify, and re-deliver before giving up.
documents_open() {
  local title
  title=$(osascript -e 'tell application "System Events" to tell process "Notepad" to return name of window 1' 2>/dev/null)
  case "$title" in *" - "*) return 0 ;; *) return 1 ;; esac
}

deliver_documents() { # $1, $2 = files
  local attempt=0
  while [ "$attempt" -lt 4 ]; do
    documents_open && return 0
    open -a "$APP" "$1" "$2" >/dev/null 2>&1
    sleep 3
    attempt=$((attempt+1))
  done
  documents_open
}

size_window() {
  osa "tell application \"System Events\" to tell process \"Notepad\"
        set frontmost to true
        set position of window 1 to {$WIN_X, $WIN_Y}
        set size of window 1 to {$WIN_W, $WIN_H}
      end tell"
  sleep 0.8
}


capture() { # $1 = destination png
  osa 'tell application "System Events" to set frontmost of process "Notepad" to true'
  sleep 0.6
  local f x y w h
  f=$(window_frame)
  if [ -z "$f" ]; then
    echo "     ! window not readable — grant Accessibility to this terminal"
    return 1
  fi
  x=$(echo "$f" | awk -F', *' '{print $1}'); y=$(echo "$f" | awk -F', *' '{print $2}')
  w=$(echo "$f" | awk -F', *' '{print $3}'); h=$(echo "$f" | awk -F', *' '{print $4}')
  screencapture -x -R"${x},${y},${w},${h}" "$1" 2>/dev/null
  if [ ! -s "$1" ]; then
    echo "     ! capture produced nothing — grant Screen Recording to this terminal"
    rm -f "$1"
    return 1
  fi
}

normalize() { # $1 = png, resized in place to exactly TARGET_W x TARGET_H
  local w h nw nh
  w=$(sips -g pixelWidth  "$1" | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$1" | awk '/pixelHeight/{print $2}')
  read -r nw nh < <(awk -v w="$w" -v h="$h" -v TW="$TARGET_W" -v TH="$TARGET_H" \
    'BEGIN{s=TW/w; if (TH/h<s) s=TH/h; printf "%d %d", int(w*s+0.5), int(h*s+0.5)}')
  sips --resampleHeightWidth "$nh" "$nw" "$1" >/dev/null 2>&1
  sips --padToHeightWidth "$TARGET_H" "$TARGET_W" --padColor "$PAD" "$1" >/dev/null 2>&1
}

# The preview toggle carries no accessible label, so it is reached through the View
# menu by index, which stays the same in every language (menu bar item 5, item 6).
open_preview() {
  osa 'tell application "System Events" to tell process "Notepad"
        set frontmost to true
        click menu item 6 of menu 1 of menu bar item 5 of menu bar 1
      end tell'
  sleep 1.2
}

shots_for() { # $1 = store locale, $2 = app language code
  local locale="$1" lang="$2"
  local dir="$WORK/$locale" dest="$OUT/$locale"
  mkdir -p "$dir" "$dest"

  local notes md
  notes="$content_dir/$locale-notes.txt"
  md="$content_dir/$locale-readme.md"
  [ -f "$notes" ] || notes="$content_dir/en-US-notes.txt"
  [ -f "$md" ]    || md="$content_dir/en-US-readme.md"

  # File names are part of the screenshot: keep the localized ones from the header
  # line of each content file (first line starting with "name: ").
  local n1 n2
  n1=$(head -1 "$notes" | sed -n 's/^name: //p'); n1="${n1:-Notes.txt}"
  n2=$(head -1 "$md"    | sed -n 's/^name: //p'); n2="${n2:-Readme.md}"

  tail -n +2 "$notes" > "$dir/$n1"
  tail -n +2 "$md"    > "$dir/$n2"
  xattr -c "$dir/$n1" "$dir/$n2" 2>/dev/null

  echo "  $locale ($lang)"
  stop_app
  sleep 2                     # let Launch Services drop the old registration
  reset_state
  # Documents and the language override go in the same launch: handing the files to a
  # separate `open` lets Launch Services route them to another instance of the same
  # bundle id, leaving the captured window on an empty Untitled tab.
  open -n -a "$APP" "$dir/$n1" "$dir/$n2" --args -AppleLanguages "($lang)" >/dev/null 2>&1
  local n=0
  while ! app_running && [ "$n" -lt 30 ]; do sleep 0.5; n=$((n+1)); done
  await_window || return 1
  sleep 3
  if ! deliver_documents "$dir/$n1" "$dir/$n2"; then
    echo "     ! documents never opened — skipped (would have shot an empty tab)"
    return 1
  fi
  size_window

  if capture "$dest/01-editor.png"; then normalize "$dest/01-editor.png"; echo "     01-editor.png"; fi
  open_preview
  size_window
  if capture "$dest/02-preview.png"; then normalize "$dest/02-preview.png"; echo "     02-preview.png"; fi
}

selected=("$@")
if [ "${#selected[@]}" -eq 0 ]; then
  for pair in "${LOCALES[@]}"; do selected+=("${pair%%:*}"); done
fi

echo "=== localized App Store screenshots ==="
for want in "${selected[@]}"; do
  for pair in "${LOCALES[@]}"; do
    if [ "${pair%%:*}" = "$want" ]; then shots_for "${pair%%:*}" "${pair##*:}"; fi
  done
done

stop_app
reset_state
rm -rf "$WORK"

echo
echo "=== result ==="
for want in "${selected[@]}"; do
  for f in "$OUT/$want"/*.png; do
    [ -f "$f" ] || continue
    printf '%s  %s\n' "$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{printf "%sx", $2}' | sed 's/x$//')" "$f"
  done
done
echo
echo "Upload them with:  python3 store/upload-screenshots.py"
