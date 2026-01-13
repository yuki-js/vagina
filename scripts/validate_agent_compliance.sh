#!/bin/bash
# Validation script to ensure AI agent instructions are being followed
# This script checks for common anti-patterns that indicate work abandonment

echo "=== Validating Agent Compliance ==="

# Check for handover documents (should not exist for incomplete work)
if find docs/引き継ぎ資料 -name "*.md" -type f 2>/dev/null | grep -q .; then
    echo "❌ ERROR: Handover documents found. Work must be completed, not deferred."
    echo "Found documents:"
    find docs/引き継ぎ資料 -name "*.md" -type f
    exit 1
fi

# Check for TODO comments in recently modified Dart files only
RECENT_FILES=$(git diff --name-only HEAD~5 2>/dev/null || echo "")
if echo "$RECENT_FILES" | grep -q "\.dart$"; then
    TODO_COUNT=$(git diff HEAD~5 -- '*.dart' | grep -E "^\+.*//.*TODO|^\+.*//.*FIXME" | wc -l || echo "0")
    if [ "$TODO_COUNT" -gt 0 ]; then
        echo "⚠️  WARNING: Found $TODO_COUNT new TODO/FIXME comments in recent Dart changes"
        echo "Agent should complete work instead of leaving TODOs"
        git diff HEAD~5 -- '*.dart' | grep -E "^\+.*//.*TODO|^\+.*//.*FIXME" || true
    fi
fi

# Check for incomplete work markers
INCOMPLETE_MARKERS=$(git log --all --oneline -20 | grep -iE "WIP|work in progress|incomplete|partial" | wc -l || echo "0")
if [ "$INCOMPLETE_MARKERS" -gt 0 ]; then
    echo "❌ ERROR: Found incomplete work markers in recent commits"
    git log --all --oneline -20 | grep -iE "WIP|work in progress|incomplete|partial" || true
    exit 1
fi

# Verify flutter analyze passes (only check for errors, not warnings)
echo "Running flutter analyze..."
ANALYZE_OUTPUT=$(flutter analyze --no-fatal-infos 2>&1 || true)
ERROR_COUNT=$(echo "$ANALYZE_OUTPUT" | grep -E "^\s*error •" | wc -l || echo "0")
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "❌ ERROR: Flutter analyze found $ERROR_COUNT errors. Agent must fix all errors before completing."
    echo "$ANALYZE_OUTPUT" | grep -E "^\s*error •"
    exit 1
fi

echo "✅ Agent compliance validation passed"
exit 0
