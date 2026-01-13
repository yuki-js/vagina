#!/bin/bash
# Validation script to ensure AI agent instructions are being followed
# This script checks for common anti-patterns that indicate work abandonment

echo "=== Validating Agent Compliance ==="

# Check for handover documents in incomplete work state
# Handover documents are only allowed if they document COMPLETED work
if find docs/引き継ぎ資料 -name "*.md" -type f 2>/dev/null | grep -q .; then
    echo "⚠️  WARNING: Handover documents found."
    echo "These should only exist for COMPLETED work documentation, not incomplete work."
    echo "Found documents:"
    find docs/引き継ぎ資料 -name "*.md" -type f
    # Only error if there are also signs of incomplete work
    INCOMPLETE_COUNT=$(git log --all --oneline -10 | grep -iE "WIP|work in progress|incomplete|partial|TODO" | wc -l || echo "0")
    if [ "$INCOMPLETE_COUNT" -gt 0 ]; then
        echo "❌ ERROR: Handover documents found with incomplete work markers. This violates agent instructions."
        exit 1
    fi
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

# Runtime self-inspection: Check AI agent's own environment
echo "=== Runtime Self-Inspection ==="

# MANDATORY: Process tree inspection with ps -ef
echo "Process tree (ps -ef):"
if command -v ps &> /dev/null; then
    ps -ef | head -50 || ps aux | head -50
else
    echo "ERROR: ps command not available - cannot perform mandatory self-inspection"
    exit 1
fi

# Check if running in GitHub Actions
if [ -n "$GITHUB_ACTIONS" ]; then
    echo "✓ Running in GitHub Actions environment"
    echo "  Workflow: ${GITHUB_WORKFLOW:-unknown}"
    echo "  Job: ${GITHUB_JOB:-unknown}"
    echo "  Run ID: ${GITHUB_RUN_ID:-unknown}"
    echo "  Actor: ${GITHUB_ACTOR:-unknown}"
    
    # Check conversation step environment
    if [ -n "$COPILOT_THREAD_ID" ]; then
        echo "  Copilot Thread ID: ${COPILOT_THREAD_ID}"
    fi
    
    # Check for PTY and terminal
    if [ -t 0 ]; then
        echo "  ✓ Standard input is connected to terminal"
    else
        echo "  ℹ Standard input is NOT a terminal (expected in CI)"
    fi
    
    # Focused process inspection for agent-related processes
    echo "  Agent-related processes:"
    ps -ef 2>/dev/null | grep -E "runner|github|copilot|node|bash" | grep -v grep | head -30 || \
    ps aux 2>/dev/null | grep -E "runner|github|copilot|node|bash" | grep -v grep | head -30 || \
    echo "  Unable to filter agent processes"
    
    # Check available environment variables related to agent
    echo "  Agent-related environment variables:"
    env | grep -iE "copilot|github|runner|agent" | head -30 || echo "  None found"
else
    echo "ℹ Not running in GitHub Actions (local execution)"
fi

# Check shell capabilities
echo "  Shell: $SHELL"
echo "  Bash version: ${BASH_VERSION:-unknown}"
echo "  Current PID: $$"
echo "  Parent PID: $PPID"

# Memory and resource check
if command -v free &> /dev/null; then
    echo "  Memory usage:"
    free -h | head -2
fi

echo "✅ Agent compliance validation passed"
exit 0
