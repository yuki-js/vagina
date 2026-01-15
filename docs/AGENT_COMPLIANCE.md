# Agent Compliance and Supervision System

This document describes the system implemented to ensure AI coding agents follow their instructions.

## Problem Statement (Issue #93)

AI coding agents were not consistently following their instructions in `.github/agents/serious-senior-swe.md`, particularly:
- Abandoning work before completion
- Creating "handover documents" for incomplete work
- Not verifying builds/tests before claiming completion
- Giving up when faced with challenges

## Solution

Implement a multi-layered supervision and validation system.

## Components

### 1. Agent Instructions

Location: `.github/agents/serious-senior-swe.md`

Enhanced with explicit requirements:
- Must complete ALL requirements before finishing
- Cannot abandon work or create handover docs for incomplete work
- Must run validation script before completion
- Token/context limits are soft caps (hard cap is 12x higher)
- Must fix all errors before completion

### 2. Validation Script

Location: `scripts/validate_agent_compliance.sh`

Automated checks for common anti-patterns:

#### Handover Document Detection
```bash
if find docs/引き継ぎ資料 -name "*.md" -type f 2>/dev/null | grep -q .; then
    # Check if work is actually complete
    # Error if handover docs + incomplete work markers
fi
```

#### TODO Comment Detection
```bash
TODO_COUNT=$(git diff HEAD~5 -- '*.dart' | grep -E "^\+.*//.*TODO|^\+.*//.*FIXME" | wc -l)
if [ "$TODO_COUNT" -gt 0 ]; then
    echo "WARNING: Found $TODO_COUNT new TODO/FIXME comments"
fi
```

#### Incomplete Work Markers
```bash
INCOMPLETE_MARKERS=$(git log --all --oneline -20 | grep -iE "WIP|work in progress|incomplete|partial")
if [ "$INCOMPLETE_MARKERS" -gt 0 ]; then
    echo "ERROR: Found incomplete work markers in commits"
    exit 1
fi
```

#### Flutter Analysis
```bash
flutter analyze --no-fatal-infos 2>&1
ERROR_COUNT=$(grep -E "^\s*error •" | wc -l)
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "ERROR: Analysis found $ERROR_COUNT errors"
    exit 1
fi
```

#### Self-Inspection
```bash
# Process tree inspection
ps -ef | head -50

# Environment variables
env | grep -iE "copilot|github|runner|agent"

# Verify running in proper environment
if [ -n "$GITHUB_ACTIONS" ]; then
    echo "Running in GitHub Actions"
fi
```

### 3. Workflow Integration

Location: `.github/workflows/copilot-setup-steps.yml`

The validation script is **mandatory** in the CI pipeline:

```yaml
- name: Validate Agent Compliance
  run: |
    if [ -f scripts/validate_agent_compliance.sh ]; then
      chmod +x scripts/validate_agent_compliance.sh
      ./scripts/validate_agent_compliance.sh
    else
      echo "ERROR: Agent compliance script not found!"
      exit 1
    fi
```

Changed from `|| true` (optional) to hard failure if script missing or fails.

### 4. Agent Instructions Update

Added section 19 to agent instructions:

```markdown
19. **エージェント監視について**
    
    - `scripts/validate_agent_compliance.sh` は必ず存在しなければならない
    - このスクリプトはエージェントの作業完了を検証する
    - スクリプトが失敗した場合、作業は未完了とみなされる
    - 削除してはならない、無効化してはならない
```

## How It Works

### Development Flow

1. Agent receives task
2. Agent works on implementation
3. Before claiming completion, agent must:
   - Run `flutter analyze` → 0 errors
   - Run `flutter test` → All tests pass
   - Run `scripts/validate_agent_compliance.sh` → Pass all checks
4. Only after passing all checks can agent report completion

### CI/CD Flow

1. Code pushed to PR
2. CI runs `copilot-setup-steps` job
3. Validation script executes:
   - Checks for anti-patterns
   - Verifies code quality
   - Inspects environment
4. If validation fails → CI fails → Agent must fix issues
5. Only when validation passes → CI succeeds

### Enforcement Mechanisms

**Level 1: Instructions** - Agent should follow willingly
**Level 2: Validation Script** - Automated checks
**Level 3: CI Pipeline** - Hard failure prevents merging
**Level 4: Human Review** - Final safeguard

## Validation Checks

### ✅ Pass Conditions

- No error-level analysis issues
- No "WIP" or "incomplete" commit messages
- No handover documents for incomplete work
- No excessive new TODO comments
- All existing tests pass

### ❌ Fail Conditions

- Analysis errors found
- Incomplete work markers in commits
- Handover documents + incomplete work
- Validation script missing or deleted

### ⚠️ Warnings

- New TODO/FIXME comments
- Analysis warnings (not blocking)
- High warning count

## Testing the System

### Manual Testing
```bash
cd /home/runner/work/vagina/vagina
./scripts/validate_agent_compliance.sh
```

### In CI
Push code to branch and check Actions tab for validation results.

## Benefits

1. **Consistency**: Agents can't skip steps
2. **Quality**: Code must pass analysis before completion
3. **Traceability**: Logs show what was checked
4. **Preventive**: Catches issues before merge
5. **Self-Aware**: Agent can inspect its own environment

## Limitations

- Cannot prevent all forms of agent misbehavior
- Relies on agent cooperation (Level 1)
- May have false positives/negatives
- Requires maintenance as codebase evolves

## Future Enhancements

1. **Deeper Analysis**:
   - Test coverage requirements
   - Performance benchmarks
   - Security scans

2. **Agent Monitoring**:
   - Token usage tracking
   - Time spent per task
   - Success rate metrics

3. **Automated Remediation**:
   - Auto-fix common issues
   - Suggest corrections
   - Template enforcement

4. **Multi-Agent Coordination**:
   - Supervisor agent
   - Peer review agents
   - Specialized validation agents
