# 2L List Plans - Show All Plans

List all plans with their status, iterations, and metadata.

## Usage

```bash
/2l-list-plans
```

Shows all plans in `.2L/` directory with detailed status information.

---

## Output Format

```
📋 2L Plans

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
All Plans (3 total)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[✅] plan-1: Initial MVP
     Status: COMPLETE
     Created: 2025-09-28
     Strategy: single-iteration
     Iterations: 1 (1 complete, 0 pending)
     Files:
       • vision.md
       • master-plan.yaml
     Git tags: 2l-plan-1-iter-1

[🔄] plan-2: Personal Finance Dashboard
     Status: IN_PROGRESS  ← CURRENT
     Created: 2025-10-01
     Strategy: multi-iteration (3 iterations)
     Iterations: 3 (1 complete, 1 in progress, 1 pending)
     Files:
       • vision.md
       • master-plan.yaml
       • master-exploration/ (2 reports)
     Git tags: 2l-plan-2-iter-2
     Current: iteration-3 (building)

[📝] plan-3: Enhanced Features
     Status: VISIONED
     Created: 2025-10-02
     Strategy: (not planned yet)
     Files:
       • vision.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total Plans: 3
    Complete: 1
    In Progress: 1
    Visioned: 1
    Planned: 0
    Abandoned: 0

  Total Iterations: 4
    Complete: 2
    In Progress: 1
    Pending: 1

  Current Plan: plan-2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Actions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  View current plan status:
    /2l-status

  View all iterations:
    /2l-list-iterations

  Continue current plan:
    /2l-continue

  Start new plan:
    /2l-vision
```

---

## Display Logic

```bash
#!/bin/bash

CONFIG_FILE=".2L/config.yaml"

# Check if .2L exists
if [ ! -d ".2L" ]; then
    echo "📋 2L Plans"
    echo ""
    echo "No plans found. Directory .2L/ does not exist."
    echo ""
    echo "Get started:"
    echo "  /2l-vision"
    exit 0
fi

# Find all plan directories
PLAN_DIRS=$(find .2L -maxdepth 1 -type d -name "plan-*" | sort -V)

if [ -z "$PLAN_DIRS" ]; then
    echo "📋 2L Plans"
    echo ""
    echo "No plans found in .2L/"
    echo ""
    echo "Get started:"
    echo "  /2l-vision"
    exit 0
fi

# Get current plan if config exists
CURRENT_PLAN=""
if [ -f "$CONFIG_FILE" ]; then
    CURRENT_PLAN=$(grep "current_plan:" $CONFIG_FILE | awk '{print $2}')
fi

echo "📋 2L Plans"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "All Plans ($(echo "$PLAN_DIRS" | wc -l) total)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Counters for summary
TOTAL_PLANS=0
COMPLETE_COUNT=0
IN_PROGRESS_COUNT=0
VISIONED_COUNT=0
PLANNED_COUNT=0
ABANDONED_COUNT=0
TOTAL_ITERATIONS=0
COMPLETE_ITERATIONS=0
IN_PROGRESS_ITERATIONS=0
PENDING_ITERATIONS=0

# Process each plan
for PLAN_DIR in $PLAN_DIRS; do
    TOTAL_PLANS=$((TOTAL_PLANS + 1))

    PLAN_ID=$(basename $PLAN_DIR)

    # Get plan details from config
    if [ -f "$CONFIG_FILE" ]; then
        PLAN_NAME=$(grep -A10 "plan_id: ${PLAN_ID}" $CONFIG_FILE | grep "name:" | head -1 | sed 's/.*name: "\(.*\)"/\1/')
        PLAN_STATUS=$(grep -A10 "plan_id: ${PLAN_ID}" $CONFIG_FILE | grep "status:" | head -1 | awk '{print $2}')
        PLAN_CREATED=$(grep -A10 "plan_id: ${PLAN_ID}" $CONFIG_FILE | grep "created_at:" | head -1 | awk '{print $2}' | cut -d'T' -f1)
    else
        PLAN_NAME=$(basename $PLAN_DIR)
        PLAN_STATUS="UNKNOWN"
        PLAN_CREATED="Unknown"
    fi

    # Update counters
    case "$PLAN_STATUS" in
        COMPLETE) COMPLETE_COUNT=$((COMPLETE_COUNT + 1)) ;;
        IN_PROGRESS) IN_PROGRESS_COUNT=$((IN_PROGRESS_COUNT + 1)) ;;
        VISIONED) VISIONED_COUNT=$((VISIONED_COUNT + 1)) ;;
        PLANNED) PLANNED_COUNT=$((PLANNED_COUNT + 1)) ;;
        ABANDONED) ABANDONED_COUNT=$((ABANDONED_COUNT + 1)) ;;
    esac

    # Status icon
    case "$PLAN_STATUS" in
        COMPLETE) ICON="✅" ;;
        IN_PROGRESS) ICON="🔄" ;;
        VISIONED) ICON="📝" ;;
        PLANNED) ICON="📊" ;;
        ABANDONED) ICON="⚠️ " ;;
        *) ICON="❓" ;;
    esac

    echo "[${ICON}] ${PLAN_ID}: ${PLAN_NAME}"

    # Show current marker
    if [ "$PLAN_ID" = "$CURRENT_PLAN" ]; then
        echo "     Status: ${PLAN_STATUS}  ← CURRENT"
    else
        echo "     Status: ${PLAN_STATUS}"
    fi

    echo "     Created: ${PLAN_CREATED}"

    # Check for master plan
    if [ -f "${PLAN_DIR}/master-plan.yaml" ]; then
        STRATEGY=$(grep "strategy:" ${PLAN_DIR}/master-plan.yaml | awk '{print $2}')
        TOTAL_ITER=$(grep "total_iterations:" ${PLAN_DIR}/master-plan.yaml | awk '{print $2}')
        echo "     Strategy: ${STRATEGY}"

        if [ "$STRATEGY" = "multi-iteration" ]; then
            echo -n "              (${TOTAL_ITER} iterations)"
        fi
        echo ""

        # Count iteration statuses
        ITER_DIRS=$(find ${PLAN_DIR} -maxdepth 1 -type d -name "iteration-*" | sort -V)
        ITER_COUNT=$(echo "$ITER_DIRS" | grep -v "^$" | wc -l)

        if [ $ITER_COUNT -gt 0 ]; then
            # Count completed, in progress, pending
            PLAN_COMPLETE=0
            PLAN_IN_PROGRESS=0
            PLAN_PENDING=0

            for ITER_DIR in $ITER_DIRS; do
                if [ -f "${ITER_DIR}/validation/validation-report.md" ]; then
                    VAL_STATUS=$(grep "^## Status" ${ITER_DIR}/validation/validation-report.md | head -1 | awk '{print $3}')
                    if [ "$VAL_STATUS" = "PASS" ]; then
                        PLAN_COMPLETE=$((PLAN_COMPLETE + 1))
                        COMPLETE_ITERATIONS=$((COMPLETE_ITERATIONS + 1))
                    else
                        PLAN_IN_PROGRESS=$((PLAN_IN_PROGRESS + 1))
                        IN_PROGRESS_ITERATIONS=$((IN_PROGRESS_ITERATIONS + 1))
                    fi
                else
                    PLAN_IN_PROGRESS=$((PLAN_IN_PROGRESS + 1))
                    IN_PROGRESS_ITERATIONS=$((IN_PROGRESS_ITERATIONS + 1))
                fi
                TOTAL_ITERATIONS=$((TOTAL_ITERATIONS + 1))
            done

            PLAN_PENDING=$((TOTAL_ITER - ITER_COUNT))
            PENDING_ITERATIONS=$((PENDING_ITERATIONS + PLAN_PENDING))
            TOTAL_ITERATIONS=$((TOTAL_ITERATIONS + PLAN_PENDING))

            echo "     Iterations: ${TOTAL_ITER} (${PLAN_COMPLETE} complete, ${PLAN_IN_PROGRESS} in progress, ${PLAN_PENDING} pending)"
        else
            PENDING_ITERATIONS=$((PENDING_ITERATIONS + TOTAL_ITER))
            TOTAL_ITERATIONS=$((TOTAL_ITERATIONS + TOTAL_ITER))
            echo "     Iterations: ${TOTAL_ITER} (0 started)"
        fi
    else
        echo "     Strategy: (not planned yet)"
    fi

    # List files
    echo "     Files:"
    [ -f "${PLAN_DIR}/vision.md" ] && echo "       • vision.md"

    if [ -f "${PLAN_DIR}/master-plan.yaml" ]; then
        echo "       • master-plan.yaml"
    fi

    if [ -d "${PLAN_DIR}/master-exploration" ]; then
        REPORT_COUNT=$(ls ${PLAN_DIR}/master-exploration/*.md 2>/dev/null | wc -l)
        echo "       • master-exploration/ (${REPORT_COUNT} reports)"
    fi

    # Show git tags
    GIT_TAGS=$(git tag -l "2l-${PLAN_ID}-*" 2>/dev/null)
    if [ -n "$GIT_TAGS" ]; then
        TAG_COUNT=$(echo "$GIT_TAGS" | wc -l)
        LATEST_TAG=$(echo "$GIT_TAGS" | tail -1)
        echo "     Git tags: ${TAG_COUNT} total, latest: ${LATEST_TAG}"
    fi

    # Show current iteration if in progress
    if [ "$PLAN_STATUS" = "IN_PROGRESS" ]; then
        CURRENT_ITER=$(find ${PLAN_DIR} -maxdepth 1 -type d -name "iteration-*" | sort -V | tail -1)
        if [ -n "$CURRENT_ITER" ]; then
            ITER_NUM=$(basename $CURRENT_ITER | sed 's/iteration-//')

            # Determine phase
            if [ -d "${CURRENT_ITER}/validation" ]; then
                PHASE="validating"
            elif [ -d "${CURRENT_ITER}/integration" ]; then
                PHASE="integrating"
            elif [ -d "${CURRENT_ITER}/building" ]; then
                PHASE="building"
            elif [ -d "${CURRENT_ITER}/plan" ]; then
                PHASE="planning"
            elif [ -d "${CURRENT_ITER}/exploration" ]; then
                PHASE="exploring"
            else
                PHASE="starting"
            fi

            echo "     Current: iteration-${ITER_NUM} (${PHASE})"
        fi
    fi

    echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Total Plans: ${TOTAL_PLANS}"
echo "    Complete: ${COMPLETE_COUNT}"
echo "    In Progress: ${IN_PROGRESS_COUNT}"
echo "    Visioned: ${VISIONED_COUNT}"
echo "    Planned: ${PLANNED_COUNT}"
if [ $ABANDONED_COUNT -gt 0 ]; then
    echo "    Abandoned: ${ABANDONED_COUNT}"
fi
echo ""
echo "  Total Iterations: ${TOTAL_ITERATIONS}"
echo "    Complete: ${COMPLETE_ITERATIONS}"
echo "    In Progress: ${IN_PROGRESS_ITERATIONS}"
echo "    Pending: ${PENDING_ITERATIONS}"
echo ""

if [ -n "$CURRENT_PLAN" ]; then
    echo "  Current Plan: ${CURRENT_PLAN}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Actions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  View current plan status:"
echo "    /2l-status"
echo ""
echo "  View all iterations:"
echo "    /2l-list-iterations"
echo ""

if [ "$IN_PROGRESS_COUNT" -gt 0 ]; then
    echo "  Continue current plan:"
    echo "    /2l-continue"
    echo ""
fi

echo "  Start new plan:"
echo "    /2l-vision"
echo ""
```

---

## Examples

### Multiple Plans
```
$ /2l-list-plans

📋 2L Plans

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
All Plans (3 total)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[✅] plan-1: Initial MVP
     Status: COMPLETE
     Created: 2025-09-28
     Strategy: single-iteration
     Iterations: 1 (1 complete, 0 pending)
     Git tags: 1 total, latest: 2l-plan-1-iter-1

[🔄] plan-2: Personal Finance Dashboard
     Status: IN_PROGRESS  ← CURRENT
     Created: 2025-10-01
     Strategy: multi-iteration (3 iterations)
     Iterations: 3 (1 complete, 1 in progress, 1 pending)
     Current: iteration-3 (building)

[📝] plan-3: Enhanced Features
     Status: VISIONED
     Created: 2025-10-02
     Strategy: (not planned yet)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total Plans: 3
    Complete: 1
    In Progress: 1
    Visioned: 1

  Total Iterations: 5
    Complete: 2
    In Progress: 1
    Pending: 2

  Current Plan: plan-2
```

### No Plans
```
$ /2l-list-plans

📋 2L Plans

No plans found. Directory .2L/ does not exist.

Get started:
  /2l-vision
```

---

## Integration with Other Commands

- **After /2l-vision**: Shows new plan with VISIONED status
- **After /2l-plan**: Shows plan with PLANNED status
- **During /2l-mvp**: Shows plan with IN_PROGRESS status
- **After completion**: Shows plan with COMPLETE status

---

## Use Cases

**Project Overview**: See all plans and their states at a glance
**Planning**: Review completed work before starting new plan
**Debugging**: Check which plans exist and their status
**Learning**: Understand the 2L plan structure

---

Now listing all your plans...
