# 2L Commit Iteration - Force Commit Despite Validation

Manually commit the current iteration even if validation failed or hasn't run yet.

## Usage

```bash
/2l-commit-iteration
```

**With custom message:**
```bash
/2l-commit-iteration "Manual commit: partial completion"
```

---

## What This Does

Creates a git commit and tag for the current iteration:

1. Stages all changes
2. Creates commit with 2L metadata
3. Creates git tag: `2l-plan-{N}-iter-{M}`
4. Updates config with commit hash and tag
5. Marks iteration as COMPLETE (even if validation failed)

**⚠️ WARNING:** This bypasses validation. Use with caution.

---

## When to Use This

### Valid Use Cases:
- ✅ Validation failed on minor issues, but you want a checkpoint
- ✅ Partial completion of iteration (documenting progress)
- ✅ Testing the commit system
- ✅ Creating recovery points during development

### Invalid Use Cases:
- ❌ Avoiding fixing bugs
- ❌ Rushing past critical errors
- ❌ Breaking the build intentionally

---

## Commit Logic

```bash
#!/bin/bash

CUSTOM_MESSAGE="$1"

# Validate git initialized
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not a git repository"
    echo "Initialize git first: git init"
    exit 1
fi

# Read config
CONFIG_FILE=".2L/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ No 2L config found"
    exit 1
fi

# Get current state
CURRENT_PLAN=$(yq eval '.current_plan' $CONFIG_FILE)
CURRENT_ITER=$(yq eval '.global_iteration_counter' $CONFIG_FILE)

if [ -z "$CURRENT_PLAN" ] || [ -z "$CURRENT_ITER" ]; then
    echo "❌ No active plan or iteration"
    exit 1
fi

echo "📋 Current State"
echo "   Plan: ${CURRENT_PLAN}"
echo "   Global Iteration: ${CURRENT_ITER}"

# Get iteration details from master plan
MASTER_PLAN_FILE=$(yq eval ".plans[] | select(.plan_id == \"${CURRENT_PLAN}\") | .master_plan_file" $CONFIG_FILE)

if [ -z "$MASTER_PLAN_FILE" ] || [ ! -f "$MASTER_PLAN_FILE" ]; then
    # No master plan (standalone iteration mode)
    ITERATION_VISION="Standalone iteration ${CURRENT_ITER}"
    LOCAL_ITER_ID=${CURRENT_ITER}
    TOTAL_ITERS=1
else
    # Get from master plan
    ITERATION_VISION=$(yq eval "
        .iterations[] |
        select(.global_iteration_number == ${CURRENT_ITER}) |
        .vision
    " $MASTER_PLAN_FILE)

    LOCAL_ITER_ID=$(yq eval "
        .iterations[] |
        select(.global_iteration_number == ${CURRENT_ITER}) |
        .iteration_id
    " $MASTER_PLAN_FILE)

    TOTAL_ITERS=$(yq eval '.total_iterations' $MASTER_PLAN_FILE)

    if [ -z "$ITERATION_VISION" ]; then
        ITERATION_VISION="Iteration ${CURRENT_ITER}"
    fi
fi

echo "   Vision: ${ITERATION_VISION}"

# Check if already committed
EXISTING_TAG="2l-${CURRENT_PLAN}-iter-${CURRENT_ITER}"
if git tag -l | grep -q "^${EXISTING_TAG}$"; then
    echo ""
    echo "⚠️  Iteration already committed with tag: ${EXISTING_TAG}"
    echo ""
    read -p "Re-commit anyway? This will update the tag. (y/N): " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Commit cancelled."
        exit 0
    fi

    # Delete existing tag
    git tag -d $EXISTING_TAG
fi

# Check if there are changes to commit
if [ -z "$(git status --porcelain)" ]; then
    echo ""
    echo "⚠️  No changes to commit"
    echo ""
    read -p "Create empty commit anyway? (y/N): " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Commit cancelled."
        exit 0
    fi

    ALLOW_EMPTY="--allow-empty"
else
    ALLOW_EMPTY=""
fi

# Show what will be committed
echo ""
echo "📝 Changes to commit:"
git status --short | head -20

if [ $(git status --short | wc -l) -gt 20 ]; then
    echo "... and $(($(git status --short | wc -l) - 20)) more files"
fi

# Prepare commit message
if [ -n "$CUSTOM_MESSAGE" ]; then
    COMMIT_TITLE="$CUSTOM_MESSAGE"
else
    COMMIT_TITLE="2L Iteration ${CURRENT_ITER} (Plan ${CURRENT_PLAN})"
fi

COMMIT_MSG=$(cat <<EOF
${COMMIT_TITLE}

Vision: ${ITERATION_VISION}
Status: FORCE_COMMITTED (validation bypassed)
Plan: ${CURRENT_PLAN} (iteration ${LOCAL_ITER_ID}/${TOTAL_ITERS})

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)

# Confirm commit
echo ""
echo "🔖 Commit Details"
echo ""
echo "Tag: ${EXISTING_TAG}"
echo "Message: ${COMMIT_TITLE}"
echo ""
echo "⚠️  This will:"
echo "  - Commit all changes (staged and unstaged)"
echo "  - Create tag: ${EXISTING_TAG}"
echo "  - Mark iteration as COMPLETE in config"
echo "  - Skip validation checks"
echo ""
read -p "Proceed with forced commit? (y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Commit cancelled."
    exit 0
fi

# Perform commit
echo ""
echo "💾 Committing..."

# Stage all changes
git add .

# Create commit
git commit ${ALLOW_EMPTY} -m "${COMMIT_MSG}"

if [ $? -ne 0 ]; then
    echo "❌ Git commit failed"
    exit 1
fi

COMMIT_HASH=$(git rev-parse HEAD)

echo "✅ Commit created: ${COMMIT_HASH:0:8}"

# Create tag
git tag "${EXISTING_TAG}"

if [ $? -ne 0 ]; then
    echo "❌ Git tag failed"
    exit 1
fi

echo "✅ Tag created: ${EXISTING_TAG}"

# Update config
echo "📝 Updating config..."

if [ -n "$MASTER_PLAN_FILE" ] && [ -f "$MASTER_PLAN_FILE" ]; then
    # Update master plan
    python3 <<PYTHON
import yaml

with open('${MASTER_PLAN_FILE}', 'r') as f:
    master_plan = yaml.safe_load(f)

# Find and update iteration
for iteration in master_plan.get('iterations', []):
    if iteration.get('global_iteration_number') == ${CURRENT_ITER}:
        iteration['status'] = 'COMPLETE'
        iteration['git_commit'] = '${COMMIT_HASH}'
        iteration['git_tag'] = '${EXISTING_TAG}'
        iteration['completed_at'] = datetime.now().isoformat()
        break

# Write updated master plan
with open('${MASTER_PLAN_FILE}', 'w') as f:
    yaml.dump(master_plan, f, default_flow_style=False, sort_keys=False)

print("✅ Master plan updated")
PYTHON
fi

# Update global config
python3 <<PYTHON
import yaml
from datetime import datetime

with open('${CONFIG_FILE}', 'r') as f:
    config = yaml.safe_load(f)

# Update plan status if needed
for plan in config.get('plans', []):
    if plan.get('plan_id') == '${CURRENT_PLAN}':
        # Check if this was the last iteration
        if plan.get('status') == 'IN_PROGRESS':
            # Would need to check if all iterations complete
            # For now, keep as IN_PROGRESS
            pass
        break

# Write updated config
with open('${CONFIG_FILE}', 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False)

print("✅ Config updated")
PYTHON

echo ""
echo "🎉 Iteration committed!"
echo ""
echo "Commit: ${COMMIT_HASH:0:8}"
echo "Tag: ${EXISTING_TAG}"

# Push to GitHub if remote exists
if git remote get-url origin > /dev/null 2>&1; then
    REPO_URL=$(git remote get-url origin)
    echo ""
    echo "📤 Pushing to GitHub: ${REPO_URL}"

    # Get current branch
    BRANCH=$(git branch --show-current)

    # Push commits
    if git push origin $BRANCH 2>&1; then
        echo "✅ Pushed to ${BRANCH}"

        # Push tags
        if git push origin ${EXISTING_TAG} 2>&1; then
            echo "✅ Pushed tag: ${EXISTING_TAG}"
        else
            echo "⚠️  Failed to push tag"
        fi
    else
        echo "⚠️  Failed to push to GitHub"
        echo "   You can push manually: git push origin ${BRANCH} && git push origin ${EXISTING_TAG}"
    fi
fi

echo ""
echo "⚠️  Remember: This iteration was force-committed."
echo "   Validation may have been skipped."
echo "   Review and fix any issues before continuing."
echo ""
echo "Next steps:"
echo "  - Review committed code"
echo "  - Run tests manually: npm test"
echo "  - Fix any issues: /2l-task \"fix...\""
echo "  - Continue: /2l-next"
```

---

## Example Workflow

### Scenario 1: Partial Completion Checkpoint

```bash
# Working on iteration 3
# Made good progress but validation fails on minor issues
# Want to checkpoint before continuing

/2l-commit-iteration "WIP: Core features complete, styling remaining"

# Creates commit and tag
# Can continue work and fix styling later
# Can rollback to this point if needed
```

### Scenario 2: Testing Iteration System

```bash
# Testing the 2L workflow
# Don't want to wait for full validation

/2l-commit-iteration "Test commit"

# Quickly creates checkpoint
# Can iterate on workflow
```

### Scenario 3: Validation Blocked on External Issue

```bash
# Iteration complete
# Validation fails because external API is down
# Not a code issue

/2l-commit-iteration "Iteration complete - validation blocked by external API"

# Commits anyway
# Can re-validate later when API is up
```

---

## What Gets Committed

**All changes in working directory:**
- Staged files
- Unstaged files
- New untracked files

**Exception:** Files in `.gitignore` are still ignored.

---

## Comparison with Auto-Commit

| Aspect | Auto-Commit (Orchestrator) | Force-Commit (Manual) |
|--------|---------------------------|----------------------|
| **Trigger** | Validation PASS | User command |
| **Validation** | Required | Bypassed |
| **Use case** | Normal flow | Override/checkpoint |
| **Status in commit** | PASS | FORCE_COMMITTED |
| **Safety** | High | User responsibility |

---

## Safety Considerations

### This Command:
- ✅ Creates permanent git commit
- ✅ Marks iteration as COMPLETE
- ✅ Bypasses validation
- ⚠️ May commit broken code
- ⚠️ May commit incomplete features

### Use Responsibly:
- Document reason in commit message
- Fix issues before continuing
- Don't rely on force-commit as normal workflow

---

## Error Handling

**If not a git repository:**
```
❌ Not a git repository
Initialize git first: git init
```

**If no active iteration:**
```
❌ No active plan or iteration
```

**If no changes:**
```
⚠️  No changes to commit

Create empty commit anyway? (y/N):
```

**If already committed:**
```
⚠️  Iteration already committed with tag: 2l-plan-1-iter-3

Re-commit anyway? This will update the tag. (y/N):
```

---

## Integration with Other Commands

**After force-commit:**
```bash
/2l-status          # Shows iteration as COMPLETE
/2l-next            # Advance to next iteration
/2l-list-iterations # Shows force-committed iteration
```

**Checking force-committed iterations:**
```bash
git log --oneline | grep "FORCE_COMMITTED"
```

---

## Recovery

If you force-committed bad code:

```bash
# Rollback to previous iteration
/2l-rollback 2

# Or reset the commit (before pushing)
git reset HEAD~1

# Or amend the commit
git add .
git commit --amend
```

---

## Prerequisites

- Git repository initialized
- Active plan and iteration
- Working directory (clean or dirty - both work)

---

## Notes

- **Use sparingly:** Force-commit is an escape hatch, not normal workflow
- **Document why:** Always provide reason in commit message
- **Fix before continuing:** Don't build on broken foundations
- **Git preserves all:** Can always recover or revert

---

**Remember:** With great power comes great responsibility. Force-commit bypasses safety checks - use wisely.
