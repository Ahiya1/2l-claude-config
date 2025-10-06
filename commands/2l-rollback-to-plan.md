# 2L Rollback to Plan - Return to End of Specific Plan

Rollback to the last completed iteration of a specific plan.

## Usage

```bash
/2l-rollback-to-plan <plan-id>
```

**Examples:**
```bash
/2l-rollback-to-plan plan-1    # Rollback to end of plan-1
/2l-rollback-to-plan 2         # Rollback to end of plan-2
```

---

## What This Does

Rolls back to the **last completed iteration** of the specified plan:

1. Finds the plan in config
2. Determines the last COMPLETE iteration of that plan
3. Finds the git tag for that iteration
4. Performs rollback (same as `/2l-rollback`)
5. Archives all future plans and iterations

---

## Plan Identification

Accepts two formats:

### Format 1: Full Plan ID
```bash
/2l-rollback-to-plan plan-1
```

### Format 2: Plan Number
```bash
/2l-rollback-to-plan 1
```

Both resolve to the same plan.

---

## Logic

```bash
#!/bin/bash

PLAN_ARG="$1"

# Normalize plan ID
if [[ "$PLAN_ARG" =~ ^[0-9]+$ ]]; then
    # Just a number, add prefix
    PLAN_ID="plan-${PLAN_ARG}"
else
    PLAN_ID="$PLAN_ARG"
fi

# Validate git clean (same as /2l-rollback)
if [ -n "$(git status --porcelain)" ]; then
    echo "❌ Working directory has uncommitted changes."
    echo "Commit or stash first."
    exit 1
fi

# Read config
CONFIG_FILE=".2L/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ No 2L config found"
    exit 1
fi

# Find the plan
PLAN_EXISTS=$(yq eval ".plans[] | select(.plan_id == \"${PLAN_ID}\") | .plan_id" $CONFIG_FILE)

if [ -z "$PLAN_EXISTS" ]; then
    echo "❌ Plan not found: ${PLAN_ID}"
    echo ""
    echo "Available plans:"
    yq eval '.plans[] | .plan_id' $CONFIG_FILE
    exit 1
fi

# Get plan details
PLAN_STATUS=$(yq eval ".plans[] | select(.plan_id == \"${PLAN_ID}\") | .status" $CONFIG_FILE)
MASTER_PLAN_FILE=$(yq eval ".plans[] | select(.plan_id == \"${PLAN_ID}\") | .master_plan_file" $CONFIG_FILE)

echo "📋 Plan: ${PLAN_ID}"
echo "   Status: ${PLAN_STATUS}"

# Check if plan has master plan
if [ -z "$MASTER_PLAN_FILE" ] || [ ! -f "$MASTER_PLAN_FILE" ]; then
    echo "❌ Plan has no master plan file"
    exit 1
fi

# Find last COMPLETE iteration in this plan
LAST_COMPLETE_ITER=$(yq eval '
    .iterations[] |
    select(.status == "COMPLETE") |
    .global_iteration_number
' $MASTER_PLAN_FILE | tail -1)

if [ -z "$LAST_COMPLETE_ITER" ]; then
    echo "❌ No completed iterations found in ${PLAN_ID}"
    echo ""
    echo "Plan has no completed iterations to rollback to."
    exit 1
fi

# Get iteration details
ITER_VISION=$(yq eval "
    .iterations[] |
    select(.global_iteration_number == ${LAST_COMPLETE_ITER}) |
    .vision
" $MASTER_PLAN_FILE)

ITER_TAG=$(yq eval "
    .iterations[] |
    select(.global_iteration_number == ${LAST_COMPLETE_ITER}) |
    .git_tag
" $MASTER_PLAN_FILE)

# Show summary
CURRENT_PLAN=$(yq eval '.current_plan' $CONFIG_FILE)
CURRENT_ITER=$(yq eval '.global_iteration_counter' $CONFIG_FILE)

echo ""
echo "📋 Rollback to End of Plan"
echo ""
echo "Current state:"
echo "  Plan: ${CURRENT_PLAN}"
echo "  Global Iteration: ${CURRENT_ITER}"
echo ""
echo "Rolling back to:"
echo "  Plan: ${PLAN_ID}"
echo "  Last iteration: ${LAST_COMPLETE_ITER}"
echo "  Vision: ${ITER_VISION}"
echo "  Tag: ${ITER_TAG}"
echo ""
echo "⚠️  This will:"
echo "  - Rollback code to end of ${PLAN_ID}"
echo "  - Archive all plans after ${PLAN_ID}"
echo "  - Archive all iterations after ${LAST_COMPLETE_ITER}"
echo ""
read -p "Proceed? (y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Rollback cancelled."
    exit 0
fi

# Execute rollback using /2l-rollback
echo ""
echo "🔄 Executing rollback to iteration ${LAST_COMPLETE_ITER}..."
echo ""

# Call /2l-rollback with the iteration number
/2l-rollback $LAST_COMPLETE_ITER

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Rolled back to end of ${PLAN_ID}"
    echo ""
    echo "Next steps:"
    echo "  - Review ${PLAN_ID} completion state"
    echo "  - Use /2l-vision to start a new plan"
    echo "  - Or use /2l-next to continue from here"
fi
```

---

## Example Workflow

### Scenario: Multiple Plans, Want to Return to Plan 1

```bash
# Current state: plan-3, iteration 8
/2l-status

# Want to go back to end of plan-1
/2l-rollback-to-plan 1

# Shows:
# Plan: plan-1
# Last iteration: 3
# Vision: Complete authentication and user management
# Tag: 2l-plan-1-iter-3

# After rollback:
# - Code at iteration 3 state
# - plan-2 and plan-3 archived
# - Iterations 4-8 archived
```

---

## What Gets Archived

**Before rollback to plan-1:**
```yaml
current_plan: plan-3
global_iteration_counter: 8

plans:
  - plan_id: plan-1
    status: COMPLETE
    iterations:
      - iteration_id: 1
        global_iteration_number: 1
        status: COMPLETE
      - iteration_id: 2
        global_iteration_number: 2
        status: COMPLETE
      - iteration_id: 3
        global_iteration_number: 3
        status: COMPLETE

  - plan_id: plan-2
    status: COMPLETE
    iterations:
      - iteration_id: 1
        global_iteration_number: 4
        status: COMPLETE
      - iteration_id: 2
        global_iteration_number: 5
        status: COMPLETE

  - plan_id: plan-3
    status: IN_PROGRESS
    iterations:
      - iteration_id: 1
        global_iteration_number: 6
        status: COMPLETE
      - iteration_id: 2
        global_iteration_number: 7
        status: COMPLETE
      - iteration_id: 3
        global_iteration_number: 8
        status: IN_PROGRESS
```

**After `/2l-rollback-to-plan plan-1`:**
```yaml
current_plan: plan-1
global_iteration_counter: 3

plans:
  - plan_id: plan-1
    status: COMPLETE
    iterations:
      - iteration_id: 1
        global_iteration_number: 1
        status: COMPLETE
      - iteration_id: 2
        global_iteration_number: 2
        status: COMPLETE
      - iteration_id: 3
        global_iteration_number: 3
        status: COMPLETE  # Current

  - plan_id: plan-2
    status: ARCHIVED  # Archived
    archived_at: "2025-10-02T15:00:00"
    archived_reason: "Rollback to end of plan-1"
    iterations:
      - iteration_id: 1
        global_iteration_number: 4
        status: ARCHIVED
      - iteration_id: 2
        global_iteration_number: 5
        status: ARCHIVED

  - plan_id: plan-3
    status: ARCHIVED  # Archived
    archived_at: "2025-10-02T15:00:00"
    archived_reason: "Rollback to end of plan-1"
    iterations:
      - iteration_id: 1
        global_iteration_number: 6
        status: ARCHIVED
      - iteration_id: 2
        global_iteration_number: 7
        status: ARCHIVED
      - iteration_id: 3
        global_iteration_number: 8
        status: ARCHIVED
```

---

## Use Cases

### Use Case 1: Plan Direction Changed
```bash
# Completed plan-1 (auth system)
# Midway through plan-2 (payments)
# User decides: "Actually, let's pivot to notifications instead"

/2l-rollback-to-plan plan-1
# Now at end of plan-1

/2l-vision
# Create new plan-2 for notifications

/2l-mvp
# Execute new plan
```

### Use Case 2: Plan Failed Spectacularly
```bash
# plan-2 went completely wrong
# Want to restart from end of plan-1

/2l-rollback-to-plan plan-1

# Review what went wrong with plan-2
# Create better plan-2

/2l-plan
# Create new master plan

/2l-mvp
# Execute revised plan-2
```

### Use Case 3: Demo Specific Plan
```bash
# Need to demo plan-1 completion state
/2l-rollback-to-plan 1

# After demo
git checkout main  # Return to latest
```

---

## Comparison with `/2l-rollback`

| Command | Target | Use When |
|---------|--------|----------|
| `/2l-rollback 5` | Specific iteration | Know exact iteration to return to |
| `/2l-rollback-to-plan plan-1` | End of plan | Want to return to plan completion |

**Example:**
```bash
# These are equivalent if plan-1 ends at iteration 3:
/2l-rollback 3
/2l-rollback-to-plan plan-1

# But rollback-to-plan is more semantic:
# "Return to end of auth plan" vs "Return to iteration 3"
```

---

## Error Handling

**If plan not found:**
```
❌ Plan not found: plan-5

Available plans:
  plan-1
  plan-2
  plan-3
```

**If plan has no completed iterations:**
```
❌ No completed iterations found in plan-2

Plan has no completed iterations to rollback to.
```

**If git is dirty:**
```
❌ Working directory has uncommitted changes.
Commit or stash first.
```

---

## Prerequisites

- Clean git working directory
- Plan exists in config
- Plan has at least one COMPLETE iteration
- That iteration has a git tag

---

## Integration with Other Commands

**After rollback to plan:**
```bash
/2l-status            # Shows rolled-back plan as current
/2l-list-plans        # Shows archived plans
/2l-vision            # Start new plan from this point
/2l-next              # Continue from this point (if plan incomplete)
```

---

**Remember:** This is a convenience wrapper around `/2l-rollback` that targets plan boundaries instead of specific iterations.
