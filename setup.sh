#!/usr/bin/env bash
# Al-Huda one-shot setup: generates native folders, installs packages,
# configures Android/iOS and builds launcher icons.
set -euo pipefail
cd "$(dirname "$0")"

PLATFORMS="android"
if [[ "$(uname)" == "Darwin" ]]; then PLATFORMS="android,ios"; fi

echo "==> flutter create (platforms: $PLATFORMS)"
flutter create --org com.alhuda.islamic --project-name al_huda --platforms "$PLATFORMS" .

echo "==> flutter pub get"
flutter pub get

echo "==> Configure native projects"
dart run tool/configure_platforms.dart

echo "==> Launcher icons"
if [[ "$(uname)" == "Darwin" ]]; then
  dart run flutter_launcher_icons
else
  dart run flutter_launcher_icons -f flutter_launcher_icons_android.yaml
fi

echo ""
echo "Done. Run the app with:  flutter run"
