# 2L Continue - Resume Workflow from Last State

Resume 2L autonomous development from where the previous session stopped. The session directly acts as the continuation orchestrator, detecting state and continuing orchestration.

## Usage

```
/2l-continue
```

No arguments needed - automatically detects state from `.2L/` directory and continues.

---

## I AM the Continuation Orchestrator

When this command executes, **I am the orchestrator**. I don't spawn another orchestrator - I directly:

1. Detect the current state
2. Determine the resume point
3. Continue orchestration from that point
4. Spawn sub-agents as needed (explorers, planners, builders, integrators, validators, healers)

---

## Step 1: Analyze Current State

```bash
# Read global config for multi-plan awareness
CONFIG_FILE=".2L/config.yaml"

if [ -f "$CONFIG_FILE" ]; then
    CURRENT_PLAN=$(yq eval '.current_plan' $CONFIG_FILE)
    CURRENT_ITER=$(yq eval '.global_iteration_counter' $CONFIG_FILE)
    CURRENT_PHASE=$(yq eval '.current_phase' $CONFIG_FILE)
    echo "📋 Multi-Plan State:"
    echo "   Current Plan: ${CURRENT_PLAN}"
    echo "   Global Iteration: ${CURRENT_ITER}"
    echo "   Phase: ${CURRENT_PHASE}"
fi

# Find latest plan and iteration
LATEST_PLAN=$(ls -d .2L/plan-* 2>/dev/null | sort -V | tail -1)
LATEST_ITER=$(ls -d .2L/plan-*/iteration-* 2>/dev/null | sort -V | tail -1)
LATEST_TASK=$(ls -d .2L/tasks/task-* 2>/dev/null | sort -V | tail -1)
```

**Determine continuation type:**

1. **Active multi-plan workflow?** → Resume master/iteration execution
2. **Active iteration?** → Resume full protocol
3. **Active task?** → Resume quick task
4. **Both?** → Resume most recent by timestamp

---

## Step 2: State Detection Logic

I examine `.2L/` structure to determine:

- Which plan we're in (plan-N)
- Which iteration we're in (global iteration number)
- Last completed phase
- Current status (PASS/FAIL/IN_PROGRESS)
- Master plan vs standalone iteration
- Healing attempts (if any)

**Phase outputs to check:**

**Master-level:**
1. **Master Exploration:** `.2L/plan-N/master-exploration/master-explorer-*-report.md`
2. **Master Planning:** `.2L/plan-N/master-plan.yaml`

**Iteration-level:**
1. **Exploration:** `.2L/plan-N/iteration-M/exploration/explorer-*-report.md`
2. **Planning:** `.2L/plan-N/iteration-M/plan/{overview,tech-stack,patterns,builder-tasks}.md`
3. **Building:** `.2L/plan-N/iteration-M/building/builder-*-report.md`
4. **Integration:** `.2L/plan-N/iteration-M/integration/round-{R}/`
   - `integration-plan.md` (from iplanner)
   - `integrator-*-report.md` (from integrators)
   - `ivalidation-report.md` (from ivalidator)
5. **Validation:** `.2L/plan-N/iteration-M/validation/validation-report.md`
6. **Healing:** `.2L/plan-N/iteration-M/healing-*/`

---

## Step 3: Resume Orchestration

Based on detected state, I continue from the appropriate phase:

---

### If Master Exploration Incomplete

**State:** Plan exists, but expected number of master explorer reports not complete

**Resume Point:** Complete master exploration

```bash
PLAN_DIR=".2L/${CURRENT_PLAN}"
EXPLORATION_DIR="${PLAN_DIR}/master-exploration"

# Read expected number of explorers from config (default to 2 for backward compatibility)
EXPECTED=$(yq eval ".plans[] | select(.plan_id == \"${CURRENT_PLAN}\") | .master_exploration.num_explorers // 2" .2L/config.yaml)

# Count actual explorer reports
ACTUAL=$(ls ${EXPLORATION_DIR}/master-explorer-*-report.md 2>/dev/null | wc -l)
```

**Action:**
- If ACTUAL < EXPECTED: Spawn remaining master-explorer agents
- Wait for completion
- Continue to master planning

**Spawn explorers:**
```python
# Determine which explorers are missing
if ACTUAL < EXPECTED:
    echo "Master exploration incomplete: $ACTUAL/$EXPECTED explorers complete"

    # Spawn missing explorers (from ACTUAL+1 to EXPECTED)
    for explorer_id in $(seq $((ACTUAL + 1)) $EXPECTED); do
        REPORT_FILE="${EXPLORATION_DIR}/master-explorer-${explorer_id}-report.md"

        # Determine focus area based on explorer ID
        case $explorer_id in
            1)
                FOCUS_AREA="Architecture & Complexity Analysis"
                ;;
            2)
                FOCUS_AREA="Dependencies & Risk Assessment"
                ;;
            3)
                FOCUS_AREA="User Experience & Integration Points"
                ;;
            4)
                FOCUS_AREA="Scalability & Performance Considerations"
                ;;
        esac

        echo "  Resuming Explorer $explorer_id: $FOCUS_AREA"

        spawn_agent(
            type="2l-master-explorer",
            focus=FOCUS_AREA,
            explorer_id=explorer_id
        )
    done

    # Wait for completion
    echo "Waiting for explorers to complete..."
else:
    echo "Master exploration complete: $ACTUAL/$EXPECTED explorers"
```

---

### If Master Planning Incomplete

**State:** Master exploration complete, no master-plan.yaml

**Resume Point:** Create master plan

```bash
MASTER_PLAN="${PLAN_DIR}/master-plan.yaml"
```

**Action:**

**Option A: User-controlled planning (default)**
- Report to user: "Master exploration complete. Run `/2l-plan` to create master plan"
- Wait for user to run `/2l-plan`

**Option B: Auto-planning mode (if MASTER MODE flag set)**
- Directly create master-plan.yaml from exploration findings
- Synthesize explorer reports
- Determine single vs multi-iteration
- Generate master-plan.yaml structure

**Then:** Continue to iteration execution

---

### If Iteration Execution in Progress

**State:** Master plan exists, iterations to execute

**Resume Point:** Continue multi-iteration execution loop

**Action:**
```python
# Read master plan
master_plan = read_yaml(f"{PLAN_DIR}/master-plan.yaml")
iterations = master_plan['iterations']

# Find current iteration
for iteration in iterations:
    iteration_status = get_iteration_status(iteration)

    if iteration_status == 'IN_PROGRESS':
        # Resume this iteration
        resume_iteration(iteration)
        break

    elif iteration_status == 'PENDING':
        # Start this iteration
        start_iteration(iteration)
        break

# After iteration completes, continue to next
# Or mark plan as COMPLETE if all done
```

**Iteration execution logic:** See iteration-specific resume points below

---

### If Quick Task Mode Detected

**State:** Task directory exists in `.2L/tasks/task-*`

**Resume Point:** Continue quick task

```bash
TASK_DIR=$(ls -d .2L/tasks/task-* 2>/dev/null | sort -V | tail -1)
```

**Determine task status:**
- Has `summary.md`? → Task complete, nothing to resume
- Has `{builder/healer}-report.md` but no validation? → Resume at validation
- Has validation logs but failed? → Resume at healing
- Has `healer-fix-report.md`? → Re-validate
- No agent report? → Task just started, spawn agent

**Resume actions:**

**If agent report exists, no validation:**
1. Read the agent report
2. Run quick validation (TypeScript, tests, build)
3. If PASS: Create summary, done
4. If FAIL: Spawn healer for quick fix
5. Re-validate and complete

**If validation failed, no healing yet:**
1. Read validation logs
2. Spawn healer agent for specific issues
3. Run validation again
4. Create summary

**If healing attempted:**
1. Re-validate
2. If PASS: Create summary, done
3. If FAIL: Escalate to user (task mode = 1 heal attempt only)

**Then mark task as complete and exit.**

---

### If Iteration Exploration Incomplete

**State:** Iteration directory exists, but exploration incomplete

**Resume Point:** Phase 1 (Exploration)

**Check state:**
```bash
ITER_DIR=".2L/${CURRENT_PLAN}/iteration-${CURRENT_ITER}"
EXPLORATION_DIR="${ITER_DIR}/exploration"

# Count completed explorers
EXPLORER_COUNT=$(ls ${EXPLORATION_DIR}/explorer-*-report.md 2>/dev/null | wc -l)
```

**Action:** Spawn remaining explorer agents (typically 2-3 total)

```python
# Determine which explorers are missing
expected_explorers = 3  # from plan or default
completed_count = len(glob(f"{EXPLORATION_DIR}/explorer-*-report.md"))

for i in range(completed_count + 1, expected_explorers + 1):
    focus = get_explorer_focus(i)  # Architecture, Tech, Complexity
    spawn_agent(
        type="2l-explorer",
        focus=focus,
        explorer_id=i,
        iteration=CURRENT_ITER
    )
```

**Wait for completion, then continue to Planning.**

---

### If Iteration Planning Incomplete

**State:** Exploration complete, no plan files

**Resume Point:** Phase 2 (Planning)

**Check state:**
```bash
PLAN_DIR="${ITER_DIR}/plan"
# Check for overview.md, tech-stack.md, patterns.md, builder-tasks.md
```

**Action:** Spawn planner agent

```python
spawn_agent(
    type="2l-planner",
    iteration=CURRENT_ITER,
    inputs={
        "exploration_reports": f"{EXPLORATION_DIR}/*.md",
        "requirements": f"{PLAN_DIR}/vision.md"
    }
)
```

**Wait for planner to create all 4 plan files, then continue to Building.**

---

### If Building Incomplete

**State:** Plan exists, building in progress

**Resume Point:** Phase 3 (Building)

**Check state:**
```bash
BUILDING_DIR="${ITER_DIR}/building"

# Read builder-tasks.md to see expected builders
EXPECTED_BUILDERS=$(grep -c "^## Builder-" ${ITER_DIR}/plan/builder-tasks.md)

# Count completed builders
COMPLETED_BUILDERS=$(ls ${BUILDING_DIR}/builder-*-report.md 2>/dev/null | wc -l)
```

**Action:**

1. Read `builder-tasks.md` to identify all builder assignments
2. Check which builders have completed (reports exist)
3. Spawn remaining builders in parallel
4. **Handle SPLIT decisions sequentially:**
   - If builder reports SPLIT status
   - Read split report to get sub-builder definitions
   - Spawn sub-builders (builder-1A, builder-1B, etc.)
5. Wait for all builders to complete

```python
# Read builder tasks
builder_tasks = parse_builder_tasks(f"{PLAN_DIR}/builder-tasks.md")

# Check which are complete
completed_builders = get_completed_builders(BUILDING_DIR)

# Spawn remaining
for builder_id, task in builder_tasks.items():
    if builder_id not in completed_builders:
        spawn_agent(
            type="2l-builder",
            builder_id=builder_id,
            task=task,
            iteration=CURRENT_ITER
        )

# After all complete, check for SPLIT status
for report in glob(f"{BUILDING_DIR}/builder-*-report.md"):
    status = extract_status(report)
    if status == 'SPLIT':
        sub_builders = extract_sub_builder_tasks(report)
        for sub_id, sub_task in sub_builders.items():
            spawn_agent(
                type="2l-builder",
                builder_id=sub_id,
                task=sub_task,
                iteration=CURRENT_ITER
            )
```

**Wait for all building to complete, then continue to Integration.**

---

### If Integration Incomplete (Multi-Round Integration)

**State:** Building complete, integration in progress

**Resume Point:** Phase 4 (Integration Loop)

**Check integration state:**
```bash
INTEGRATION_DIR="${ITER_DIR}/integration"

# Find latest round
LATEST_ROUND=$(ls -d ${INTEGRATION_DIR}/round-* 2>/dev/null | sort -V | tail -1)
ROUND_NUM=$(basename $LATEST_ROUND | sed 's/round-//')
```

**Integration Round Loop:**

```python
MAX_ROUNDS = 3
round = get_current_round() or 1

while round <= MAX_ROUNDS:
    ROUND_DIR = f"{INTEGRATION_DIR}/round-{round}"

    # Step 1: Iplanner - create integration plan
    if not exists(f"{ROUND_DIR}/integration-plan.md"):
        spawn_agent(
            type="2l-iplanner",
            round=round,
            iteration=CURRENT_ITER,
            inputs={
                "builder_reports": f"{BUILDING_DIR}/builder-*.md",
                "patterns": f"{PLAN_DIR}/patterns.md"
            }
        )
        return  # Resume after iplanner completes

    # Step 2: Integrators (parallel) - execute zones
    integration_plan = read_integration_plan(f"{ROUND_DIR}/integration-plan.md")
    zones = extract_zones(integration_plan)

    # Check which integrators have completed
    completed_integrators = get_completed_integrators(ROUND_DIR)

    if not all_integrators_complete(zones, completed_integrators):
        # Spawn remaining integrators
        for integrator_id, assigned_zones in get_integrator_assignments(zones):
            if integrator_id not in completed_integrators:
                spawn_agent(
                    type="2l-integrator",
                    integrator_id=integrator_id,
                    zones=assigned_zones,
                    round=round,
                    iteration=CURRENT_ITER
                )
        return  # Resume after integrators complete

    # Step 3: Ivalidator - validate integration cohesion
    if not exists(f"{ROUND_DIR}/ivalidation-report.md"):
        spawn_agent(
            type="2l-ivalidator",
            round=round,
            iteration=CURRENT_ITER,
            inputs={
                "integration_plan": f"{ROUND_DIR}/integration-plan.md",
                "integrator_reports": f"{ROUND_DIR}/integrator-*.md",
                "patterns": f"{PLAN_DIR}/patterns.md"
            }
        )
        return  # Resume after ivalidator completes

    # Check ivalidation result
    result = read_ivalidation_result(f"{ROUND_DIR}/ivalidation-report.md")

    if result == 'PASS':
        # Integration successful!
        create_final_integration_report(round, INTEGRATION_DIR)
        break  # Proceed to validation

    elif result == 'FAIL' and round < MAX_ROUNDS:
        # Need another integration round
        round += 1
        print(f"⚠️  Integration round {round-1} failed. Starting round {round}...")
        continue

    elif result == 'FAIL' and round == MAX_ROUNDS:
        # Max rounds reached, proceed with partial integration
        print(f"⚠️  Integration rounds exhausted. Proceeding with partial integration...")
        create_final_integration_report(round, INTEGRATION_DIR, status='PARTIAL')
        break

# Continue to validation phase
```

**After integration loop completes, continue to Validation.**

---

### If Validation Incomplete

**State:** Integration complete, no validation report

**Resume Point:** Phase 5 (Validation)

**Check state:**
```bash
VALIDATION_DIR="${ITER_DIR}/validation"
```

**Action:** Spawn validator agent

```python
spawn_agent(
    type="2l-validator",
    iteration=CURRENT_ITER,
    inputs={
        "integration_report": f"{INTEGRATION_DIR}/final-integration-report.md",
        "plan": f"{PLAN_DIR}/overview.md",
        "requirements": f"{PLAN_DIR}/vision.md"
    }
)
```

**Wait for validation to complete.**

**Check validation result:**
- **If PASS:** ✅ Iteration complete! Auto-commit (see below)
- **If FAIL:** Continue to Healing

---

### If Validation FAILED (Healing Needed)

**State:** Validation report exists with FAIL status

**Resume Point:** Phase 6 (Healing)

**Check healing attempts:**
```bash
# Count healing iterations
HEALING_COUNT=$(ls -d ${ITER_DIR}/healing-* 2>/dev/null | wc -l)
```

**Healing logic:**

```python
MAX_HEALING_ATTEMPTS = 2

if HEALING_COUNT < MAX_HEALING_ATTEMPTS:
    # Start healing iteration
    healing_iteration = HEALING_COUNT + 1
    HEALING_DIR = f"{ITER_DIR}/healing-{healing_iteration}"

    # Read validation report to identify issue categories
    validation_report = read_validation_report(f"{VALIDATION_DIR}/validation-report.md")
    issue_categories = extract_issue_categories(validation_report)

    # Spawn healer agents (1 per category, max 3 in parallel)
    for category in issue_categories[:3]:
        spawn_agent(
            type="2l-healer",
            category=category,
            healing_iteration=healing_iteration,
            iteration=CURRENT_ITER
        )

    # Wait for healers to complete
    # Then spawn mini-integrator to merge fixes
    spawn_agent(
        type="2l-integrator",
        mode="healing_integration",
        healing_iteration=healing_iteration,
        iteration=CURRENT_ITER
    )

    # Wait for integration
    # Then re-validate
    spawn_agent(
        type="2l-validator",
        healing_iteration=healing_iteration,
        iteration=CURRENT_ITER
    )

    # Check new validation status
    new_validation = read_validation_report(f"{HEALING_DIR}/validation-report.md")

    if new_validation['status'] == 'PASS':
        # Healing successful!
        print("✅ Healing successful! Iteration complete.")
        auto_commit_iteration()
    else:
        # Healing failed
        if healing_iteration < MAX_HEALING_ATTEMPTS:
            print(f"⚠️  Healing iteration {healing_iteration} failed. Retrying...")
            # Loop will continue to next healing iteration
        else:
            print(f"❌ Healing failed after {MAX_HEALING_ATTEMPTS} iterations.")
            escalate_to_user()

elif HEALING_COUNT >= MAX_HEALING_ATTEMPTS:
    # Max healing attempts reached
    print(f"❌ Healing failed after {MAX_HEALING_ATTEMPTS} iterations.")
    print("Manual intervention required.")

    # Show remaining issues
    final_validation = read_validation_report(
        f"{ITER_DIR}/healing-{MAX_HEALING_ATTEMPTS}/validation-report.md"
    )

    print("\nRemaining issues:")
    display_issues(final_validation)

    print(f"\nPlease review: {ITER_DIR}/healing-{MAX_HEALING_ATTEMPTS}/validation-report.md")
```

---

### If Validation PASSED (Auto-Commit)

**State:** Validation report exists with PASS status

**Status:** ✅ Iteration Complete!

**Action: Auto-Commit**

```bash
# Only if validation PASSED
VALIDATION_STATUS=$(grep "^## Status" ${VALIDATION_DIR}/validation-report.md | awk '{print $3}')

if [ "$VALIDATION_STATUS" = "PASS" ]; then
    # Get iteration details
    PLAN_ID="${CURRENT_PLAN}"
    ITER_NUM="${CURRENT_ITER}"

    # Get vision from master plan
    ITERATION_VISION=$(yq eval ".iterations[] | select(.iteration_id == ${ITER_NUM}) | .vision" ${PLAN_DIR}/master-plan.yaml)

    # Get local iteration number within this plan
    LOCAL_ITER_ID=$(yq eval ".iterations[] | select(.iteration_id == ${ITER_NUM}) | .local_id" ${PLAN_DIR}/master-plan.yaml)
    TOTAL_ITERS=$(yq eval '.total_iterations' ${PLAN_DIR}/master-plan.yaml)

    # Stage all changes
    git add .

    # Create commit with metadata
    git commit -m "2L Iteration ${ITER_NUM} (Plan ${PLAN_ID})

Vision: ${ITERATION_VISION}
Status: PASS
Plan: ${PLAN_ID} (iteration ${LOCAL_ITER_ID}/${TOTAL_ITERS})

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"

    # Create tag
    TAG="2l-${PLAN_ID}-iter-${ITER_NUM}"
    git tag "${TAG}"

    COMMIT_HASH=$(git rev-parse HEAD)

    # Update config with commit info
    yq eval ".iterations[] |= (select(.iteration_id == ${ITER_NUM}) | .commit_hash = \"${COMMIT_HASH}\" | .git_tag = \"${TAG}\" | .completed_at = \"$(date -Iseconds)\")" -i ${PLAN_DIR}/master-plan.yaml

    echo "✅ Auto-committed: ${TAG}"
    echo "   Commit: ${COMMIT_HASH}"
fi
```

**Then:**
- If part of multi-iteration plan: Continue to next iteration
- If standalone iteration or last iteration: Report MVP complete
- Ready for user review

---

## Orchestration Flow Summary

```
Detect State
    ↓
┌─── Master exploration incomplete? ───→ Spawn remaining master-explorers → Continue
│
├─── Master planning incomplete? ─────→ Create master-plan.yaml (or wait for /2l-plan) → Continue
│
├─── Iteration exploration incomplete? → Spawn remaining explorers → Continue
│
├─── Iteration planning incomplete? ──→ Spawn planner → Continue
│
├─── Building incomplete? ────────────→ Spawn remaining builders → Handle splits → Continue
│
├─── Integration incomplete? ─────────→ Execute integration loop:
│                                         Round 1-3: iplanner → integrators → ivalidator
│                                         If PASS: Continue
│                                         If FAIL: Next round or continue
│
├─── Validation incomplete? ──────────→ Spawn validator → Check PASS/FAIL
│                                              ↓
│                                        ┌─── PASS → Auto-commit → Next iteration or COMPLETE ✅
│                                        │
│                                        └─── FAIL → Healing
│                                                      ↓
└─── Healing needed? ─────────────────────────→ Check attempts
                                                    ↓
                                              ┌─── < 2 → Spawn healers → Integrate → Re-validate
                                              │          ↓
                                              │    ┌─── PASS → Auto-commit → COMPLETE ✅
                                              │    └─── FAIL → Repeat or escalate
                                              │
                                              └─── = 2 & FAIL → Escalate to user ❌
```

---

## Progress Reporting

Throughout execution, I provide clear status updates:

- "📍 Detected state: Building phase (3/4 builders complete)"
- "▶️ Resuming Builder-4..."
- "✅ Building complete. Starting integration round 1..."
- "🔍 Integration round 1: Spawning iplanner..."
- "🔗 Spawning 2 integrators for parallel zone execution..."
- "✓ Ivalidator: Integration cohesion PASS"
- "✅ Integration complete. Starting validation..."
- "⚠️ Validation FAILED. Entering healing iteration 1..."
- "✅ Healing successful! Iteration complete."
- "📝 Auto-committed: 2l-plan-2-iter-3"
- "🚀 Starting next iteration (4/5)..."

---

## Context Management (Infinite Resumability)

**If I need to compact during this session:**

Before compacting, I will:
1. Ensure all current phase outputs are written to `.2L/`
2. Update state markers (all reports saved)
3. Instruct the next session to continue:

> /2l-continue is running…

This creates infinite resumability - the workflow can span any number of sessions and always resume from the exact checkpoint.

---

## Error Handling

**If state is ambiguous:**
- Report what was found
- Ask user for clarification
- Suggest recovery steps

**If directory structure is corrupted:**
- Report the issue
- Show what exists
- Ask if should start fresh iteration

**If agents fail:**
- Document the failure
- Attempt retry once
- If still fails: escalate to user

---

## Agent Spawning Reference

I spawn these agents as needed during orchestration:

- **2l-master-explorer** - Strategic exploration for master planning
- **2l-explorer** - Iteration-level exploration
- **2l-planner** - Creates iteration plan from exploration
- **2l-builder** - Implements features (can SPLIT into sub-builders)
- **2l-iplanner** - Creates integration plan with zones
- **2l-integrator** - Executes integration zones
- **2l-ivalidator** - Validates integration cohesion
- **2l-validator** - Final validation before completion
- **2l-healer** - Fixes specific issue categories

All agents write reports to `.2L/` structure, enabling resumability.

---

Now analyzing `.2L/` directory and detecting resume point...
