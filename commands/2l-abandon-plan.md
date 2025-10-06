# 2L Abandon Plan - Archive Current Plan and Rollback

Mark the current plan as abandoned and rollback to the end of the previous plan.

## Usage

```bash
/2l-abandon-plan
```

**Optional with reason:**
```bash
/2l-abandon-plan "Requirements changed - pivoting to mobile first"
```

---

## What This Does

Abandons the current plan and rolls back to the previous stable state:

1. Marks current plan as `ABANDONED` in config
2. Finds the last completed iteration of the previous plan
3. Rolls back code to that state
4. Sets previous plan as current
5. Preserves all git history

---

## Abandon Logic

```bash
#!/bin/bash

REASON="$1"

# Default reason if not provided
if [ -z "$REASON" ]; then
    REASON="Plan abandoned by user"
fi

# Validate git clean
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

# Get current plan
CURRENT_PLAN=$(yq eval '.current_plan' $CONFIG_FILE)

if [ -z "$CURRENT_PLAN" ]; then
    echo "❌ No active plan to abandon"
    exit 1
fi

echo "📋 Current Plan: ${CURRENT_PLAN}"

# Get plan details
PLAN_STATUS=$(yq eval ".plans[] | select(.plan_id == \"${CURRENT_PLAN}\") | .status" $CONFIG_FILE)
PLAN_NAME=$(yq eval ".plans[] | select(.plan_id == \"${CURRENT_PLAN}\") | .name" $CONFIG_FILE)

echo "   Name: ${PLAN_NAME}"
echo "   Status: ${PLAN_STATUS}"

# Check if already abandoned
if [ "$PLAN_STATUS" = "ABANDONED" ]; then
    echo ""
    echo "⚠️  Plan is already abandoned"
    exit 0
fi

# Find previous plan
# Plans are ordered, so find the plan before current one
PLAN_INDEX=$(yq eval ".plans[] | select(.plan_id == \"${CURRENT_PLAN}\") | key" $CONFIG_FILE)
PREV_PLAN_INDEX=$((PLAN_INDEX - 1))

if [ $PREV_PLAN_INDEX -lt 0 ]; then
    echo ""
    echo "❌ This is the first plan - cannot rollback to previous"
    echo ""
    echo "Options:"
    echo "  1. Continue with this plan: /2l-continue"
    echo "  2. Start fresh: /2l-vision (creates new plan)"
    exit 1
fi

PREV_PLAN=$(yq eval ".plans[${PREV_PLAN_INDEX}] | .plan_id" $CONFIG_FILE)
PREV_PLAN_NAME=$(yq eval ".plans[${PREV_PLAN_INDEX}] | .name" $CONFIG_FILE)
PREV_PLAN_STATUS=$(yq eval ".plans[${PREV_PLAN_INDEX}] | .status" $CONFIG_FILE)

echo ""
echo "📋 Previous Plan: ${PREV_PLAN}"
echo "   Name: ${PREV_PLAN_NAME}"
echo "   Status: ${PREV_PLAN_STATUS}"

# Confirm abandonment
echo ""
echo "⚠️  Abandon Plan"
echo ""
echo "This will:"
echo "  - Mark ${CURRENT_PLAN} as ABANDONED"
echo "  - Rollback code to end of ${PREV_PLAN}"
echo "  - Preserve all git history (can recover later)"
echo "  - Set ${PREV_PLAN} as current plan"
echo ""
echo "Reason: ${REASON}"
echo ""
read -p "Proceed with abandonment? (y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Abandonment cancelled."
    exit 0
fi

# Mark current plan as abandoned
echo ""
echo "📝 Marking ${CURRENT_PLAN} as abandoned..."

python3 <<PYTHON
import yaml
from datetime import datetime

with open('${CONFIG_FILE}', 'r') as f:
    config = yaml.safe_load(f)

# Find and update current plan
for plan in config.get('plans', []):
    if plan.get('plan_id') == '${CURRENT_PLAN}':
        plan['status'] = 'ABANDONED'
        plan['abandoned_at'] = datetime.now().isoformat()
        plan['abandoned_reason'] = '''${REASON}'''
        break

# Write updated config
with open('${CONFIG_FILE}', 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False)

print("✅ Plan marked as abandoned")
PYTHON

# Rollback to end of previous plan
echo ""
echo "🔄 Rolling back to end of ${PREV_PLAN}..."
echo ""

# Use /2l-rollback-to-plan
/2l-rollback-to-plan $PREV_PLAN

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Plan abandoned successfully"
    echo ""
    echo "Abandoned: ${CURRENT_PLAN}"
    echo "Reason: ${REASON}"
    echo ""
    echo "Current state: End of ${PREV_PLAN}"
    echo ""
    echo "Next steps:"
    echo "  - Review code at ${PREV_PLAN} completion"
    echo "  - Use /2l-vision to create new plan"
    echo "  - Or recover ${CURRENT_PLAN} by checking out its commits"
    echo ""
    echo "To recover abandoned plan:"
    echo "  git log --all --oneline | grep \"${CURRENT_PLAN}\""
    echo "  git checkout <commit-hash>"
else
    echo ""
    echo "❌ Rollback failed"
    echo "Plan marked as abandoned but rollback did not complete."
    echo "Manual intervention required."
fi
```

---

## What Gets Updated

**Before abandonment:**
```yaml
current_plan: plan-2
global_iteration_counter: 5

plans:
  - plan_id: plan-1
    name: "Authentication System"
    status: COMPLETE

  - plan_id: plan-2
    name: "Payment Integration"
    status: IN_PROGRESS  # Current, will be abandoned
```

**After `/2l-abandon-plan "Requirements changed"`:**
```yaml
current_plan: plan-1  # Rolled back to previous
global_iteration_counter: 3  # Last iteration of plan-1

plans:
  - plan_id: plan-1
    name: "Authentication System"
    status: COMPLETE  # Now current again

  - plan_id: plan-2
    name: "Payment Integration"
    status: ABANDONED  # Abandoned
    abandoned_at: "2025-10-02T15:30:00"
    abandoned_reason: "Requirements changed"
```

---

## Use Cases

### Use Case 1: Requirements Pivot
```bash
# Midway through plan-2 (payments)
# Client says: "Actually, we need notifications first"

/2l-abandon-plan "Pivoting to notifications - payment deferred"

# Now at end of plan-1
# Create new plan for notifications

/2l-vision
# Interactive vision for notifications

/2l-plan
# Create notification plan

/2l-mvp
# Execute new plan-2 (notifications)
```

### Use Case 2: Technical Blockers
```bash
# plan-2 requires external API that's not ready yet

/2l-abandon-plan "External payment API not available"

# Revert to plan-1 completion
# Work on plan-3 instead (can be done independently)

/2l-vision
# Create plan-3 for other features
```

### Use Case 3: Approach Failed
```bash
# plan-2 approach isn't working
# Want to try completely different strategy

/2l-abandon-plan "Architecture approach not suitable"

# Back at plan-1
# Create fresh plan-2 with new approach

/2l-vision
# Design new approach

/2l-plan
/2l-mvp
```

---

## Recovery: Restoring Abandoned Plan

All abandoned plan work is preserved in git. To recover:

```bash
# Find commits from abandoned plan
git log --all --oneline | grep "plan-2"

# Output:
# abc1234 2L Iteration 5 (Plan plan-2)
# def5678 2L Iteration 4 (Plan plan-2)

# Checkout to recover
git checkout abc1234

# Review the code
# If you want to continue from here:

# 1. Update config to restore plan
# Edit .2L/config.yaml
# Change plan-2 from ABANDONED to IN_PROGRESS

# 2. Continue work
/2l-continue
```

---

## Difference from Rollback

| Command | Current Plan Status | Target |
|---------|---------------------|--------|
| `/2l-rollback 3` | Unchanged | Specific iteration |
| `/2l-rollback-to-plan plan-1` | Unchanged | End of specific plan |
| `/2l-abandon-plan` | Marked ABANDONED | End of previous plan |

**Key difference:** Abandon explicitly marks the plan as failed/cancelled, while rollback is just time travel.

---

## Error Handling

**If this is the first plan:**
```
❌ This is the first plan - cannot rollback to previous

Options:
  1. Continue with this plan: /2l-continue
  2. Start fresh: /2l-vision (creates new plan)
```

**If git is dirty:**
```
❌ Working directory has uncommitted changes.
Commit or stash first.
```

**If plan already abandoned:**
```
⚠️  Plan is already abandoned
```

**If no active plan:**
```
❌ No active plan to abandon
```

---

## Integration with Other Commands

**After abandoning:**
```bash
/2l-status         # Shows previous plan as current
/2l-list-plans     # Shows abandoned plan in list
/2l-vision         # Create new plan from here
```

**To view abandoned plans:**
```bash
/2l-list-plans

# Output includes:
# plan-2 (ABANDONED) - Payment Integration
#   Abandoned: 2025-10-02
#   Reason: Requirements changed
```

---

## Prerequisites

- Clean git working directory
- Active plan exists
- At least one previous plan exists (can't abandon first plan)
- Previous plan has completed iterations

---

## Notes

- **Non-destructive:** All commits preserved in git
- **Recoverable:** Can checkout abandoned plan commits later
- **Semantic:** Marks plan as explicitly abandoned (not just rolled back)
- **Safe:** Validates state before proceeding

---

**Remember:** Abandonment is different from failure. It's a deliberate decision to stop pursuing a direction, not a bug or error.
