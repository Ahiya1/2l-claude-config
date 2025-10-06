# 2L Next - Advance to Next Iteration

Manually advance to the next iteration in the current master plan.

## Usage

```bash
/2l-next
```

No arguments needed - automatically determines and starts the next pending iteration.

---

## What This Does

1. **Reads current plan** from `.2L/config.yaml`
2. **Reads master plan** to find iteration sequence
3. **Identifies next pending iteration**
4. **Validates prerequisites** (previous iterations complete)
5. **Spawns orchestrator** in ITERATION MODE for next iteration

---

## When to Use

✅ Current iteration is complete and validated
✅ You want to manually trigger the next iteration
✅ Multi-iteration master plan exists

❌ No master plan (use `/2l-plan` first)
❌ Current iteration not complete (use `/2l-continue`)
❌ All iterations already complete

---

## Prerequisites

- `.2L/config.yaml` exists with current_plan set
- Current plan has `master-plan.yaml`
- At least one iteration is PENDING
- Previous required iterations are COMPLETE

---

## Orchestration Logic

```bash
#!/bin/bash

CONFIG_FILE=".2L/config.yaml"

# Step 1: Validate setup
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ No active plan found."
    echo ""
    echo "Create a plan first:"
    echo "  /2l-vision"
    exit 1
fi

# Step 2: Get current plan
CURRENT_PLAN=$(grep "current_plan:" $CONFIG_FILE | awk '{print $2}')

if [ -z "$CURRENT_PLAN" ]; then
    echo "❌ No current plan set."
    echo ""
    echo "Create a plan first:"
    echo "  /2l-vision"
    exit 1
fi

PLAN_DIR=".2L/${CURRENT_PLAN}"
MASTER_PLAN="${PLAN_DIR}/master-plan.yaml"

# Step 3: Check for master plan
if [ ! -f "$MASTER_PLAN" ]; then
    echo "❌ No master plan found for ${CURRENT_PLAN}"
    echo ""
    echo "This command requires a master plan."
    echo ""
    echo "Options:"
    echo "  1. Create master plan interactively:"
    echo "     /2l-plan"
    echo ""
    echo "  2. Use /2l-mvp to auto-create and execute"
    exit 1
fi

# Step 4: Read master plan
TOTAL_ITERATIONS=$(grep "total_iterations:" $MASTER_PLAN | awk '{print $2}')

echo "📊 Master Plan: ${CURRENT_PLAN}"
echo "   Total iterations: ${TOTAL_ITERATIONS}"
echo ""

# Step 5: Find next pending iteration
# Parse master-plan.yaml to get iteration sequence
# For each iteration, check if its directory exists and status

NEXT_ITERATION_ID=""
NEXT_GLOBAL_NUM=""

# This would parse the YAML and find the first iteration without a directory
# or with incomplete status

# Simplified: Look for first iteration-* directory that doesn't exist
# or first one that exists but isn't validated

for i in $(seq 1 $TOTAL_ITERATIONS); do
    # Get global iteration number for this iteration
    # This requires parsing master-plan.yaml

    # Check if iteration directory exists
    ITER_DIRS=$(find ${PLAN_DIR} -maxdepth 1 -type d -name "iteration-*" | sort -V)

    # Count existing iterations
    EXISTING_COUNT=$(echo "$ITER_DIRS" | grep -v "^$" | wc -l)

    if [ $i -gt $EXISTING_COUNT ]; then
        NEXT_ITERATION_ID=$i
        # Get global number from master plan
        # NEXT_GLOBAL_NUM=$(parse_yaml_iteration_global_num $i)
        break
    fi

    # Check if iteration $i is complete
    GLOBAL_NUM=$(ls -d ${PLAN_DIR}/iteration-* 2>/dev/null | sort -V | sed -n "${i}p" | sed 's/.*iteration-//')

    if [ -n "$GLOBAL_NUM" ]; then
        VALIDATION_REPORT="${PLAN_DIR}/iteration-${GLOBAL_NUM}/validation/validation-report.md"

        if [ ! -f "$VALIDATION_REPORT" ]; then
            echo "⚠️  Iteration ${i} (global #${GLOBAL_NUM}) is in progress"
            echo ""
            echo "Complete current iteration first:"
            echo "  /2l-continue"
            exit 1
        fi

        VALIDATION_STATUS=$(grep "^## Status" $VALIDATION_REPORT | head -1 | awk '{print $3}')

        if [ "$VALIDATION_STATUS" != "PASS" ]; then
            echo "⚠️  Iteration ${i} (global #${GLOBAL_NUM}) validation failed"
            echo ""
            echo "Heal current iteration first:"
            echo "  /2l-continue"
            exit 1
        fi
    fi
done

if [ -z "$NEXT_ITERATION_ID" ]; then
    echo "✅ All iterations complete!"
    echo ""
    echo "Plan ${CURRENT_PLAN} is finished."
    echo ""
    echo "Start new plan:"
    echo "  /2l-vision"
    exit 0
fi

# Step 6: Get iteration details from master plan
echo "🚀 Starting next iteration..."
echo ""
echo "   Iteration ${NEXT_ITERATION_ID}/${TOTAL_ITERATIONS}"
# echo "   Global #${NEXT_GLOBAL_NUM}"
echo ""

# Read iteration details from master-plan.yaml
# ITERATION_NAME=$(parse yaml)
# ITERATION_VISION=$(parse yaml)

# echo "   Name: ${ITERATION_NAME}"
# echo "   Vision: ${ITERATION_VISION}"
echo ""
```

**Then spawn orchestrator:**

```
Use Task tool with subagent_type: "2l-orchestrator"

Prompt:
"You are the 2L Orchestrator in ITERATION MODE.

Plan: ${CURRENT_PLAN}
Master Plan: ${MASTER_PLAN}

The user manually triggered the next iteration.

Execute iteration ${NEXT_ITERATION_ID} (global iteration ${NEXT_GLOBAL_NUM}):
- Read iteration config from master-plan.yaml
- Run complete iteration workflow (explore → plan → build → integrate → validate)
- Auto-commit on validation PASS
- Report progress

This is a single iteration execution. Do not continue to subsequent iterations.

Follow the 2l-orchestrator agent definition for ITERATION MODE execution."
```

---

## Examples

### Success Case
```
$ /2l-next

📊 Master Plan: plan-2
   Total iterations: 3

🚀 Starting next iteration...

   Iteration 2/3
   Name: Core UI
   Vision: User can view accounts and manage transactions

   Spawning orchestrator...
```

### Current Iteration Incomplete
```
$ /2l-next

📊 Master Plan: plan-2
   Total iterations: 3

⚠️  Iteration 1 (global #2) is in progress

Complete current iteration first:
  /2l-continue
```

### All Complete
```
$ /2l-next

📊 Master Plan: plan-1
   Total iterations: 1

✅ All iterations complete!

Plan plan-1 is finished.

Start new plan:
  /2l-vision
```

### No Master Plan
```
$ /2l-next

❌ No master plan found for plan-2

This command requires a master plan.

Options:
  1. Create master plan interactively:
     /2l-plan

  2. Use /2l-mvp to auto-create and execute
```

---

## Difference from /2l-mvp

| Aspect | `/2l-next` | `/2l-mvp` |
|--------|-----------|-----------|
| **Scope** | Single next iteration | All iterations in sequence |
| **Use Case** | Manual control between iterations | Continuous execution |
| **Prerequisites** | Master plan must exist | Can create master plan |
| **Execution** | Stops after one iteration | Continues through all |
| **Resumption** | User calls /2l-next again | Automatic progression |

---

## Integration with Other Commands

### Typical Workflow

```bash
# Create vision and plan
/2l-vision
/2l-plan

# Execute first iteration manually
/2l-next
# ... iteration 1 completes ...

# Review results, then continue
/2l-next
# ... iteration 2 completes ...

# Final iteration
/2l-next
# ... iteration 3 completes ...

# Plan complete
```

### vs. Automatic Workflow

```bash
# Create vision and plan
/2l-vision
/2l-plan

# Execute all iterations automatically
/2l-mvp
# ... all iterations complete without manual steps ...
```

---

## Error Handling

**If validation failed:**
```
The orchestrator will run the iteration through validation.
If validation fails, healing will automatically begin.
User can check status with /2l-status.
```

**If context compaction needed:**
```
Iteration will checkpoint and /2l-continue will resume.
/2l-next doesn't need to be called again - /2l-continue handles it.
```

---

## Notes

- Manual control useful for reviewing code between iterations
- Allows fixing issues before proceeding
- Good for learning or debugging the 2L workflow
- Can modify master-plan.yaml between iterations if needed

---

Now advancing to next iteration...
