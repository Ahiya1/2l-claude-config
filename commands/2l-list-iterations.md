# 2L List Iterations - Show All Iterations

List all iterations across all plans with detailed status.

## Usage

```bash
/2l-list-iterations
```

Shows all iterations from all plans in chronological order.

---

## Output Format

```
🔢 2L Iterations

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
All Iterations (5 total)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[✅] Global #1 (plan-1, iteration 1)
     Name: Initial Features
     Vision: Build core MVP with auth and dashboard
     Plan: plan-1 (single-iteration strategy)
     Status: COMPLETE
     Duration: 4.5 hours
     Builders: 3 (all complete)
     Git: 2l-plan-1-iter-1 (a1b2c3d)
     Validation: PASS
     Completed: 2025-09-28

[✅] Global #2 (plan-2, iteration 1)
     Name: Foundation
     Vision: Secure foundation with auth and data layer
     Plan: plan-2 (multi-iteration, 1/3)
     Status: COMPLETE
     Duration: 5.2 hours
     Builders: 3 (all complete)
     Git: 2l-plan-2-iter-2 (b2c3d4e)
     Validation: PASS
     Completed: 2025-10-01

[🔄] Global #3 (plan-2, iteration 2)
     Name: Core UI
     Vision: User can view accounts and manage transactions
     Plan: plan-2 (multi-iteration, 2/3)  ← CURRENT
     Status: IN_PROGRESS
     Current Phase: Building (3/4 builders complete)
     Started: 2025-10-02 10:30
     Progress:
       ✅ Exploration (2 reports)
       ✅ Planning (4 files)
       🔄 Building (3/4 complete)
       ⏳ Integration (pending)
       ⏳ Validation (pending)

[⏳] Global #4 (plan-2, iteration 3)
     Name: Advanced Features
     Vision: Power features for financial planning
     Plan: plan-2 (multi-iteration, 3/3)
     Status: PENDING
     Depends on: iteration-3
     Estimated: 4 hours, 3-4 builders

[⏳] Global #5 (plan-3, iteration 1)
     Name: Enhanced Dashboard
     Plan: plan-3 (not yet planned)
     Status: PENDING (plan not started)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary by Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✅ Complete: 2
     Total duration: 9.7 hours
     All validations: PASS

  🔄 In Progress: 1
     Current phase: Building

  ⏳ Pending: 2
     Estimated total: ~8 hours

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary by Plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  plan-1: 1 iteration (1 complete)
  plan-2: 3 iterations (1 complete, 1 in progress, 1 pending)
  plan-3: 1 iteration (1 pending, not started)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Actions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  View current iteration:
    /2l-status

  Continue current iteration:
    /2l-continue

  View all plans:
    /2l-list-plans
```

---

## Display Logic

```bash
#!/bin/bash

CONFIG_FILE=".2L/config.yaml"

# Check if .2L exists
if [ ! -d ".2L" ]; then
    echo "🔢 2L Iterations"
    echo ""
    echo "No iterations found. Directory .2L/ does not exist."
    echo ""
    echo "Get started:"
    echo "  /2l-vision"
    exit 0
fi

# Find all iteration directories across all plans
ITERATION_DIRS=$(find .2L/plan-*/iteration-* -maxdepth 0 -type d 2>/dev/null | sort -V)

if [ -z "$ITERATION_DIRS" ]; then
    echo "🔢 2L Iterations"
    echo ""
    echo "No iterations found."
    echo ""
    echo "Plans may exist but no iterations started yet."
    echo ""
    echo "Get started:"
    echo "  /2l-mvp"
    exit 0
fi

# Get current plan if config exists
CURRENT_PLAN=""
if [ -f "$CONFIG_FILE" ]; then
    CURRENT_PLAN=$(grep "current_plan:" $CONFIG_FILE | awk '{print $2}')
fi

echo "🔢 2L Iterations"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "All Iterations ($(echo "$ITERATION_DIRS" | wc -l) total)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Counters
COMPLETE_COUNT=0
IN_PROGRESS_COUNT=0
PENDING_COUNT=0
TOTAL_DURATION=0

# Process each iteration
for ITER_DIR in $ITERATION_DIRS; do
    # Extract plan ID and global iteration number
    PLAN_ID=$(echo $ITER_DIR | sed 's|.2L/\(plan-[0-9]*\)/.*|\1|')
    GLOBAL_NUM=$(basename $ITER_DIR | sed 's/iteration-//')

    # Get plan details
    PLAN_DIR=".2L/${PLAN_ID}"

    # Try to get iteration details from master plan
    if [ -f "${PLAN_DIR}/master-plan.yaml" ]; then
        # This would parse YAML to get iteration name, vision, etc.
        # For now, use placeholder
        ITER_NAME="Iteration ${GLOBAL_NUM}"
        ITER_VISION="(vision from master plan)"
    else
        ITER_NAME="Iteration ${GLOBAL_NUM}"
        ITER_VISION="No master plan"
    fi

    # Determine iteration status
    if [ -f "${ITER_DIR}/validation/validation-report.md" ]; then
        VALIDATION_STATUS=$(grep "^## Status" ${ITER_DIR}/validation/validation-report.md | head -1 | awk '{print $3}')

        if [ "$VALIDATION_STATUS" = "PASS" ]; then
            STATUS="COMPLETE"
            ICON="✅"
            COMPLETE_COUNT=$((COMPLETE_COUNT + 1))
        else
            STATUS="IN_PROGRESS"
            ICON="🔄"
            IN_PROGRESS_COUNT=$((IN_PROGRESS_COUNT + 1))
        fi
    elif [ -d "${ITER_DIR}/validation" ]; then
        STATUS="IN_PROGRESS"
        ICON="🔄"
        IN_PROGRESS_COUNT=$((IN_PROGRESS_COUNT + 1))
    elif [ -d "${ITER_DIR}/integration" ]; then
        STATUS="IN_PROGRESS"
        ICON="🔄"
        IN_PROGRESS_COUNT=$((IN_PROGRESS_COUNT + 1))
    elif [ -d "${ITER_DIR}/building" ]; then
        STATUS="IN_PROGRESS"
        ICON="🔄"
        IN_PROGRESS_COUNT=$((IN_PROGRESS_COUNT + 1))
    elif [ -d "${ITER_DIR}/plan" ]; then
        STATUS="IN_PROGRESS"
        ICON="🔄"
        IN_PROGRESS_COUNT=$((IN_PROGRESS_COUNT + 1))
    elif [ -d "${ITER_DIR}/exploration" ]; then
        STATUS="IN_PROGRESS"
        ICON="🔄"
        IN_PROGRESS_COUNT=$((IN_PROGRESS_COUNT + 1))
    else
        STATUS="PENDING"
        ICON="⏳"
        PENDING_COUNT=$((PENDING_COUNT + 1))
    fi

    echo "[${ICON}] Global #${GLOBAL_NUM} (${PLAN_ID}, iteration ?)"
    echo "     Name: ${ITER_NAME}"
    echo "     Vision: ${ITER_VISION}"
    echo "     Status: ${STATUS}"

    # Show current marker
    CURRENT_ITER=$(find .2L/${CURRENT_PLAN} -maxdepth 1 -type d -name "iteration-*" 2>/dev/null | sort -V | tail -1)
    if [ "$(basename $CURRENT_ITER)" = "iteration-${GLOBAL_NUM}" ] && [ "$PLAN_ID" = "$CURRENT_PLAN" ]; then
        echo "     ← CURRENT"
    fi

    # Status-specific details
    case "$STATUS" in
        COMPLETE)
            # Show duration, git tag, etc.
            # This would be extracted from reports
            echo "     Duration: (extracted from reports)"
            echo "     Git: 2l-${PLAN_ID}-iter-${GLOBAL_NUM}"
            echo "     Validation: PASS"
            ;;
        IN_PROGRESS)
            # Show current phase
            if [ -d "${ITER_DIR}/validation" ]; then
                PHASE="Validation"
            elif [ -d "${ITER_DIR}/integration" ]; then
                PHASE="Integration"
            elif [ -d "${ITER_DIR}/building" ]; then
                BUILDER_COUNT=$(ls ${ITER_DIR}/building/*.md 2>/dev/null | wc -l)
                PHASE="Building (${BUILDER_COUNT} builders)"
            elif [ -d "${ITER_DIR}/plan" ]; then
                PHASE="Planning"
            elif [ -d "${ITER_DIR}/exploration" ]; then
                PHASE="Exploration"
            else
                PHASE="Starting"
            fi

            echo "     Current Phase: ${PHASE}"

            # Show progress
            echo "     Progress:"
            [ -d "${ITER_DIR}/exploration" ] && echo "       ✅ Exploration" || echo "       ⏳ Exploration"
            [ -d "${ITER_DIR}/plan" ] && echo "       ✅ Planning" || echo "       ⏳ Planning"
            [ -d "${ITER_DIR}/building" ] && echo "       🔄 Building" || echo "       ⏳ Building"
            [ -d "${ITER_DIR}/integration" ] && echo "       🔄 Integration" || echo "       ⏳ Integration"
            [ -d "${ITER_DIR}/validation" ] && echo "       🔄 Validation" || echo "       ⏳ Validation"
            ;;
        PENDING)
            echo "     Status: Not yet started"
            ;;
    esac

    echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary by Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  ✅ Complete: ${COMPLETE_COUNT}"
echo "  🔄 In Progress: ${IN_PROGRESS_COUNT}"
echo "  ⏳ Pending: ${PENDING_COUNT}"
echo ""

# Plan summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary by Plan"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Group by plan
for PLAN_DIR in $(find .2L -maxdepth 1 -type d -name "plan-*" | sort -V); do
    PLAN_ID=$(basename $PLAN_DIR)
    PLAN_ITERS=$(find $PLAN_DIR -maxdepth 1 -type d -name "iteration-*" 2>/dev/null | wc -l)

    if [ $PLAN_ITERS -gt 0 ]; then
        # Count statuses for this plan
        echo "  ${PLAN_ID}: ${PLAN_ITERS} iteration(s)"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Actions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  View current iteration:"
echo "    /2l-status"
echo ""

if [ $IN_PROGRESS_COUNT -gt 0 ]; then
    echo "  Continue current iteration:"
    echo "    /2l-continue"
    echo ""
fi

echo "  View all plans:"
echo "    /2l-list-plans"
echo ""
```

---

## Examples

### Multiple Iterations
```
$ /2l-list-iterations

🔢 2L Iterations

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
All Iterations (3 total)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[✅] Global #1 (plan-1, iteration 1)
     Name: Initial Features
     Status: COMPLETE
     Git: 2l-plan-1-iter-1

[✅] Global #2 (plan-2, iteration 1)
     Name: Foundation
     Status: COMPLETE
     Git: 2l-plan-2-iter-2

[🔄] Global #3 (plan-2, iteration 2)
     Name: Core UI
     Status: IN_PROGRESS  ← CURRENT
     Current Phase: Building (3 builders)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary by Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✅ Complete: 2
  🔄 In Progress: 1
  ⏳ Pending: 0
```

### No Iterations
```
$ /2l-list-iterations

🔢 2L Iterations

No iterations found.

Plans may exist but no iterations started yet.

Get started:
  /2l-mvp
```

---

## Filtering Options (Future Enhancement)

Could add flags for filtering:

```bash
/2l-list-iterations --plan plan-2        # Only plan-2 iterations
/2l-list-iterations --status complete    # Only completed
/2l-list-iterations --current            # Only current iteration
```

---

## Integration with Other Commands

- **After /2l-mvp starts**: Shows iterations as they're created
- **During execution**: Shows current iteration progress
- **After completion**: Shows complete iteration history

---

## Use Cases

**Progress Tracking**: See which iterations are done and which are pending
**Debugging**: Identify which iteration has issues
**Planning**: Review completed iterations before starting new ones
**Learning**: Understand the iteration workflow

---

Now listing all your iterations...
