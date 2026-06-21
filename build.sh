#!/bin/bash
#
# NotepadForMacOS - Build & Archive Script
#
# This script matches the current project layout (as of 2026-06-20).
# The project builds cleanly in Xcode. This script provides reliable
# CLI equivalents for build verification and distribution.
#
# Usage:
#   ./build.sh                # Debug build (default)
#   ./build.sh build          # Same as above
#   ./build.sh release        # Release build (arm64)
#   ./build.sh archive        # Create timestamped .xcarchive
#   ./build.sh clean          # Clean build products
#   ./build.sh open           # Open in Xcode
#   ./build.sh --help
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# === Current project settings ===
PROJECT="NotepadForMacOS/NotepadForMacOS.xcodeproj"
SCHEME="NotepadForMacOS"
BUILD_DIR="$SCRIPT_DIR/build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}    $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $1"; }
error()   { echo -e "${RED}[ERROR]${NC}   $1"; }

usage() {
  cat <<'EOF'
NotepadForMacOS Build Script

Commands:
  build     Build Debug configuration (default)
  release   Build Release configuration
  archive   Archive for distribution (Release + .xcarchive)
  clean     Clean derived data and local build folder
  open      Open the Xcode project
  help      Show this help message

Examples:
  ./build.sh
  ./build.sh release
  ./build.sh archive
  ./build.sh clean
EOF
}

ensure_build_dir() {
  mkdir -p "$BUILD_DIR"
}

# Generate a complete multi-resolution AppIcon.icns and replace it in the built .app.
# This guarantees the Dock / Finder shows the real icon instead of a white square.
fix_app_icon() {
  local configuration="$1"
  local app_path="$BUILD_DIR/DerivedData/Build/Products/${configuration}/Notepad.app"

  if [[ ! -d "$app_path" ]]; then
    warn "Built app not found at $app_path — skipping icon fix"
    return
  fi

  # Prefer the high-res image the user prepared in the asset catalog if available.
  # Fall back to the Windows reference icon.
  local master_icon="NotepadForMacOS/NotepadForMacOS/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png"
  if [[ ! -f "$master_icon" ]]; then
    master_icon="NotepadForMacOS/Windows_Notepad_icon.png"
  fi
  if [[ ! -f "$master_icon" ]]; then
    warn "No suitable master icon found — skipping icon fix"
    return
  fi

  local tmp_iconset="/tmp/NotepadAppIcon.$$.iconset"
  rm -rf "$tmp_iconset"
  mkdir -p "$tmp_iconset"

  # Create all required sizes (macOS App Icon requirements)
  sips -s format png -z 16 16   "$master_icon" --out "$tmp_iconset/icon_16x16.png"     >/dev/null 2>&1
  sips -s format png -z 32 32   "$master_icon" --out "$tmp_iconset/icon_16x16@2x.png"  >/dev/null 2>&1
  sips -s format png -z 32 32   "$master_icon" --out "$tmp_iconset/icon_32x32.png"     >/dev/null 2>&1
  sips -s format png -z 64 64   "$master_icon" --out "$tmp_iconset/icon_32x32@2x.png"  >/dev/null 2>&1
  sips -s format png -z 128 128 "$master_icon" --out "$tmp_iconset/icon_128x128.png"   >/dev/null 2>&1
  sips -s format png -z 256 256 "$master_icon" --out "$tmp_iconset/icon_128x128@2x.png" >/dev/null 2>&1
  sips -s format png -z 256 256 "$master_icon" --out "$tmp_iconset/icon_256x256.png"   >/dev/null 2>&1
  sips -s format png -z 512 512 "$master_icon" --out "$tmp_iconset/icon_256x256@2x.png" >/dev/null 2>&1
  sips -s format png -z 512 512 "$master_icon" --out "$tmp_iconset/icon_512x512.png"   >/dev/null 2>&1
  sips -s format png -z 1024 1024 "$master_icon" --out "$tmp_iconset/icon_512x512@2x.png" >/dev/null 2>&1

  local new_icns="/tmp/NotepadAppIcon.$$.icns"
  if iconutil --convert icns --output "$new_icns" "$tmp_iconset" >/dev/null 2>&1; then
    local target_icns="$app_path/Contents/Resources/AppIcon.icns"
    cp "$new_icns" "$target_icns"
    rm -f "$new_icns"
    success "Replaced AppIcon.icns with complete version (all sizes up to 1024)"
  else
    warn "Failed to generate full .icns"
  fi
  rm -rf "$tmp_iconset"

  # Help macOS notice the new icon
  touch "$app_path"
}

build_target() {
  local configuration="$1"
  local destination="$2"

  ensure_build_dir

  info "Building scheme '$SCHEME' ($configuration) → arm64"

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$configuration" \
    -destination "$destination" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -parallelizeTargets \
    clean build \
    | tee "$BUILD_DIR/last-build.log"

  success "Build finished: $configuration"
  echo "  Log: $BUILD_DIR/last-build.log"

  # Ensure the app has a complete, proper AppIcon (the asset catalog sometimes
  # produces incomplete .icns missing 256/512 sizes, resulting in white square in Dock).
  fix_app_icon "$configuration"
}

do_archive() {
  ensure_build_dir

  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local archive_name="NotepadForMacOS-${timestamp}"
  local archive_path="$BUILD_DIR/${archive_name}.xcarchive"

  info "Creating archive for distribution..."

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$archive_path" \
    archive \
    | tee "$BUILD_DIR/last-archive.log"

  success "Archive created successfully!"
  echo ""
  echo "  Archive: $archive_path"
  echo ""
  echo "Next steps for exporting .app:"
  echo "  1. Open Xcode → Window > Organizer"
  echo "  2. Select the archive → 'Distribute App'"
  echo "  3. Choose 'Copy App' (for direct distribution) or Developer ID"
  echo ""
  echo "Or export from command line if you have an exportOptions.plist."
}

do_clean() {
  info "Cleaning project..."

  if [[ -f "$PROJECT" ]]; then
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" clean || true
  fi

  rm -rf "$BUILD_DIR"
  success "Clean complete"
}

open_in_xcode() {
  info "Opening project in Xcode..."
  open "$PROJECT"
}

# === Main dispatch ===
command="${1:-build}"

case "$command" in
  build|"")
    build_target "Debug" "platform=macOS,arch=arm64"
    ;;
  release)
    build_target "Release" "platform=macOS,arch=arm64"
    ;;
  archive)
    do_archive
    ;;
  clean)
    do_clean
    ;;
  open)
    open_in_xcode
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    error "Unknown command: $command"
    usage
    exit 1
    ;;
esac
