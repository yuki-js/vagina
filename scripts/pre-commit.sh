#!/bin/bash
# Pre-commit hook for VAGINA project
# Run: chmod +x scripts/pre-commit.sh && cp scripts/pre-commit.sh .git/hooks/pre-commit

echo "Running pre-commit checks..."

# Check if fvm is available, if not fall back to flutter
if command -v fvm &> /dev/null; then
    FLUTTER_CMD="fvm flutter"
else
    FLUTTER_CMD="flutter"
fi

# Format Dart code
echo "Formatting Dart code..."
dart format --set-exit-if-changed .
if [ $? -ne 0 ]; then
    echo "Error: Code formatting issues found. Please run 'dart format .' to fix."
    exit 1
fi

# Run analyzer
echo "Running Dart analyzer..."
$FLUTTER_CMD analyze --no-fatal-infos
if [ $? -ne 0 ]; then
    echo "Error: Analysis issues found. Please fix before committing."
    exit 1
fi

echo "All pre-commit checks passed!"
exit 0
