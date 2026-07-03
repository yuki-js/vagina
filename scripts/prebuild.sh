#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OPENAPI_SPEC="openapi/openapi.yaml"

if [[ ! -f "$OPENAPI_SPEC" ]]; then
  cat >&2 <<EOF
Error: $OPENAPI_SPEC is missing.

Generate or copy the compiled server OpenAPI spec into the client repo before
running client prebuild. From the meta workspace, run:

  ./server/gradlew -p server copyCompiledOpenApiToClient

EOF
  exit 1
fi

echo "Generating Flutter localizations..."
flutter gen-l10n

echo "Generating florval API client from $OPENAPI_SPEC..."
dart run florval generate --schema "$OPENAPI_SPEC" --output lib/api/generated

echo "Running Dart build_runner..."
dart run build_runner build --delete-conflicting-outputs
