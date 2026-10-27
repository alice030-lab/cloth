#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Generate SDK-version-matched native scaffolds without overwriting app sources.
if [ ! -d ios/Runner.xcodeproj ] || [ ! -f android/app/build.gradle.kts ]; then
  temp_dir=$(mktemp -d)
  trap 'rm -rf "$temp_dir"' EXIT
  flutter --suppress-analytics create --project-name outfit_canvas --org com.outfitcanvas --platforms=ios,android "$temp_dir/outfit_canvas"
  for platform in ios android; do
    if [ ! -d "$platform" ]; then cp -R "$temp_dir/outfit_canvas/$platform" "$platform"; fi
  done
fi
python3 tool/configure_native.py
flutter --suppress-analytics pub get
