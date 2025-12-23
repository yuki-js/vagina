#!/bin/bash
# Fix Windows plugin list by removing flutter_sound (not supported on Windows)
# This script is called after flutter pub get in Windows CI workflow

set -e

PLUGIN_FILE="windows/flutter/generated_plugins.cmake"

if [ ! -f "$PLUGIN_FILE" ]; then
  echo "Error: $PLUGIN_FILE not found"
  exit 1
fi

echo "Removing flutter_sound from Windows plugins list..."

# Remove flutter_sound from the plugin list
sed -i '/^  flutter_sound$/d' "$PLUGIN_FILE"

echo "Windows plugins fixed successfully"
echo "Updated plugin list:"
grep -A 10 "list(APPEND FLUTTER_PLUGIN_LIST" "$PLUGIN_FILE"
