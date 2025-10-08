# 2L MVP - Full Autonomous Development Orchestrator

Execute complete 2L protocol with three access levels: full autonomy, vision control, or full control.

**CRITICAL:** This command IS the orchestrator. It directly executes all orchestration logic - no agent spawning for orchestration.

## Usage

### Level 1: Full Autonomy (Inline Requirements)
```bash
/2l-mvp "Build a todo app with user auth and categories"
```

Auto-generates vision → auto-creates master plan → executes all iterations

### Level 2: Vision Control
```bash
# After /2l-vision creates vision.md
/2l-mvp
```

Uses existing vision → auto-creates master plan → executes all iterations

### Level 3: Full Control
```bash
# After /2l-vision and /2l-plan create vision.md and master-plan.yaml
/2l-mvp
```

Uses existing vision and master plan → executes all iterations

---

## Event Logging & Dashboard Initialization

The orchestrator emits events throughout execution to enable real-time observability via the dashboard. All event emission is **optional** and fails gracefully if the event logger library is not available.

### Event Logger Initialization

At orchestrator startup, initialize the event logging system:

```bash
# Source event logger library if available (backward compatible)
EVENT_LOGGING_ENABLED=false
if [ -f "$HOME/.claude/lib/2l-event-logger.sh" ]; then
  . "$HOME/.claude/lib/2l-event-logger.sh"
  EVENT_LOGGING_ENABLED=true
  echo "[2L] Event logging enabled"
else
  echo "[2L] Event logging not available (continuing without dashboard)"
fi
```

**Key principles:**
- Set `EVENT_LOGGING_ENABLED=false` initially for backward compatibility
- Only enable if library exists and sources successfully
- All event emissions must check `EVENT_LOGGING_ENABLED` before calling `log_2l_event`
- System continues normally even if event logging is unavailable

### Event Types Emitted by Orchestrator

The orchestrator emits the following event types throughout execution:

| Event Type | When Emitted | Phase | Purpose |
|------------|--------------|-------|---------|
| `plan_start` | Orchestrator initialization (all 3 levels) | initialization | Signal orchestration beginning |
| `complexity_decision` | After analyzing vision complexity | master_exploration | Document explorer count decision |
| `phase_change` | Every phase transition | current phase | Track orchestration progress |
| `agent_spawn` | When spawning any agent | agent's phase | Track agent creation |
| `agent_complete` | When agent finishes | agent's phase | Track agent completion |
| `iteration_start` | Beginning of each iteration | initialization | Mark iteration boundary |
| `validation_result` | After validation completes | validation | Document PASS/FAIL status |
| `iteration_complete` | After successful iteration | complete | Mark iteration success |

All events are written to `.2L/events.jsonl` in JSON Lines format with this schema:

```json
{
  "timestamp": "2025-10-08T14:23:45.123Z",
  "event_type": "phase_change",
  "phase": "building",
  "agent_id": "orchestrator",
  "data": "Starting Building phase"
}
```

### Event Emission Guidelines

**When to emit events:**

1. **Initialization (4 events):**
   - `plan_start` - Level 1, 2, 3, or Resume entry points

2. **Master Mode (4+ events):**
   - `complexity_decision` - After analyzing vision complexity
   - `phase_change` - Master exploration start
   - `agent_spawn` - For each master explorer (2-4)
   - `agent_complete` - For each master explorer
   - `phase_change` - Master planning start

3. **Per Iteration (12+ events):**
   - `iteration_start` - Beginning of iteration
   - `phase_change` - Exploration start
   - `agent_spawn` × 2-3 - For explorers
   - `agent_complete` × 2-3 - For explorers
   - `phase_change` - Planning start
   - `agent_spawn` - For planner
   - `agent_complete` - For planner
   - `phase_change` - Building start
   - `agent_spawn` × N - For builders (typically 2-4)
   - `agent_complete` × N - For builders
   - `phase_change` - Integration start
   - `agent_spawn` × M - For integrators (per round)
   - `agent_complete` × M - For integrators
   - `phase_change` - Validation start
   - `agent_spawn` - For validator
   - `agent_complete` - For validator
   - `validation_result` - Validation outcome
   - `iteration_complete` - If validation passes

4. **Healing (if validation fails, 6+ events):**
   - `phase_change` - Healing start
   - `agent_spawn` × K - For healing explorers
   - `agent_complete` × K - For healing explorers
   - `agent_spawn` × L - For healers (by category)
   - `agent_complete` × L - For healers
   - `validation_result` - Re-validation outcome
   - `iteration_complete` - If healing successful

**Example: Simple Single-Iteration Plan**

Total events: ~35-40 events

- 1 `plan_start`
- 1 `complexity_decision` (2 explorers)
- 6 master exploration events (phase_change + 2 spawn + 2 complete)
- 1 master planning `phase_change`
- 1 `iteration_start`
- 8 exploration events (phase_change + 2 spawn + 2 complete)
- 3 planning events (phase_change + spawn + complete)
- 7 building events (phase_change + 3 spawn + 3 complete)
- 5 integration events (phase_change + 2 spawn + 2 complete)
- 4 validation events (phase_change + spawn + complete + result)
- 1 `iteration_complete`

**Backward Compatibility:**

All event emission is wrapped in conditional checks:

```bash
if [ "$EVENT_LOGGING_ENABLED" = true ]; then
  log_2l_event "event_type" "description" "phase" "agent_id"
fi
```

This ensures:
- Orchestrator works even if event logger library is missing
- No crashes or failures due to event emission
- Graceful degradation to non-observable mode
- Dashboard features are optional, not required

**Agent Event Emission:**

Each agent (explorer, planner, builder, integrator, validator, healer) is responsible for emitting its own `agent_start` and `agent_complete` events. The orchestrator documentation shows the expected event pattern, but agents emit these events themselves via their markdown template instructions.

See agent markdown files in `~/.claude/agents/` for agent-specific event emission code.

---

## Three-Level Access Logic

The command adapts based on what exists in `.2L/`:

### Level 1: Full Autonomy
**Condition:** Invoked with inline requirements string

**Flow:**
1. Create new plan-{N} directory
2. Auto-generate vision.md from inline requirements
3. Spawn master explorers (Task tool)
4. Auto-create master-plan.yaml
5. Execute all iterations

**User control:** Minimal - provides high-level description only

### Level 2: Vision Control
**Condition:** Current plan has vision.md but no master-plan.yaml (status: VISIONED)

**Flow:**
1. Use existing vision.md
2. Spawn master explorers (if not done)
3. Auto-create master-plan.yaml based on exploration
4. Execute all iterations

**User control:** Medium - user created vision.md via `/2l-vision`

### Level 3: Full Control
**Condition:** Current plan has both vision.md and master-plan.yaml (status: PLANNED)

**Flow:**
1. Use existing vision.md and master-plan.yaml
2. Execute iterations according to master plan
3. Follow user-defined iteration breakdown

**User control:** Maximum - user created vision and plan via `/2l-vision` + `/2l-plan`

---

## Mode Detection & Initialization

```python
# Read global config
CONFIG_FILE = ".2L/config.yaml"

if arguments_provided:
    # LEVEL 1: Full Autonomy
    LEVEL = 1
    inline_requirements = arguments

    # Create new plan
    next_plan_id = determine_next_plan_id()
    create_plan_directory(next_plan_id)
    auto_generate_vision(inline_requirements)

    # Enter MASTER MODE
    MODE = 'MASTER'
    plan_id = next_plan_id

    # EVENT: plan_start (Level 1)
    # Emit plan_start event to signal beginning of autonomous orchestration
    if [ "$EVENT_LOGGING_ENABLED" = true ]; then
      log_2l_event "plan_start" "Plan $plan_id started in MASTER mode (Level 1: Full Autonomy)" "initialization" "orchestrator"
    fi

    # Event details:
    # - event_type: "plan_start" - Marks orchestration beginning
    # - data: Descriptive message including plan ID and level
    # - phase: "initialization" - Pre-iteration orchestration setup
    # - agent_id: "orchestrator" - Always "orchestrator" for orchestrator events

else:
    # Check for existing plan
    if not file_exists(CONFIG_FILE):
        error("No active plan found. Use: /2l-mvp \"requirements\" or /2l-vision first")
        exit(1)

    config = read_yaml(CONFIG_FILE)
    current_plan = config['current_plan']

    if not current_plan:
        error("No active plan. Use: /2l-mvp \"requirements\" or /2l-vision first")
        exit(1)

    plan_status = get_plan_status(current_plan, config)
    plan_dir = f".2L/{current_plan}"

    has_vision = file_exists(f"{plan_dir}/vision.md")
    has_master_plan = file_exists(f"{plan_dir}/master-plan.yaml")

    if not has_vision:
        error(f"Plan {current_plan} has no vision.md. Run /2l-vision first.")
        exit(1)

    if plan_status == 'VISIONED' and not has_master_plan:
        # LEVEL 2: Vision Control
        LEVEL = 2
        print(f"📋 Using existing vision from {current_plan}")
        print("🎯 Auto-planning iteration breakdown...")

        # Enter MASTER MODE (will auto-plan)
        MODE = 'MASTER'
        plan_id = current_plan

        # EVENT: plan_start (Level 2)
        # Emit plan_start event for vision-controlled orchestration
        if [ "$EVENT_LOGGING_ENABLED" = true ]; then
          log_2l_event "plan_start" "Plan $plan_id started in MASTER mode (Level 2: Vision Control)" "initialization" "orchestrator"
        fi

        # Event details:
        # - Level 2: User provided vision.md, orchestrator auto-creates master plan
        # - phase: "initialization" - Before master exploration begins

    elif plan_status == 'PLANNED' and has_master_plan:
        # LEVEL 3: Full Control
        LEVEL = 3
        print(f"📋 Using existing vision and master plan from {current_plan}")
        print("🚀 Executing planned iterations...")

        # Enter ITERATION_EXECUTOR MODE
        MODE = 'ITERATION_EXECUTOR'
        plan_id = current_plan

        # EVENT: plan_start (Level 3)
        # Emit plan_start event for fully-controlled orchestration
        if [ "$EVENT_LOGGING_ENABLED" = true ]; then
          log_2l_event "plan_start" "Plan $plan_id started in ITERATION_EXECUTOR mode (Level 3: Full Control)" "initialization" "orchestrator"
        fi

        # Event details:
        # - Level 3: User provided both vision.md and master-plan.yaml
        # - Orchestrator executes pre-defined iteration plan
        # - phase: "initialization" - Before iteration execution begins

    elif plan_status == 'IN_PROGRESS':
        # Resume in-progress plan
        print(f"▶️  Resuming in-progress plan: {current_plan}")

        MODE = 'ITERATION_EXECUTOR'
        plan_id = current_plan

        # EVENT: plan_start (Resume)
        # Emit plan_start event when resuming interrupted orchestration
        if [ "$EVENT_LOGGING_ENABLED" = true ]; then
          log_2l_event "plan_start" "Plan $plan_id resumed (IN_PROGRESS)" "initialization" "orchestrator"
        fi

        # Event details:
        # - Resuming a plan that was previously interrupted
        # - Orchestrator will detect where to continue from config.yaml state
        # - phase: "initialization" - Re-entry point

    elif plan_status == 'COMPLETE':
        error(f"Plan {current_plan} is already complete. Create new plan with /2l-vision")
        exit(0)

    else:
        error(f"Plan {current_plan} is in unexpected state: {plan_status}")
        exit(1)
```

---

## Dashboard Initialization

```bash
# Initialize dashboard if not exists (after mode detection, before orchestration)
echo ""
echo "=== Dashboard Initialization ==="
if [ "$EVENT_LOGGING_ENABLED" = true ]; then
  if [ ! -f ".2L/dashboard/index.html" ]; then
    echo "[2L] Dashboard not found, creating..."

    # Create dashboard directory
    mkdir -p .2L/dashboard

    # Get project name
    PROJECT_NAME=$(basename "$(pwd)")

    # Note: Dashboard builder agent will be spawned once Builder-2 completes
    # For now, we'll attempt spawning and handle gracefully if agent doesn't exist yet
    if [ -f "$HOME/.claude/agents/2l-dashboard-builder.md" ]; then
      # Spawn dashboard builder agent using Task tool
      echo "[2L] Spawning dashboard builder agent..."
      # (Task tool spawning logic would go here in actual implementation)
      # For documentation: This section will spawn the dashboard builder
      echo "[2L] Dashboard builder spawned"
    else
      echo "[2L] ⚠ Dashboard builder agent not available yet (will be created on next run)"
    fi

    if [ -f ".2L/dashboard/index.html" ]; then
      DASHBOARD_PATH="$(pwd)/.2L/dashboard/index.html"
      echo "[2L] ✓ Dashboard created successfully"
      echo "[2L] Open dashboard: file://$DASHBOARD_PATH"
      echo ""
    else
      echo "[2L] ⚠ Dashboard creation pending (continuing without dashboard)"
    fi
  else
    DASHBOARD_PATH="$(pwd)/.2L/dashboard/index.html"
    echo "[2L] ✓ Dashboard already exists"
    echo "[2L] Open dashboard: file://$DASHBOARD_PATH"
    echo ""
  fi
else
  echo "[2L] Dashboard initialization skipped (event logging disabled)"
fi
```

---

## MASTER MODE Orchestration

When MODE = 'MASTER', we orchestrate master-level planning before iterations:

```bash
PLAN_DIR=".2L/${plan_id}"
MASTER_EXPLORATION="${PLAN_DIR}/master-exploration"
MASTER_PLAN="${PLAN_DIR}/master-plan.yaml"

# Step 0: GitHub Repository Setup
echo ""
echo "=== GitHub Integration ==="

# Initialize git if not already
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "🔧 Initializing git repository..."
    git init
    git branch -M main
fi

# Setup GitHub repo
setup_github_repo(plan_id, PLAN_DIR)

# Step 1: Master Exploration with Adaptive Spawning
VISION_FILE="${PLAN_DIR}/vision.md"

# Check if vision exists
if [ ! -f "$VISION_FILE" ]; then
    echo "❌ ERROR: Vision file not found: $VISION_FILE"
    exit 1
fi

# Analyze vision complexity to determine number of explorers
echo "🔍 Analyzing vision complexity..."

# Count features (## headers in vision.md)
feature_count=$(grep -c "^## " "$VISION_FILE" || echo 0)

# Count integrations (keywords indicating external integrations)
integration_count=$(grep -cE "API|integration|external|webhook|OAuth|third-party" "$VISION_FILE" || echo 0)

# Decision logic for num_explorers
if [ "$feature_count" -lt 5 ]; then
    num_explorers=2
    complexity="SIMPLE"
elif [ "$feature_count" -ge 15 ] || [ "$integration_count" -ge 3 ]; then
    num_explorers=4
    complexity="COMPLEX"
else
    num_explorers=3
    complexity="MEDIUM"
fi

echo "   Vision complexity: $complexity"
echo "   - Features detected: $feature_count"
echo "   - Integrations detected: $integration_count"
echo "   - Spawning $num_explorers master explorers"

# Store decision in config.yaml for resume detection
yq eval ".plans[] | select(.plan_id == \"${plan_id}\") | .master_exploration.num_explorers = $num_explorers" -i .2L/config.yaml
yq eval ".plans[] | select(.plan_id == \"${plan_id}\") | .master_exploration.complexity_level = \"$complexity\"" -i .2L/config.yaml

# EVENT: complexity_decision
# Document the adaptive spawning decision based on vision analysis
if [ "$EVENT_LOGGING_ENABLED" = true ]; then
  log_2l_event "complexity_decision" "Spawning $num_explorers explorers (complexity: $complexity)" "master_exploration" "orchestrator"
fi

# Event details:
# - event_type: "complexity_decision" - Records adaptive spawning logic
# - data: Includes explorer count and complexity assessment (SIMPLE, MEDIUM, COMPLEX)
# - phase: "master_exploration" - During master exploration setup
# - Purpose: Dashboard shows how orchestrator adapted to vision complexity

# Check if master exploration needs to run
if [ ! -d "$MASTER_EXPLORATION" ] || [ $(ls ${MASTER_EXPLORATION}/master-explorer-*-report.md 2>/dev/null | wc -l) -lt $num_explorers ]; then
    echo "🔍 Running master exploration..."

    # EVENT: phase_change (Master Exploration Start)
    # Signal transition into master exploration phase
    if [ "$EVENT_LOGGING_ENABLED" = true ]; then
      log_2l_event "phase_change" "Starting Master Exploration phase" "master_exploration" "orchestrator"
    fi

    # Event details:
    # - event_type: "phase_change" - Marks phase transition
    # - phase: "master_exploration" - The current phase
    # - Purpose: Dashboard timeline shows when master exploration begins

    mkdir -p ${MASTER_EXPLORATION}

    # Spawn explorers in parallel (1 to num_explorers)
    for explorer_id in $(seq 1 $num_explorers); do
        REPORT_FILE="${MASTER_EXPLORATION}/master-explorer-${explorer_id}-report.md"

        # Skip if report already exists
        if [ -f "$REPORT_FILE" ]; then
            echo "   Explorer $explorer_id already complete (report exists)"
            continue
        fi

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

        echo "   Spawning Explorer $explorer_id: $FOCUS_AREA"

        # EVENT: agent_spawn (Master Explorer)
        # Track creation of each master explorer agent
        if [ "$EVENT_LOGGING_ENABLED" = true ]; then
          log_2l_event "agent_spawn" "Master Explorer-$explorer_id: $FOCUS_AREA" "master_exploration" "master-explorer-$explorer_id"
        fi

        # Event details:
        # - event_type: "agent_spawn" - Agent creation notification
        # - data: Includes explorer ID and focus area
        # - agent_id: "master-explorer-{N}" - Unique identifier for this explorer
        # - Purpose: Dashboard shows which explorers are active

        # Spawn explorer using task tool
        spawn_task(
            type="2l-master-explorer",
            prompt=f"You are Master Explorer $explorer_id.

Focus Area: $FOCUS_AREA

Plan: {plan_id}
Vision: {PLAN_DIR}/vision.md
Output: {MASTER_EXPLORATION}/master-explorer-${explorer_id}-report.md

Analyze the vision document and create a comprehensive exploration report focused on your assigned area.

Follow the report structure and focus area guidelines in your agent definition.

Create your report at: {MASTER_EXPLORATION}/master-explorer-${explorer_id}-report.md"
        )
    done

    # Wait for all explorers to complete
    echo "   Waiting for $num_explorers master explorers..."
    # (Task tool handles this)

    # EVENT: agent_complete (Master Explorers)
    # Track completion of each master explorer
    # NOTE: In actual implementation, each explorer emits its own agent_complete event
    # This is documentation showing the expected event pattern
    if [ "$EVENT_LOGGING_ENABLED" = true ]; then
      for explorer_id in $(seq 1 $num_explorers); do
        log_2l_event "agent_complete" "Master Explorer-$explorer_id completed" "master_exploration" "master-explorer-$explorer_id"
      done
    fi

    # Event details:
    # - event_type: "agent_complete" - Agent completion notification
    # - Emitted once per explorer when their report is written
    # - agent_id: Matches the agent_id from agent_spawn
    # - Purpose: Dashboard can calculate agent duration (spawn → complete)
fi

# Step 2: Auto-Create Master Plan
if [ ! -f "$MASTER_PLAN" ]; then
    echo "📊 Creating master plan from exploration..."

    # EVENT: phase_change (Master Planning Start)
    # Signal transition from master exploration to master planning
    if [ "$EVENT_LOGGING_ENABLED" = true ]; then
      log_2l_event "phase_change" "Starting Master Planning phase" "master_planning" "orchestrator"
    fi

    # Event details:
    # - phase: "master_planning" - Synthesizing exploration into master plan
    # - Follows completion of all master explorers
    # - Purpose: Dashboard shows orchestrator is creating iteration breakdown

    # Read all explorer reports dynamically (2-4 reports)
    EXPLORER_REPORTS=""
    REPORT_COUNT=0

    for report in ${MASTER_EXPLORATION}/master-explorer-*-report.md; do
        if [ -f "$report" ]; then
            REPORT_COUNT=$((REPORT_COUNT + 1))
            REPORT_NAME=$(basename "$report")
            EXPLORER_ID=$(echo "$REPORT_NAME" | sed 's/master-explorer-\([0-9]\)-report.md/\1/')

            EXPLORER_REPORTS="$EXPLORER_REPORTS

========================================
EXPLORER $EXPLORER_ID REPORT: $REPORT_NAME
========================================

$(cat "$report")
"
        fi
    done

    echo "   Found $REPORT_COUNT explorer reports to synthesize"

    # Synthesize into master plan
    # Extract complexity assessment
    complexity=$(extract_complexity_from_reports)

    # Determine iteration count
    if complexity in ['SIMPLE', 'MEDIUM']:
        total_iterations=1
    elif complexity == 'COMPLEX':
        total_iterations=$(extract_recommended_iteration_count) # Usually 2-3
    else:  # VERY COMPLEX
        total_iterations=$(extract_recommended_iteration_count) # Usually 3-5

    # Get global iteration counter
    global_counter=$(get_next_global_iteration)

    # Create master-plan.yaml
    cat > ${MASTER_PLAN} <<EOF
plan_id: ${plan_id}
created_at: $(date -Iseconds)
status: PLANNED
total_iterations: ${total_iterations}

strategy: |
  $(extract_strategy_from_reports)

iterations:
EOF

    # Generate iteration entries
    for i in $(seq 1 ${total_iterations}); do
        iter_global=$((global_counter + i - 1))
        iter_vision=$(extract_iteration_vision_from_reports $i)
        iter_scope=$(extract_iteration_scope_from_reports $i)

        cat >> ${MASTER_PLAN} <<EOF
  - iteration_id: ${i}
    global_iteration: ${iter_global}
    name: "Iteration ${i}"
    vision: "${iter_vision}"
    scope: |
      ${iter_scope}
    status: PENDING
    dependencies: []
EOF
    done

    echo "✅ Master plan created: ${total_iterations} iterations"

    # Update config
    update_config_plan_status(${plan_id}, 'PLANNED')
fi

# Step 3: Enter Iteration Execution Loop
echo "🚀 Executing all iterations..."
MODE='ITERATION_EXECUTOR'
```

---

## ITERATION_EXECUTOR MODE Orchestration

When MODE = 'ITERATION_EXECUTOR', we execute iterations from the master plan:

```python
# Read master plan
master_plan = read_yaml(f"{PLAN_DIR}/master-plan.yaml")
total_iterations = master_plan['total_iterations']

print(f"📊 Master plan: {total_iterations} iterations")

# Execute each iteration in sequence
for iteration_config in master_plan['iterations']:
    iter_id = iteration_config['iteration_id']
    global_iter = iteration_config['global_iteration']
    iter_status = iteration_config['status']
    iter_vision = iteration_config['vision']

    if iter_status == 'COMPLETE':
        print(f"✅ Iteration {iter_id}/{total_iterations} already complete (global #{global_iter})")
        continue

    if iter_status == 'IN_PROGRESS':
        print(f"▶️  Resuming iteration {iter_id}/{total_iterations} (global #{global_iter})")
    else:
        print(f"🚀 Starting iteration {iter_id}/{total_iterations} (global #{global_iter})")
        print(f"   Vision: {iter_vision}")

    # Execute single iteration
    execute_iteration(
        plan_id=plan_id,
        iter_id=iter_id,
        global_iter=global_iter,
        iteration_config=iteration_config
    )

    # Check if validation passed
    validation_report = f"{PLAN_DIR}/iteration-{global_iter}/validation/validation-report.md"
    validation_status = extract_validation_status(validation_report)

    if validation_status == 'PASS':
        print(f"✅ Iteration {iter_id}/{total_iterations} complete!")

        # EVENT: iteration_complete (First-Pass Validation)
        # Mark successful iteration completion after first-pass validation
        if [ "$EVENT_LOGGING_ENABLED" = true ]; then
          log_2l_event "iteration_complete" "Iteration ${global_iter} completed successfully" "complete" "orchestrator"
        fi

        # Event details:
        # - event_type: "iteration_complete" - Iteration success marker
        # - data: Iteration completed on first-pass validation (no healing needed)
        # - phase: "complete" - Terminal phase
        # - Purpose: Dashboard shows iteration completion, enables progress tracking

        # Auto-commit (Mission 3)
        auto_commit_iteration(plan_id, iter_id, global_iter, iter_vision)

        # Update master plan
        update_iteration_status(master_plan, iter_id, 'COMPLETE')
    else:
        print(f"❌ Iteration {iter_id}/{total_iterations} validation failed")
        print("   Healing will be attempted...")
        # Healing is handled within execute_iteration
        break  # Stop multi-iteration execution on failure

print("")
print("✅ All planned iterations complete!")
print(f"🎉 MVP ready! Plan: {plan_id}")
```

---

## Iteration Execution Logic (execute_iteration)

```python
def execute_iteration(plan_id, iter_id, global_iter, iteration_config):
    """
    Execute a single iteration through all phases.
    This is the core iteration loop that was in the deleted orchestrator.
    """

    ITER_DIR = f".2L/{plan_id}/iteration-{global_iter}"

    # Update config
    update_config_current_phase('exploration')
    update_config_current_iteration(global_iter)

    # EVENT: iteration_start
    # Mark the beginning of a new iteration
    if [ "$EVENT_LOGGING_ENABLED" = true ]; then
      iter_vision=$(head -n 1 ${ITER_DIR}/../vision.md 2>/dev/null || echo "Iteration ${global_iter}")
      log_2l_event "iteration_start" "Iteration ${global_iter}: ${iter_vision}" "initialization" "orchestrator"
    fi

    # Event details:
    # - event_type: "iteration_start" - Iteration boundary marker
    # - data: Includes global iteration number and vision summary
    # - phase: "initialization" - Before exploration phase begins
    # - Purpose: Dashboard shows iteration boundaries and tracks progress through master plan

    # Phase 1: EXPLORATION
    print(f"   Phase 1: Exploration")

    # EVENT: phase_change (Exploration Start)
    # Signal transition into exploration phase of iteration
    if [ "$EVENT_LOGGING_ENABLED" = true ]; then
      log_2l_event "phase_change" "Starting Exploration phase" "exploration" "orchestrator"
    fi

    # Event details:
    # - event_type: "phase_change" - Phase transition marker
    # - phase: "exploration" - Current iteration phase
    # - Emitted at start of every iteration's exploration phase
    # - Purpose: Dashboard timeline shows phase transitions within iterations

    exploration_dir = f"{ITER_DIR}/exploration"

    if not dir_exists(exploration_dir) or count_explorer_reports(exploration_dir) < 2:
        mkdir -p ${exploration_dir}

        # Spawn 2-3 explorers in parallel
        # Use Task tool with subagent_type: "2l-explorer"

        # EVENT: agent_spawn (Explorer-1)
        # Track creation of iteration explorer agents
        if [ "$EVENT_LOGGING_ENABLED" = true ]; then
          log_2l_event "agent_spawn" "Explorer-1: Architecture & Structure" "exploration" "explorer-1"
        fi

        # Event details:
        # - Emitted for each explorer spawned during iteration
        # - agent_id format: "explorer-{N}" where N is explorer number
        # - Each explorer will emit its own agent_complete event when done

        spawn_task(
            type="2l-explorer",
            prompt=f"Explorer 1: Architecture & Structure

Iteration: {global_iter}
Requirements: {ITER_DIR}/../vision.md (or iteration-specific vision)
Output: {exploration_dir}/explorer-1-report.md

Analyze:
- Application architecture
- Main components and relationships
- File/folder structure
- Entry points and boundaries

Create report at: {exploration_dir}/explorer-1-report.md"
        )

        # EVENT: agent_spawn (Explorer-2)
        if [ "$EVENT_LOGGING_ENABLED" = true ]; then
          log_2l_event "agent_spawn" "Explorer-2: Technology Patterns & Dependencies" "exploration" "explorer-2"
        fi

        spawn_task(
            type="2l-explorer",
            prompt=f"Explorer 2: Technology Patterns & Dependencies

Iteration: {global_iter}
Requirements: {ITER_DIR}/../vision.md
Output: {exploration_dir}/explorer-2-report.md

Analyze:
- Frameworks and libraries to use
- Coding patterns for this domain
- External integrations required
- Dependencies to consider

Create report at: {exploration_dir}/explorer-2-report.md"
        )

        # Optional 3rd explorer for complex iterations
        if iteration_config.get('complexity') in ['HIGH', 'VERY HIGH']:
            spawn_task(
                type="2l-explorer",
                prompt=f"Explorer 3: Complexity & Integration Points

Iteration: {global_iter}
Requirements: {ITER_DIR}/../vision.md
Output: {exploration_dir}/explorer-3-report.md

Analyze:
- Most complex features
- Integration challenges
- Features needing subdivision
- Critical dependencies between features

Create report at: {exploration_dir}/explorer-3-report.md"
            )

        print("      Explorers spawned, waiting for completion...")
        # Task tool waits for completion

        # EVENT: agent_complete (Explorers)
        # NOTE: In actual implementation, each explorer emits its own agent_complete event
        # This documents the expected event pattern
        if [ "$EVENT_LOGGING_ENABLED" = true ]; then
          log_2l_event "agent_complete" "Explorer-1 completed" "exploration" "explorer-1"
          log_2l_event "agent_complete" "Explorer-2 completed" "exploration" "explorer-2"
        fi

        # Event details:
        # - One agent_complete event per explorer
        # - Emitted by each explorer agent when writing final report
        # - Dashboard uses these to calculate exploration phase duration

    # Phase 2: PLANNING
    print(f"   Phase 2: Planning")

    # EVENT: phase_change (Planning Start)
    # Signal transition from exploration to planning phase
    if [ "$EVENT_LOGGING_ENABLED" = true ]; then
      log_2l_event "phase_change" "Starting Planning phase" "planning" "orchestrator"
    fi

    # Event details:
    # - phase: "planning" - Planner synthesizes exploration into build plan
    # - Follows completion of all explorers

    plan_dir = f"{ITER_DIR}/plan"

    if not dir_exists(plan_dir):
        mkdir -p ${plan_dir}

        # Spawn planner
        # Use Task tool with subagent_type: "2l-planner"

        # EVENT: agent_spawn (Planner)
        # Track planner agent creation
        if [ "$EVENT_LOGGING_ENABLED" = true ]; then
          log_2l_event "agent_spawn" "Planner: Creating development plan" "planning" "planner-1"
        fi

        # Event details:
        # - Single planner agent per iteration
        # - agent_id: "planner-1" (or just "planner" for singleton)

        spawn_task(
            type="2l-planner",
            prompt=f"Create comprehensive development plan.

Iteration: {global_iter}
Requirements: {ITER_DIR}/../vision.md
Exploration: {exploration_dir}
Output: {plan_dir}

Read all exploration reports and create 4 files:
1. overview.md - Project vision and success criteria
2. tech-stack.md - Technology decisions with rationale
3. patterns.md - Code patterns and conventions
4. builder-tasks.md - Builder task breakdown

All files go in: {plan_dir}/"
        )

        print("      Planner spawned, waiting for completion...")

        # EVENT: agent_complete (Planner)
        # NOTE: Planner emits this event itself when writing final plan files
        if [ "$EVENT_LOGGING_ENABLED" = true ]; then
          log_2l_event "agent_complete" "Planner-1 completed" "planning" "planner-1"
        fi

        # Event details:
        # - Emitted when all 4 plan files created (overview, tech-stack, patterns, builder-tasks)

    # Phase 3: BUILDING
    print(f"   Phase 3: Building")

    # EVENT: phase_change (Building Start)
    # Signal transition from planning to building phase
    if [ "$EVENT_LOGGING_ENABLED" = true ]; then
      log_2l_event "phase_change" "Starting Building phase" "building" "orchestrator"
    fi

    # Event details:
    # - phase: "building" - Builders implement features based on plan
    # - Typically the longest phase in iteration

    building_dir = f"{ITER_DIR}/building"
    mkdir -p ${building_dir}

    # Read builder tasks
    builder_tasks = read_file(f"{plan_dir}/builder-tasks.md")
    num_builders = extract_number_of_builders(builder_tasks)

    print(f"      {num_builders} builders planned")

    # Spawn all primary builders in parallel
    for builder_id in range(1, num_builders + 1):
        builder_report = f"{building_dir}/builder-{builder_id}-report.md"

        if not file_exists(builder_report):
            # EVENT: agent_spawn (Builder)
            # Track creation of each builder agent
            if [ "$EVENT_LOGGING_ENABLED" = true ]; then
              log_2l_event "agent_spawn" "Builder-${builder_id}: Building assigned feature" "building" "builder-${builder_id}"
            fi

            # Event details:
            # - One agent_spawn per builder (typically 2-4 builders per iteration)
            # - agent_id format: "builder-{N}" where N is builder number from plan

            spawn_task(
                type="2l-builder",
                prompt=f"Build assigned feature.

Iteration: {global_iter}
Your ID: Builder-{builder_id}
Plan: {plan_dir}
Output: {building_dir}/builder-{builder_id}-report.md

Read your task from: {plan_dir}/builder-tasks.md
Follow patterns from: {plan_dir}/patterns.md

You can COMPLETE or SPLIT if too complex.

Create report at: {building_dir}/builder-{builder_id}-report.md"
            )

    print(f"      Builders spawned, waiting for completion...")

    # Check for SPLIT decisions and spawn sub-builders
    for builder_id in range(1, num_builders + 1):
        builder_report = f"{building_dir}/builder-{builder_id}-report.md"
        status = extract_builder_status(builder_report)

        if status == 'SPLIT':
            print(f"      Builder-{builder_id} split, spawning sub-builders...")

            # Parse sub-builder tasks from report
            sub_tasks = extract_sub_builder_tasks(builder_report)

            for sub_id, sub_task in enumerate(sub_tasks, start=1):
                sub_builder_id = f"{builder_id}{chr(64+sub_id)}"  # 1A, 1B, etc.
                sub_report = f"{building_dir}/builder-{sub_builder_id}-report.md"

                if not file_exists(sub_report):
                    spawn_task(
                        type="2l-builder",
                        prompt=f"Build sub-feature from split.

Iteration: {global_iter}
Your ID: Builder-{sub_builder_id}
Foundation: {building_dir}/builder-{builder_id}-report.md
Sub-task: {sub_task}

Read foundation and your sub-task.
Complete the sub-task (no further splitting allowed).

Create report at: {building_dir}/builder-{sub_builder_id}-report.md"
                    )

            print(f"         Sub-builders spawned for Builder-{builder_id}")

    # Phase 4: INTEGRATION (Multi-Round)
    print(f"   Phase 4: Integration")

    # EVENT: phase_change (Integration Start)
    # Signal transition from building to integration phase
    if [ "$EVENT_LOGGING_ENABLED" = true ]; then
      log_2l_event "phase_change" "Starting Integration phase" "integration" "orchestrator"
    fi

    # Event details:
    # - phase: "integration" - Merge builder outputs into cohesive codebase
    # - May have multiple rounds (up to 3) if conflicts detected

    integration_dir = f"{ITER_DIR}/integration"
    mkdir -p ${integration_dir}

    max_integration_rounds = 3
    integration_round = 1

    while integration_round <= max_integration_rounds:
        round_dir = f"{integration_dir}/round-{integration_round}"
        mkdir -p ${round_dir}

        print(f"      Integration Round {integration_round}")

        # Step 4.1: Iplanner
        integration_plan = f"{round_dir}/integration-plan.md"

        if not file_exists(integration_plan):
            print(f"         Creating integration plan...")

            spawn_task(
                type="2l-iplanner",
                prompt=f"Analyze builder outputs and create zone-based integration plan.

Iteration: {global_iter}
Round: {integration_round}
Builders: {building_dir}
Plan: {plan_dir}
Output: {round_dir}/integration-plan.md

Read all builder reports and create integration zones.
Assign zones to integrators for parallel work.

Create plan at: {round_dir}/integration-plan.md"
            )

        # Step 4.2: Integrators (parallel, based on zones)
        plan_content = read_file(integration_plan)
        integrator_assignments = parse_integrator_assignments(plan_content)

        print(f"         Spawning {len(integrator_assignments)} integrators...")

        for integrator_id, zones in integrator_assignments.items():
            integrator_report = f"{round_dir}/integrator-{integrator_id}-report.md"

            if not file_exists(integrator_report):
                spawn_task(
                    type="2l-integrator",
                    prompt=f"Execute assigned integration zones.

Iteration: {global_iter}
Round: {integration_round}
Your ID: Integrator-{integrator_id}
Integration Plan: {integration_plan}
Assigned Zones: {zones}

Read the integration plan and execute your assigned zones.
Resolve conflicts according to plan strategies.

Create report at: {round_dir}/integrator-{integrator_id}-report.md"
                )

        print(f"         Integrators spawned, waiting for completion...")

        # Step 4.3: Ivalidator
        ivalidation_report = f"{round_dir}/ivalidation-report.md"

        if not file_exists(ivalidation_report):
            print(f"         Running integration validation...")

            spawn_task(
                type="2l-ivalidator",
                prompt=f"Validate organic cohesion of integrated code.

Iteration: {global_iter}
Round: {integration_round}
Integration: {round_dir}
Plan: {plan_dir}

Check all cohesion dimensions:
- No duplicate implementations
- Import consistency
- Type consistency
- No circular dependencies
- Pattern adherence
- Shared code utilization
- Database schema consistency
- No abandoned code

Create report at: {round_dir}/ivalidation-report.md"
            )

        # Check ivalidation result
        ivalidation_status = extract_ivalidation_status(ivalidation_report)

        if ivalidation_status == 'PASS':
            print(f"      ✅ Integration Round {integration_round} passed")

            # Create final integration report
            create_final_integration_report(integration_dir, integration_round)
            break

        elif ivalidation_status == 'FAIL' and integration_round < max_integration_rounds:
            print(f"      ⚠️  Integration Round {integration_round} failed, starting round {integration_round + 1}")
            integration_round += 1
            continue

        else:  # FAIL and round == 3
            print(f"      ⚠️  Integration Round {integration_round} failed (final round)")
            print(f"         Proceeding with partial integration...")
            create_final_integration_report(integration_dir, integration_round, status='PARTIAL')
            break

    # Phase 5: VALIDATION
    print(f"   Phase 5: Validation")

    # EVENT: phase_change (Validation Start)
    # Signal transition from integration to validation phase
    if [ "$EVENT_LOGGING_ENABLED" = true ]; then
      log_2l_event "phase_change" "Starting Validation phase" "validation" "orchestrator"
    fi

    # Event details:
    # - phase: "validation" - Validator runs all tests and checks
    # - Critical phase that determines iteration success/failure

    validation_dir = f"{ITER_DIR}/validation"
    mkdir -p ${validation_dir}

    validation_report = f"{validation_dir}/validation-report.md"

    if not file_exists(validation_report):
        spawn_task(
            type="2l-validator",
            prompt=f"Validate MVP for production readiness.

Iteration: {global_iter}
Integration: {integration_dir}
Plan: {plan_dir}

Run all validation checks:
1. TypeScript compilation
2. Linting
3. Code formatting
4. Unit tests
5. Integration tests
6. Build process
7. Development server
8. Success criteria verification
9. MCP-based validation (performance, E2E, database)

Determine PASS or FAIL.

Create report at: {validation_dir}/validation-report.md"
        )

    # Check validation result
    validation_status = extract_validation_status(validation_report)

    # EVENT: validation_result
    # Document the outcome of validation phase
    if [ "$EVENT_LOGGING_ENABLED" = true ]; then
      log_2l_event "validation_result" "Validation: ${validation_status}" "validation" "validator-1"
    fi

    # Event details:
    # - event_type: "validation_result" - Special event for validation outcome
    # - data: Includes validation status (PASS or FAIL)
    # - agent_id: "validator-1" (validator agent that ran the checks)
    # - Purpose: Dashboard highlights validation success/failure prominently

    if validation_status == 'PASS':
        print(f"   ✅ Validation PASSED")
        return  # Iteration complete!

    # Phase 6: HEALING (if validation failed)
    print(f"   ⚠️  Validation FAILED")
    print(f"   Phase 6: Healing")

    # EVENT: phase_change (Healing Start)
    # Signal transition to healing phase after validation failure
    if [ "$EVENT_LOGGING_ENABLED" = true ]; then
      log_2l_event "phase_change" "Starting Healing phase" "healing" "orchestrator"
    fi

    # Event details:
    # - phase: "healing" - Healers fix validation failures
    # - Only occurs if validation status == FAIL
    # - Up to 2 healing attempts before manual intervention required

    max_healing_attempts = 2
    healing_attempt = 1

    while healing_attempt <= max_healing_attempts:
        healing_dir = f"{ITER_DIR}/healing-{healing_attempt}"
        mkdir -p ${healing_dir}

        print(f"      Healing Attempt {healing_attempt}")

        # Step 6.1: HEALING EXPLORATION
        print(f"         Step 1: Exploration (analyze failures)")

        healing_exploration_dir = f"{healing_dir}/exploration"
        mkdir -p ${healing_exploration_dir}

        # Spawn 1-2 healing explorers to analyze the validation failures
        # This helps healers understand root causes before fixing

        exploration_report_1 = f"{healing_exploration_dir}/healing-explorer-1-report.md"

        if not file_exists(exploration_report_1):
            spawn_task(
                type="2l-explorer",
                prompt=f"Analyze validation failures to guide healing.

Iteration: {global_iter}
Healing Attempt: {healing_attempt}
Focus: Root Cause Analysis

Validation Report: {validation_report}
Codebase: Current state with failures

Your mission:
1. Read the validation report carefully
2. Categorize failures (TypeScript, tests, lint, build, logic bugs, etc.)
3. For each failure category, identify:
   - Root causes (not just symptoms)
   - Affected files and components
   - Dependencies between failures
   - Recommended fix strategies
4. Create a failure analysis that will guide healers

Create report at: {healing_exploration_dir}/healing-explorer-1-report.md

Report structure:
## Failure Categories

### Category: [Name]
- Count: [number of issues]
- Severity: HIGH | MEDIUM | LOW
- Root Cause: [analysis]
- Affected Files: [list]
- Fix Strategy: [recommendation]
- Dependencies: [other categories that must be fixed first/simultaneously]

## Critical Path
[Which categories should be fixed first and why]

## Risk Assessment
[Potential complications during healing]"
            )

        # Optional: Spawn second explorer for complex failures
        issues_preview = extract_issues_by_category(validation_report)
        num_categories = len(issues_preview)

        if num_categories > 3:
            exploration_report_2 = f"{healing_exploration_dir}/healing-explorer-2-report.md"

            if not file_exists(exploration_report_2):
                spawn_task(
                    type="2l-explorer",
                    prompt=f"Analyze inter-dependencies and integration risks in failures.

Iteration: {global_iter}
Healing Attempt: {healing_attempt}
Focus: Integration & Dependency Analysis

Validation Report: {validation_report}
Primary Analysis: {healing_exploration_dir}/healing-explorer-1-report.md

Your mission:
1. Identify dependencies between different failure categories
2. Map out which fixes might conflict with each other
3. Analyze integration points that need healing
4. Recommend healing order to minimize conflicts

Create report at: {healing_exploration_dir}/healing-explorer-2-report.md

Report structure:
## Inter-Category Dependencies
[Which categories depend on each other]

## Conflict Risks
[Where healer fixes might conflict]

## Healing Order Recommendation
[Optimal sequence for healing categories]

## Integration Considerations
[What to watch during healer integration]"
                )

        print(f"         Exploration complete, proceeding to healing...")

        # Step 6.2: CATEGORIZE AND HEAL
        print(f"         Step 2: Healing (fix issues by category)")

        # Read validation report AND exploration reports to categorize issues
        issues = extract_issues_by_category(validation_report)

        # Read healing exploration insights
        exploration_insights = ""
        if file_exists(exploration_report_1):
            exploration_insights = read_file(exploration_report_1)

        print(f"         Issue categories: {list(issues.keys())}")

        # Spawn healers in parallel (one per category)
        for category, issue_list in issues.items():
            healer_id = get_healer_id_for_category(category)
            healer_report = f"{healing_dir}/healer-{healer_id}-report.md"

            if not file_exists(healer_report):
                spawn_task(
                    type="2l-healer",
                    prompt=f"Fix issues in assigned category.

Iteration: {global_iter}
Healing Attempt: {healing_attempt}
Category: {category}

Validation Report: {validation_report}
Healing Exploration: {healing_exploration_dir}/healing-explorer-1-report.md

Read the validation report AND the healing exploration report.
The exploration report provides root cause analysis and fix strategies.

Fix all issues in category: {category}
Issues: {issue_list}

Follow the recommended fix strategy from the exploration report.
Consider dependencies and risks identified by explorers.

Create report at: {healing_dir}/healer-{healer_id}-report.md"
                )

        print(f"         Healers spawned, waiting for completion...")

        # Mini-integration: merge healer fixes
        print(f"         Integrating healer fixes...")

        # (Simple merge, or could spawn mini-integrator)
        # For healing, we often just verify files changed by healers

        # Re-validate
        print(f"         Re-validating...")

        validation_report_heal = f"{healing_dir}/validation-report.md"

        spawn_task(
            type="2l-validator",
            prompt=f"Re-validate after healing.

Iteration: {global_iter}
Healing Attempt: {healing_attempt}
Integration: {integration_dir}
Healing: {healing_dir}

Run full validation again.

Create report at: {healing_dir}/validation-report.md"
        )

        # Check re-validation
        validation_status = extract_validation_status(validation_report_heal)

        if validation_status == 'PASS':
            print(f"      ✅ Healing successful!")

            # EVENT: iteration_complete (After Healing)
            # Mark successful iteration completion after healing
            if [ "$EVENT_LOGGING_ENABLED" = true ]; then
              log_2l_event "iteration_complete" "Iteration ${global_iter} completed after healing" "complete" "orchestrator"
            fi

            # Event details:
            # - event_type: "iteration_complete" - Iteration success marker
            # - data: Notes iteration completed after healing (not first-pass validation)
            # - phase: "complete" - Terminal phase
            # - Purpose: Dashboard marks iteration as successful, ready for next iteration

            return  # Iteration complete!

        elif healing_attempt < max_healing_attempts:
            print(f"      ⚠️  Healing attempt {healing_attempt} failed, trying again...")
            healing_attempt += 1
            validation_report = validation_report_heal  # Use new report for next round
            continue

        else:
            print(f"      ❌ Healing failed after {max_healing_attempts} attempts")
            print(f"         Manual intervention required")

            # Escalate to user
            print("")
            print("=" * 60)
            print("MANUAL INTERVENTION REQUIRED")
            print("=" * 60)
            print(f"Iteration {global_iter} could not be healed automatically.")
            print(f"Review: {healing_dir}/validation-report.md")
            print("")

            raise Exception("Iteration healing failed - manual intervention required")
```

---

## Helper Functions

```python
def auto_commit_iteration(plan_id, iter_id, global_iter, iter_vision):
    """
    Auto-commit successful iteration (Mission 3).
    """

    # Stage all changes
    run_command("git add .")

    # Create commit message
    commit_msg = f"""2L Iteration {global_iter} (Plan {plan_id})

Vision: {iter_vision}
Status: PASS
Plan: {plan_id} (iteration {iter_id})

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"""

    # Commit
    run_command(f'git commit -m "{commit_msg}"')

    # Create tag
    tag = f"2l-{plan_id}-iter-{global_iter}"
    run_command(f"git tag {tag}")

    commit_hash = run_command("git rev-parse HEAD").strip()

    # Update config
    update_config_iteration_commit(global_iter, commit_hash, tag)

    print(f"   ✅ Auto-committed: {tag}")

    # Push to GitHub if remote exists
    push_to_github(plan_id, tag)


def create_final_integration_report(integration_dir, final_round, status='SUCCESS'):
    """
    Create final integration report after multi-round integration.
    """

    report_path = f"{integration_dir}/final-integration-report.md"

    content = f"""# Final Integration Report

## Status
{status}

## Integration Rounds Completed
{final_round}

## Summary
Integration completed after {final_round} round(s).

[Include summary from ivalidation of final round]

## Next Phase
Ready for validation.

---
*Generated: {datetime.now().isoformat()}*
"""

    write_file(report_path, content)


def update_iteration_status(master_plan_path, iter_id, status):
    """
    Update iteration status in master-plan.yaml.
    """

    master_plan = read_yaml(master_plan_path)

    for iteration in master_plan['iterations']:
        if iteration['iteration_id'] == iter_id:
            iteration['status'] = status
            break

    write_yaml(master_plan_path, master_plan)


def setup_github_repo(plan_id, plan_dir, project_name=None):
    """
    Create GitHub repository for the PROJECT (not per-plan).
    All plans within a project share the same repository.
    Updates config with GitHub repo URL.
    """

    # Check if gh CLI is available
    gh_check = run_command("gh --version", capture_output=True, check=False)
    if gh_check.returncode != 0:
        print("   ⚠️  GitHub CLI (gh) not installed - skipping GitHub integration")
        print("      Install: https://cli.github.com/")
        return None

    # Check if already authenticated
    auth_check = run_command("gh auth status", capture_output=True, check=False)
    if auth_check.returncode != 0:
        print("   ⚠️  GitHub CLI not authenticated - skipping GitHub integration")
        print("      Run: gh auth login")
        return None

    # Check if remote already exists (from any previous plan)
    remote_check = run_command("git remote get-url origin", capture_output=True, check=False)
    if remote_check.returncode == 0:
        repo_url = remote_check.stdout.strip()
        print(f"   ✓ GitHub repo already exists: {repo_url}")
        # Store repo URL for this plan too
        update_config_github_repo(plan_id, repo_url)
        return repo_url

    # Determine repo name (PROJECT name, not plan-specific)
    if project_name is None:
        project_name = os.path.basename(os.getcwd())

    # Use project name directly, without plan suffix
    repo_name = project_name

    print(f"   🔧 Creating GitHub repository: {repo_name}")

    # Read vision for repo description
    vision_file = f"{plan_dir}/vision.md"
    description = "2L Generated Project"
    if file_exists(vision_file):
        vision_content = read_file(vision_file)
        first_line = vision_content.split('\n')[0].strip('# ')
        description = first_line[:100] if first_line else description

    # Create GitHub repo
    create_result = run_command(
        f'gh repo create {repo_name} --public --source=. --remote=origin --description="{description}"',
        capture_output=True,
        check=False
    )

    if create_result.returncode != 0:
        print(f"   ⚠️  Failed to create GitHub repo: {create_result.stderr}")
        return None

    # Get repo URL
    repo_url = run_command("gh repo view --json url -q .url").strip()

    print(f"   ✅ GitHub repo created: {repo_url}")

    # Store repo URL in config (for this plan and future reference)
    update_config_github_repo(plan_id, repo_url)

    return repo_url


def push_to_github(plan_id, tag=None):
    """
    Push commits and tags to GitHub remote.
    """

    # Check if remote exists
    remote_check = run_command("git remote get-url origin", capture_output=True, check=False)
    if remote_check.returncode != 0:
        # No remote configured, skip push
        return

    repo_url = remote_check.stdout.strip()

    print(f"   📤 Pushing to GitHub: {repo_url}")

    # Get current branch
    branch = run_command("git branch --show-current").strip()

    # Push commits
    push_result = run_command(f"git push origin {branch}", capture_output=True, check=False)

    if push_result.returncode != 0:
        print(f"   ⚠️  Push failed: {push_result.stderr}")
        return

    print(f"   ✅ Pushed to {branch}")

    # Push tags if specified
    if tag:
        tag_push_result = run_command(f"git push origin {tag}", capture_output=True, check=False)
        if tag_push_result.returncode == 0:
            print(f"   ✅ Pushed tag: {tag}")
        else:
            print(f"   ⚠️  Tag push failed: {tag_push_result.stderr}")


def update_config_github_repo(plan_id, repo_url):
    """
    Update config with GitHub repository URL for a plan.
    """

    config_file = ".2L/config.yaml"
    config = read_yaml(config_file)

    for plan in config.get('plans', []):
        if plan.get('plan_id') == plan_id:
            plan['github_repo'] = repo_url
            break

    write_yaml(config_file, config)
```

---

## Level 1 Setup: Auto-Generate Vision

```bash
# Determine next plan ID
PLAN_COUNT=$(find .2L/plan-* -maxdepth 0 -type d 2>/dev/null | wc -l)
NEXT_PLAN=$((PLAN_COUNT + 1))
PLAN_ID="plan-${NEXT_PLAN}"
PLAN_DIR=".2L/${PLAN_ID}"

# Create plan directory
mkdir -p ${PLAN_DIR}

# Auto-generate vision.md
echo "📝 Generating vision from inline requirements..."

# Create simple vision document
cat > ${PLAN_DIR}/vision.md <<EOF
# Vision: ${INLINE_REQUIREMENTS}

## Overview

${INLINE_REQUIREMENTS}

## Approach

This vision was auto-generated from inline requirements.
Master exploration will analyze and create appropriate iteration breakdown.

## Requirements

${INLINE_REQUIREMENTS}

---

*Auto-generated: $(date -I)*
*Plan ID: ${PLAN_ID}*
EOF

# Initialize/update config
if [ ! -f .2L/config.yaml ]; then
    cat > .2L/config.yaml <<EOF
current_plan: ${PLAN_ID}
global_iteration_counter: 0

plans:
  - plan_id: ${PLAN_ID}
    name: "Auto-generated from inline requirements"
    status: VISIONED
    created_at: "$(date -Iseconds)"
    vision_file: .2L/${PLAN_ID}/vision.md
EOF
else
    # Update existing config
    # Add new plan entry and set as current
    echo "Updating config with new plan..."
fi

echo "✅ Vision created: ${PLAN_DIR}/vision.md"
echo "🚀 Starting master orchestration..."
```

---

## Context Management & Infinite Resumability

**If I need to compact this session during execution:**

Before compacting, I will:

1. **Ensure current phase is checkpointed:**
   - All agent reports written to `.2L/`
   - Current phase status saved in config.yaml
   - No in-flight operations

2. **Create continuation instruction:**
   - The next session will automatically receive:

> /2l-continue is running…

3. **State preservation:**
   - All progress saved in `.2L/` directory structure
   - Next session will detect exact resume point
   - Workflow continues seamlessly

**This enables infinite orchestration:**
- MVP can span any number of sessions
- Each session auto-triggers `/2l-continue`
- No manual intervention needed
- Complete context resilience

---

## Progress Reporting

Throughout execution, provide clear status updates:

**Level 1:**
- "📝 Generating vision from inline requirements..."
- "✅ Vision created"
- "🔍 Running master exploration..."
- "📊 Creating master plan..."
- "🚀 Executing iteration 1/3..."

**Level 2:**
- "📋 Using existing vision"
- "🔍 Running master exploration..."
- "📊 Auto-planning iteration breakdown..."
- "🚀 Executing iteration 1/2..."

**Level 3:**
- "📋 Using existing vision and master plan"
- "📊 3 iterations planned"
- "🚀 Executing iteration 1/3..."
- "✅ Iteration 1 complete. Auto-committed: 2l-plan-1-iter-1"

---

## Output Structure

After `/2l-mvp` completes (any level):

```
.2L/
├── config.yaml
└── plan-{N}/
    ├── vision.md                       # From inline OR /2l-vision
    ├── master-exploration/             # Auto-generated
    │   ├── master-explorer-1-report.md
    │   └── master-explorer-2-report.md
    ├── master-plan.yaml                # Auto OR from /2l-plan
    ├── iteration-{M}/                  # Global iteration number
    │   ├── exploration/
    │   ├── plan/
    │   ├── building/
    │   ├── integration/
    │   │   ├── round-1/
    │   │   ├── round-2/ (if needed)
    │   │   ├── round-3/ (if needed)
    │   │   └── final-integration-report.md
    │   ├── validation/
    │   └── healing-{1,2}/ (if needed)
    └── iteration-{M+1}/
```

---

## MCP Server Availability

You have access to powerful Model Context Protocol servers:

- **Playwright MCP** - Browser automation and testing
- **Chrome DevTools MCP** - Performance profiling and debugging
- **Supabase Local MCP** - Database operations (port 5432)
- **GitHub MCP** - Code research and pattern discovery
- **Screenshot MCP** - Visual testing and documentation

These are available to all agents throughout the 2L workflow.

---

## Requirements

**Before running:**
- You're in the project root directory
- You have time for autonomous execution (varies by level and complexity)

**For database work:**
- Supabase running on port 5432 (if needed)

---

## Error Handling

**If no arguments and no active plan:**
```
❌ No active plan found.

Options:
  1. Provide inline requirements:
     /2l-mvp "Build a todo app with auth"

  2. Create vision first:
     /2l-vision
     /2l-mvp
```

**If plan is COMPLETE:**
```
✅ Plan ${PLAN_ID} is already complete!

To start new work:
  /2l-vision    # Create new plan
```

**If plan is ABANDONED:**
```
⚠️  Plan ${PLAN_ID} was abandoned.

Options:
  1. Resume it (if appropriate)
  2. Create new plan: /2l-vision
```

---

Now let's build this MVP! 🚀

**Note:** This command IS the orchestrator. All orchestration logic executes directly within this command session. If context limits are reached, the workflow will checkpoint and `/2l-continue` will resume from the exact state.
