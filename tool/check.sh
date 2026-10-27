#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter --suppress-analytics pub get
flutter --suppress-analytics analyze
flutter --suppress-analytics test --reporter expanded
flutter --suppress-analytics build web --release --no-web-resources-cdn
python3 tool/generate_offline_worker.py
