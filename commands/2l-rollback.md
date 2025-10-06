# 2L Rollback - Time Travel to Specific Iteration

Rollback the codebase to a specific iteration checkpoint using git tags.

## Usage

```bash
/2l-rollback <iteration-number>
```

**Example:**
```bash
/2l-rollback 3          # Rollback to iteration 3
/2l-rollback plan-2-5   # Rollback to plan-2, iteration 5
```

---

## What This Does

Rolls back your codebase to the state at the end of a specific iteration:

1. Validates git working directory is clean
2. Finds the git tag for the specified iteration
3. Checks out to that tag
4. Archives future iterations/plans in config
5. Updates `.2L/config.yaml` to reflect rolled-back state

---

## Safety Checks

Before rollback, the command validates:

### Check 1: Git is Clean
```bash
git status --porcelain
```

**If dirty:**
```
❌ Working directory has uncommitted changes.

Please commit or stash your changes first:
  git add .
  git commit -m "WIP: before rollback"

Or stash:
  git stash
```

**Must be clean to proceed.**

### Check 2: Iteration Exists
```bash
# Check if iteration has a git tag
git tag -l | grep "2l-plan-.*-iter-${ITERATION}"
```

**If not found:**
```
❌ Iteration ${ITERATION} not found.

Available iterations:
  1 (2l-plan-1-iter-1) - Foundation Setup
  2 (2l-plan-1-iter-2) - Core Features
  3 (2l-plan-1-iter-3) - User Authentication

Use: /2l-rollback <iteration-number>
```

### Check 3: Not Rolling Back to Current
```bash
# Check current iteration from config
if [ "$CURRENT_ITERATION" = "$TARGET_ITERATION" ]; then
    echo "Already at iteration $TARGET_ITERATION"
    exit 0
fi
```

---

## Iteration Number Formats

The command accepts multiple formats:

### Format 1: Global Iteration Number
```bash
/2l-rollback 5
```
Rolls back to global iteration 5 (across all plans).

### Format 2: Plan + Iteration
```bash
/2l-rollback plan-2-3
```
Rolls back to plan-2, iteration 3.

### Format 3: Tag Name
```bash
/2l-rollback 2l-plan-1-iter-2
```
Rolls back to specific git tag.

---

## Rollback Logic

```bash
#!/bin/bash

ITERATION_ARG="$1"

# Validate git clean
if [ -n "$(git status --porcelain)" ]; then
    echo "❌ Working directory has uncommitted changes."
    echo ""
    echo "Please commit or stash your changes first:"
    echo "  git add ."
    echo "  git commit -m \"WIP: before rollback\""
    echo ""
    echo "Or stash:"
    echo "  git stash"
    exit 1
fi

# Parse iteration argument
if [[ "$ITERATION_ARG" =~ ^[0-9]+$ ]]; then
    # Format 1: Global iteration number
    GLOBAL_ITER=$ITERATION_ARG
    TAG=$(git tag -l | grep "2l-.*-iter-${GLOBAL_ITER}$" | head -1)
elif [[ "$ITERATION_ARG" =~ ^plan-[0-9]+-[0-9]+$ ]]; then
    # Format 2: plan-X-Y
    TAG="2l-${ITERATION_ARG//-/-iter-}"
    TAG="${TAG/plan-/plan-}"
else
    # Format 3: Assume it's a tag name
    TAG="$ITERATION_ARG"
fi

# Validate tag exists
if ! git tag -l | grep -q "^${TAG}$"; then
    echo "❌ Iteration tag not found: ${TAG}"
    echo ""
    echo "Available iterations:"
    git tag -l "2l-*" | while read tag; do
        # Extract info from tag
        iter_num=$(echo $tag | grep -oP 'iter-\K\d+')
        # Get commit message
        msg=$(git log -1 --format=%B $tag | head -1)
        echo "  ${iter_num} (${tag}) - ${msg}"
    done
    exit 1
fi

# Get tag details
TAG_COMMIT=$(git rev-parse $TAG)
TAG_MESSAGE=$(git log -1 --format=%B $TAG | head -1)

# Extract plan and iteration info from tag
PLAN_ID=$(echo $TAG | grep -oP 'plan-\K[0-9]+')
ITER_NUM=$(echo $TAG | grep -oP 'iter-\K\d+')

# Current state
CURRENT_COMMIT=$(git rev-parse HEAD)
CURRENT_PLAN=$(yq eval '.current_plan' .2L/config.yaml)
CURRENT_ITER=$(yq eval '.global_iteration_counter' .2L/config.yaml)

# Confirm rollback
echo "📋 Rollback Summary"
echo ""
echo "Current state:"
echo "  Plan: ${CURRENT_PLAN}"
echo "  Global Iteration: ${CURRENT_ITER}"
echo "  Commit: ${CURRENT_COMMIT:0:8}"
echo ""
echo "Rolling back to:"
echo "  Tag: ${TAG}"
echo "  Plan: plan-${PLAN_ID}"
echo "  Global Iteration: ${ITER_NUM}"
echo "  Commit: ${TAG_COMMIT:0:8}"
echo "  Message: ${TAG_MESSAGE}"
echo ""
echo "⚠️  This will:"
echo "  - Checkout code to ${TAG}"
echo "  - Archive iterations ${ITER_NUM}+ in config"
echo "  - You can rollforward using git (commits preserved)"
echo ""
read -p "Proceed with rollback? (y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Rollback cancelled."
    exit 0
fi

# Perform rollback
echo ""
echo "🔄 Rolling back..."

# Checkout to tag
git checkout $TAG

if [ $? -ne 0 ]; then
    echo "❌ Git checkout failed"
    exit 1
fi

echo "✅ Code rolled back to ${TAG}"

# Update config.yaml
echo "📝 Updating config..."

# Read current config
CONFIG_FILE=".2L/config.yaml"

# Archive future iterations
# Set current iteration to rolled-back iteration
# Mark future iterations as ARCHIVED in config

python3 <<PYTHON
import yaml
from datetime import datetime

with open('${CONFIG_FILE}', 'r') as f:
    config = yaml.safe_load(f)

# Update global iteration counter
config['global_iteration_counter'] = ${ITER_NUM}

# Update current plan
config['current_plan'] = 'plan-${PLAN_ID}'

# Archive future iterations
for plan in config.get('plans', []):
    plan_id = plan.get('plan_id')

    # If this is a future plan, archive it
    if plan_id and plan_id > 'plan-${PLAN_ID}':
        plan['status'] = 'ARCHIVED'
        plan['archived_at'] = datetime.now().isoformat()
        plan['archived_reason'] = 'Rollback to iteration ${ITER_NUM}'

    # If this is the target plan or earlier, check iterations
    elif plan_id and plan_id <= 'plan-${PLAN_ID}':
        master_plan_file = plan.get('master_plan_file')
        if master_plan_file:
            with open(master_plan_file, 'r') as mf:
                master_plan = yaml.safe_load(mf)

            for iteration in master_plan.get('iterations', []):
                global_iter = iteration.get('global_iteration_number')

                # Archive iterations after target
                if global_iter and global_iter > ${ITER_NUM}:
                    iteration['status'] = 'ARCHIVED'
                    iteration['archived_at'] = datetime.now().isoformat()
                    iteration['archived_reason'] = 'Rollback to iteration ${ITER_NUM}'
                    iteration['git_commit'] = None
                    iteration['git_tag'] = None

                # Mark target as current
                elif global_iter == ${ITER_NUM}:
                    iteration['status'] = 'COMPLETE'

            # Write updated master plan
            with open(master_plan_file, 'w') as mf:
                yaml.dump(master_plan, mf, default_flow_style=False, sort_keys=False)

# Write updated config
with open('${CONFIG_FILE}', 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False)

print("✅ Config updated")
PYTHON

echo ""
echo "🎉 Rollback complete!"
echo ""
echo "Current state:"
echo "  Plan: plan-${PLAN_ID}"
echo "  Global Iteration: ${ITER_NUM}"
echo "  Tag: ${TAG}"
echo ""
echo "Next steps:"
echo "  - Review code at this checkpoint"
echo "  - Use /2l-next to advance forward"
echo "  - Or use /2l-mvp to resume from here"
echo ""
echo "To rollforward to previous state:"
echo "  git checkout ${CURRENT_COMMIT}"
echo "  (Then manually restore config.yaml)"
```

---

## What Gets Archived

When rolling back, future iterations are marked as `ARCHIVED` in config:

**Before rollback:**
```yaml
plans:
  - plan_id: plan-1
    iterations:
      - iteration_id: 1
        status: COMPLETE
      - iteration_id: 2
        status: COMPLETE
      - iteration_id: 3
        status: COMPLETE  # Rolling back to here
      - iteration_id: 4
        status: COMPLETE
```

**After `/2l-rollback 3`:**
```yaml
plans:
  - plan_id: plan-1
    iterations:
      - iteration_id: 1
        status: COMPLETE
      - iteration_id: 2
        status: COMPLETE
      - iteration_id: 3
        status: COMPLETE  # Current
      - iteration_id: 4
        status: ARCHIVED  # Archived
        archived_at: "2025-10-02T14:30:00"
        archived_reason: "Rollback to iteration 3"
        git_commit: null
        git_tag: null
```

---

## Rollforward

**To restore to the previous state:**

```bash
# Checkout to previous commit
git checkout <previous-commit-hash>

# Or if you know the tag
git checkout 2l-plan-1-iter-5

# Then restore config manually or use git
git checkout HEAD -- .2L/config.yaml
```

**Git preserves all commits and tags**, so rollback is non-destructive.

---

## Use Cases

### Use Case 1: Iteration Failed Badly
```bash
# Iteration 5 broke everything
/2l-rollback 4

# Review what went wrong
# Fix the plan or requirements
# Re-run iteration 5 fresh
/2l-next
```

### Use Case 2: Trying Different Approaches
```bash
# Completed iteration 3 with approach A
# Want to try approach B instead

/2l-rollback 2
# Modify plan for iteration 3
/2l-next  # Execute iteration 3 with new approach
```

### Use Case 3: Demo at Specific Checkpoint
```bash
# Need to demo at iteration 2 state
/2l-rollback 2

# After demo, return to latest
git checkout main
```

---

## Integration with Other Commands

### After Rollback

**To advance forward again:**
```bash
/2l-next    # Execute next iteration from rollback point
```

**To see current state:**
```bash
/2l-status  # Shows rolled-back iteration as current
```

**To list iterations:**
```bash
/2l-list-iterations  # Shows archived iterations
```

---

## Error Handling

**If git is dirty:**
```
❌ Working directory has uncommitted changes.
Commit or stash first.
```

**If iteration doesn't exist:**
```
❌ Iteration 10 not found.
Available: 1-7
```

**If already at target:**
```
ℹ️  Already at iteration 5.
No action needed.
```

**If git checkout fails:**
```
❌ Git checkout failed
Check for conflicts or uncommitted changes.
```

---

## Prerequisites

- Clean git working directory (no uncommitted changes)
- Target iteration must have a git tag (created by auto-commit)
- `.2L/config.yaml` exists
- `yq` installed for YAML manipulation

---

## Notes

- **Non-destructive:** All commits and tags are preserved
- **Reversible:** Can rollforward using git checkout
- **Safe:** Validates git state before proceeding
- **Atomic:** Either completes fully or fails safely

---

**Remember:** Rollback is time travel within your project's development timeline. All history is preserved in git.
