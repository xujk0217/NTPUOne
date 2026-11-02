#!/bin/bash
# Explicit invocation only. Uses Xcode's signed-in developer account; no stored API secrets.
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-archive}"
root="$PWD/.academic-local/TestFlight"
archive="$root/NTPUOne.xcarchive"
mkdir -p "$root"
case "$mode" in
  archive)
    if [ -e "$archive" ]; then
      echo "Archive exists. Move it aside before creating another build: $archive" >&2
      exit 1
    fi
    xcodebuild -project NTPUOne.xcodeproj -scheme NTPUOne -configuration Release \
      -destination 'generic/platform=iOS' -archivePath "$archive" \
      -allowProvisioningUpdates archive
    ;;
  upload)
    [ -d "$archive" ] || { echo 'Create the archive first.' >&2; exit 1; }
    xcodebuild -exportArchive -archivePath "$archive" \
      -exportOptionsPlist config/TestFlightExportOptions.plist \
      -exportPath "$root/Export" -allowProvisioningUpdates
    ;;
  *) echo 'Usage: scripts/testflight.sh [archive|upload]' >&2; exit 2 ;;
esac
