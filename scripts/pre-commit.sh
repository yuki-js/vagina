#!/bin/bash
# Pre-commit hook for VAGINA project
# Run: chmod +x scripts/pre-commit.sh && cp scripts/pre-commit.sh .git/hooks/pre-commit

echo "Running pre-commit checks..."

# Format Dart code
echo "Formatting Dart code..."
dart format --set-exit-if-changed .
if [ $? -ne 0 ]; then
    echo "Error: Code formatting issues found. Please run 'dart format .' to fix."
    exit 1
fi

# Run analyzer
echo "Running Dart analyzer..."
flutter analyze --no-fatal-infos
if [ $? -ne 0 ]; then
    echo "Error: Analysis issues found. Please fix before committing."
    exit 1
fi

echo "All pre-commit checks passed!"
exit 0
