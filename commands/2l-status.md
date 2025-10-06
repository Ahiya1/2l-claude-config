# 2L Status - Show Current State

Display the current state of all plans, iterations, and progress.

## Usage

```bash
/2l-status
```

No arguments needed - reads from `.2L/config.yaml` and displays complete status.

---

## What This Shows

### Plan Summary
- Current active plan
- Plan status (VISIONED, PLANNED, IN_PROGRESS, COMPLETE, ABANDONED)
- Total plans created
- Vision and master plan file locations

### Iteration Progress
- Total iterations across all plans
- Current iteration (if in progress)
- Completed iterations with git tags
- Pending iterations

### Recent Activity
- Last git commit (if any)
- Last validation status
- Current phase (if iteration in progress)

---

## Output Format

```
📊 2L Status Report

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Current Plan: plan-2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Plan Details:
  Name: Personal Finance Dashboard
  Status: IN_PROGRESS
  Created: 2025-10-01

  Vision: .2L/plan-2/vision.md
  Master Plan: .2L/plan-2/master-plan.yaml

  Strategy: multi-iteration (3 iterations)
  Total Iterations: 3

Iteration Progress:
  ✅ Iteration 1: Foundation (Auth + Database + API)
     Status: COMPLETE
     Duration: 5.2 hours
     Git: 2l-plan-2-iter-1 (a1b2c3d)
     Validation: PASS

  🔄 Iteration 2: Core UI (Dashboard + Transactions)
     Status: IN_PROGRESS
     Current Phase: Building (3/4 builders complete)
     Started: 2025-10-02 10:30

  ⏳ Iteration 3: Advanced Features
     Status: PENDING
     Depends on: Iteration 2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
All Plans
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✅ plan-1: Initial MVP (COMPLETE)
     Created: 2025-09-28
     Iterations: 1 (all complete)

  🔄 plan-2: Personal Finance Dashboard (IN_PROGRESS)
     Created: 2025-10-01
     Iterations: 1/3 complete

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Global Iterations
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total: 4 (2 complete, 1 in progress, 1 pending)

  ✅ Global #1 (plan-1, iter-1): Initial Features
  ✅ Global #2 (plan-2, iter-1): Foundation
  🔄 Global #3 (plan-2, iter-2): Core UI
  ⏳ Global #4 (plan-2, iter-3): Advanced Features

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next Steps
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Resume current iteration:
    /2l-continue

  Advance to next iteration (when current completes):
    /2l-next

  View all plans:
    /2l-list-plans

  View all iterations:
    /2l-list-iterations
```

---

## Status Detection Logic

```bash
#!/bin/bash

CONFIG_FILE=".2L/config.yaml"

# Check if .2L exists
if [ ! -d ".2L" ]; then
    echo "📊 2L Status: Not initialized"
    echo ""
    echo "No .2L directory found."
    echo ""
    echo "Get started:"
    echo "  /2l-vision              # Interactive requirements gathering"
    echo "  /2l-mvp \"description\"  # Full autonomy mode"
    exit 0
fi

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "📊 2L Status: Initialized but no plans"
    echo ""
    echo "Directory exists but no config.yaml found."
    echo ""
    echo "Get started:"
    echo "  /2l-vision"
    exit 0
fi

# Read config
CURRENT_PLAN=$(grep "current_plan:" $CONFIG_FILE | awk '{print $2}')

if [ -z "$CURRENT_PLAN" ]; then
    echo "📊 2L Status: No active plan"
    echo ""
    echo "Config exists but no current_plan set."
    echo ""
    echo "Create a plan:"
    echo "  /2l-vision"
    exit 0
fi

# Get plan details
PLAN_DIR=".2L/${CURRENT_PLAN}"

# Read plan status from config
PLAN_STATUS=$(grep -A10 "plan_id: ${CURRENT_PLAN}" $CONFIG_FILE | grep "status:" | head -1 | awk '{print $2}')
PLAN_NAME=$(grep -A10 "plan_id: ${CURRENT_PLAN}" $CONFIG_FILE | grep "name:" | head -1 | sed 's/.*name: "\(.*\)"/\1/')
PLAN_CREATED=$(grep -A10 "plan_id: ${CURRENT_PLAN}" $CONFIG_FILE | grep "created_at:" | head -1 | awk '{print $2}')

# Check files
HAS_VISION=false
HAS_MASTER_PLAN=false

[ -f "${PLAN_DIR}/vision.md" ] && HAS_VISION=true
[ -f "${PLAN_DIR}/master-plan.yaml" ] && HAS_MASTER_PLAN=true

# Display current plan details
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Current Plan: ${CURRENT_PLAN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Plan Details:"
echo "  Name: ${PLAN_NAME}"
echo "  Status: ${PLAN_STATUS}"
echo "  Created: ${PLAN_CREATED}"
echo ""

if [ "$HAS_VISION" = true ]; then
    echo "  Vision: ${PLAN_DIR}/vision.md"
fi

if [ "$HAS_MASTER_PLAN" = true ]; then
    echo "  Master Plan: ${PLAN_DIR}/master-plan.yaml"

    # Read master plan details
    TOTAL_ITERATIONS=$(grep "total_iterations:" ${PLAN_DIR}/master-plan.yaml | awk '{print $2}')
    STRATEGY=$(grep "strategy:" ${PLAN_DIR}/master-plan.yaml | awk '{print $2}')

    echo ""
    echo "  Strategy: ${STRATEGY} (${TOTAL_ITERATIONS} iterations)"
fi

echo ""

# Show iteration progress if master plan exists
if [ "$HAS_MASTER_PLAN" = true ]; then
    echo "Iteration Progress:"

    # Parse iterations from master plan and show status
    # This would iterate through the master-plan.yaml and show each iteration's status
    # For each iteration, check if directory exists and what phase it's in

    # List iteration directories
    ITERATION_DIRS=$(find ${PLAN_DIR} -maxdepth 1 -type d -name "iteration-*" | sort -V)

    for ITER_DIR in $ITERATION_DIRS; do
        GLOBAL_NUM=$(basename $ITER_DIR | sed 's/iteration-//')

        # Determine iteration status
        if [ -f "${ITER_DIR}/validation/validation-report.md" ]; then
            VALIDATION_STATUS=$(grep "^## Status" ${ITER_DIR}/validation/validation-report.md | head -1 | awk '{print $3}')

            if [ "$VALIDATION_STATUS" = "PASS" ]; then
                echo "  ✅ Iteration ${GLOBAL_NUM}: COMPLETE"
            else
                echo "  🔄 Iteration ${GLOBAL_NUM}: IN_PROGRESS (validation failed, healing...)"
            fi
        elif [ -d "${ITER_DIR}/validation" ]; then
            echo "  🔄 Iteration ${GLOBAL_NUM}: IN_PROGRESS (validating...)"
        elif [ -d "${ITER_DIR}/integration" ]; then
            echo "  🔄 Iteration ${GLOBAL_NUM}: IN_PROGRESS (integrating...)"
        elif [ -d "${ITER_DIR}/building" ]; then
            # Count builders
            BUILDER_COUNT=$(ls ${ITER_DIR}/building/*.md 2>/dev/null | wc -l)
            echo "  🔄 Iteration ${GLOBAL_NUM}: IN_PROGRESS (building, ${BUILDER_COUNT} builders)"
        elif [ -d "${ITER_DIR}/plan" ]; then
            echo "  🔄 Iteration ${GLOBAL_NUM}: IN_PROGRESS (planned, starting build...)"
        elif [ -d "${ITER_DIR}/exploration" ]; then
            echo "  🔄 Iteration ${GLOBAL_NUM}: IN_PROGRESS (exploring...)"
        else
            echo "  ⏳ Iteration ${GLOBAL_NUM}: PENDING"
        fi
    done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next Steps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

case "$PLAN_STATUS" in
    VISIONED)
        echo "  Create master plan (interactive):"
        echo "    /2l-plan"
        echo ""
        echo "  OR auto-plan and execute:"
        echo "    /2l-mvp"
        ;;
    PLANNED)
        echo "  Execute the master plan:"
        echo "    /2l-mvp"
        ;;
    IN_PROGRESS)
        echo "  Resume current iteration:"
        echo "    /2l-continue"
        echo ""
        echo "  View all iterations:"
        echo "    /2l-list-iterations"
        ;;
    COMPLETE)
        echo "  ✅ Plan complete!"
        echo ""
        echo "  Start new plan:"
        echo "    /2l-vision"
        ;;
    ABANDONED)
        echo "  ⚠️  This plan was abandoned."
        echo ""
        echo "  Start new plan:"
        echo "    /2l-vision"
        ;;
esac

echo ""
```

---

## Quick Status Checks

### Check if initialized
```bash
[ -d ".2L" ] && echo "Initialized" || echo "Not initialized"
```

### Check current plan
```bash
grep "current_plan:" .2L/config.yaml | awk '{print $2}'
```

### Count total plans
```bash
find .2L/plan-* -maxdepth 0 -type d 2>/dev/null | wc -l
```

### Count total iterations
```bash
find .2L/plan-*/iteration-* -maxdepth 0 -type d 2>/dev/null | wc -l
```

### Get current phase
```bash
# Look for most recent directory in current iteration
CURRENT_ITER=$(find .2L/plan-*/iteration-* -maxdepth 0 -type d | sort -V | tail -1)
if [ -d "$CURRENT_ITER/validation" ]; then
    echo "Validation"
elif [ -d "$CURRENT_ITER/integration" ]; then
    echo "Integration"
elif [ -d "$CURRENT_ITER/building" ]; then
    echo "Building"
elif [ -d "$CURRENT_ITER/plan" ]; then
    echo "Planning"
elif [ -d "$CURRENT_ITER/exploration" ]; then
    echo "Exploration"
fi
```

---

## Examples

### Uninitialized Project
```
$ /2l-status

📊 2L Status: Not initialized

No .2L directory found.

Get started:
  /2l-vision              # Interactive requirements gathering
  /2l-mvp "description"  # Full autonomy mode
```

### Active Development
```
$ /2l-status

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Current Plan: plan-2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Plan Details:
  Name: Personal Finance Dashboard
  Status: IN_PROGRESS
  Created: 2025-10-01

  Vision: .2L/plan-2/vision.md
  Master Plan: .2L/plan-2/master-plan.yaml

  Strategy: multi-iteration (3 iterations)

Iteration Progress:
  ✅ Iteration 2: COMPLETE
  🔄 Iteration 3: IN_PROGRESS (building, 3 builders)
  ⏳ Iteration 4: PENDING

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next Steps
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Resume current iteration:
    /2l-continue
```

### Completed Plan
```
$ /2l-status

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Current Plan: plan-1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Plan Details:
  Name: Initial MVP
  Status: COMPLETE
  Created: 2025-09-28

  Vision: .2L/plan-1/vision.md
  Master Plan: .2L/plan-1/master-plan.yaml

  Strategy: single-iteration (1 iteration)

Iteration Progress:
  ✅ Iteration 1: COMPLETE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next Steps
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✅ Plan complete!

  Start new plan:
    /2l-vision
```

---

## Integration with Other Commands

- **After /2l-vision**: Shows VISIONED status, suggests /2l-plan or /2l-mvp
- **After /2l-plan**: Shows PLANNED status, suggests /2l-mvp
- **During /2l-mvp**: Shows IN_PROGRESS with current iteration and phase
- **After completion**: Shows COMPLETE status, suggests /2l-vision for next plan

---

Now showing your 2L status...
