# 2L Plan - Interactive Master Planning

Create a master plan through interactive conversation. The session becomes the master planner, analyzing vision, running strategic exploration, and guiding you through iteration breakdown.

## Usage

```bash
/2l-plan
```

No arguments needed - automatically uses current plan from config.

---

## What This Does

1. **Checks Prerequisites** - Ensures vision.md exists
2. **Runs Master Exploration** - Spawns 2 explorers for strategic analysis (if not done)
3. **Conducts Interactive Planning** - Session engages in back-and-forth conversation to refine iteration breakdown
4. **Creates master-plan.yaml** - When user approves the plan
5. **Updates Config** - Changes plan status from VISIONED to PLANNED

---

## When to Use

✅ **After** running `/2l-vision` (have vision.md)
✅ **Before** running `/2l-mvp` (want to control iteration breakdown)
✅ Want interactive control over how work is split into iterations

**Workflow:**
```bash
/2l-vision           # Create vision.md
/2l-plan             # Create master-plan.yaml (interactive)
/2l-mvp              # Execute the plan
```

---

## Your Role as Master Planner

When `/2l-plan` is invoked, **YOU ARE** the master planner. You will:

1. **Read and analyze** the vision and exploration reports
2. **Synthesize findings** into an initial iteration breakdown recommendation
3. **Present the recommendation** to the user clearly
4. **Engage in conversation** to refine and iterate on the plan
5. **Create master-plan.yaml** when the user approves
6. **Update .2L/config.yaml** to set status: PLANNED

---

## Step 1: Validate Prerequisites

First, check that all prerequisites are met:

```bash
# Read global config
CONFIG_FILE=".2L/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ No .2L config found. Run /2l-vision first."
  exit 1
fi

# Get current plan
CURRENT_PLAN=$(grep "current_plan:" $CONFIG_FILE | awk '{print $2}')
PLAN_DIR=".2L/${CURRENT_PLAN}"

if [ ! -d "$PLAN_DIR" ]; then
  echo "❌ Plan directory not found: $PLAN_DIR"
  exit 1
fi

# Check for vision.md
VISION_FILE="${PLAN_DIR}/vision.md"
if [ ! -f "$VISION_FILE" ]; then
  echo "❌ No vision.md found in $PLAN_DIR"
  echo "Run /2l-vision first."
  exit 1
fi

# Check plan status
PLAN_STATUS=$(grep -A5 "plan_id: ${CURRENT_PLAN}" $CONFIG_FILE | grep "status:" | awk '{print $2}')

if [ "$PLAN_STATUS" = "PLANNED" ]; then
  echo "⚠️  Master plan already exists: ${PLAN_DIR}/master-plan.yaml"
  echo ""
  echo "Options:"
  echo "  1. Edit the existing plan manually"
  echo "  2. Delete master-plan.yaml to recreate"
  echo "  3. Run /2l-mvp to execute existing plan"
  exit 0
fi

if [ "$PLAN_STATUS" != "VISIONED" ]; then
  echo "❌ Plan status is $PLAN_STATUS (expected VISIONED)"
  echo "Current plan must be in VISIONED state to create master plan."
  exit 1
fi
```

---

## Step 2: Run Master Exploration with Adaptive Spawning (if needed)

Analyze vision complexity and spawn appropriate number of explorers (2-4):

```bash
# Check if master exploration already done
EXPLORATION_DIR="${PLAN_DIR}/master-exploration"
VISION_FILE="${PLAN_DIR}/vision.md"

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
yq eval ".plans[] | select(.plan_id == \"$CURRENT_PLAN\") | .master_exploration.num_explorers = $num_explorers" -i .2L/config.yaml
yq eval ".plans[] | select(.plan_id == \"$CURRENT_PLAN\") | .master_exploration.complexity_level = \"$complexity\"" -i .2L/config.yaml

# Check if master exploration needs to run
if [ ! -d "$EXPLORATION_DIR" ] || [ $(ls ${EXPLORATION_DIR}/master-explorer-*-report.md 2>/dev/null | wc -l) -lt $num_explorers ]; then
  echo "🔍 Running master exploration..."
  echo ""

  mkdir -p "$EXPLORATION_DIR"

  # Spawn explorers in parallel (1 to num_explorers)
  for explorer_id in $(seq 1 $num_explorers); do
      REPORT_FILE="${EXPLORATION_DIR}/master-explorer-${explorer_id}-report.md"

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

      # Spawn explorer using task tool (parallel execution)
      # Use Task tool with subagent_type: "2l-master-explorer"
  done

  echo "   Waiting for $num_explorers master explorers to complete..."
fi
```

**Explorer Prompts (dynamically assigned based on num_explorers):**

All explorers receive the same basic structure with their assigned focus area:

```
You are Master Explorer {explorer_id}.

Focus Area: {FOCUS_AREA}

Plan: {CURRENT_PLAN}
Vision file: {PLAN_DIR}/vision.md

Your mission:
- Read the vision document thoroughly
- Analyze your assigned focus area in depth
- Follow the focus area guidelines in your agent definition
- Provide specific, actionable insights
- Recommend iteration strategy based on your findings

Create your report at: {PLAN_DIR}/master-exploration/master-explorer-{explorer_id}-report.md

Follow the report structure template in the 2l-master-explorer agent definition.
```

**Focus Areas by Explorer ID:**
- Explorer 1: Architecture & Complexity Analysis (always spawned)
- Explorer 2: Dependencies & Risk Assessment (always spawned)
- Explorer 3: User Experience & Integration Points (spawned if num_explorers >= 3)
- Explorer 4: Scalability & Performance Considerations (spawned if num_explorers == 4)

**Wait for all explorers to complete before proceeding.**

---

## Step 3: Read and Synthesize

Read all the planning inputs dynamically (handles 2-4 explorer reports):

```bash
# Read vision document
VISION_CONTENT=$(cat ${PLAN_DIR}/vision.md)

# Read all explorer reports dynamically
EXPLORER_REPORTS=""
REPORT_COUNT=0

for report in ${PLAN_DIR}/master-exploration/master-explorer-*-report.md; do
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

echo "Found $REPORT_COUNT explorer reports to synthesize"
```

Analyze and synthesize from all available reports:
- What is the overall complexity level?
- What are the major architectural phases?
- What are the dependency chains?
- What are the key risks?
- What integration points and UX considerations exist? (if Explorer 3 ran)
- What scalability and performance concerns exist? (if Explorer 4 ran)
- Should this be single or multi-iteration?
- If multi: how many iterations and what breakdown?

---

## Step 4: Present Initial Recommendation

Present your initial iteration breakdown recommendation to the user in a clear, structured format:

```markdown
# Master Plan Recommendation

## Vision Summary
{1-2 sentence summary of what we're building}

## Complexity Assessment
**Overall Complexity:** {SIMPLE | MEDIUM | COMPLEX | VERY COMPLEX}

**Key factors:**
- {Factor 1}
- {Factor 2}
- {Factor 3}

## Recommendation: {SINGLE ITERATION | MULTI-ITERATION ({N} iterations)}

{If SINGLE ITERATION:}

### Single Iteration Approach
**Rationale:**
- {Why one iteration is sufficient}
- {Estimated duration}
- {All features can be built together}

**Proposed scope:**
- {Feature 1}
- {Feature 2}
- {Feature 3}

{If MULTI-ITERATION:}

### Iteration Breakdown

**Iteration 1: {Phase Name}**
- **Vision:** {One-line description}
- **Scope:**
  - {Component/Feature 1}
  - {Component/Feature 2}
  - {Component/Feature 3}
- **Why first:** {Strategic reasoning}
- **Estimated duration:** {hours}
- **Success criteria:** {How we know it's done}

**Iteration 2: {Phase Name}**
- **Vision:** {One-line description}
- **Scope:**
  - {Feature 1}
  - {Feature 2}
- **Dependencies:** Requires Iteration 1 completion
- **Estimated duration:** {hours}
- **Success criteria:** {How we know it's done}

{Continue for all iterations...}

## Questions for You

Before I finalize this plan, I'd like your input on:

1. {Question about iteration breakdown}
2. {Question about scope/priorities}
3. {Question about any unclear requirements}
```

---

## Step 5: Interactive Refinement

Engage in back-and-forth conversation with the user to refine the plan:

**Listen for:**
- Concerns about iteration breakdown
- Requests to move features between iterations
- Scope clarifications
- Priority changes
- Timeline constraints
- Risk concerns

**Respond by:**
- Adjusting iteration breakdown based on feedback
- Explaining trade-offs and implications
- Asking clarifying questions
- Presenting revised recommendations
- Confirming understanding

**Continue iterating until the user approves the plan.**

---

## Step 6: Create master-plan.yaml

Once the user approves the iteration breakdown, create the master plan YAML file:

**File location:** `{PLAN_DIR}/master-plan.yaml`

**YAML Structure:**

```yaml
# Master Plan for {Project Name}
# Created: {ISO timestamp}
# Plan ID: {CURRENT_PLAN}

plan_id: {CURRENT_PLAN}
created_at: "{ISO timestamp}"
vision_file: .2L/{CURRENT_PLAN}/vision.md

# Plan Status
status: PLANNED

# Iteration Strategy
iteration_strategy: {single | multi}
total_iterations: {N}

# Global Iteration Numbering
# Each iteration gets a unique global number across all plans
# Format: iteration-{global-number}

iterations:
  - iteration_id: iteration-{global-1}
    iteration_number: {global-1}
    phase_name: "{Phase Name}"
    vision: "{One-line iteration vision}"

    scope:
      - "{Feature/Component 1}"
      - "{Feature/Component 2}"
      - "{Feature/Component 3}"

    dependencies:
      iteration_dependencies: []  # or [iteration-{N}] if depends on previous
      external_dependencies:
        - "{External dependency if any}"

    success_criteria:
      - "{Criterion 1}"
      - "{Criterion 2}"
      - "{Criterion 3}"

    estimated_duration_hours: {X}
    risk_level: {LOW | MEDIUM | HIGH}

    status: NOT_STARTED

  - iteration_id: iteration-{global-2}
    iteration_number: {global-2}
    phase_name: "{Phase Name}"
    vision: "{One-line iteration vision}"

    scope:
      - "{Feature 1}"
      - "{Feature 2}"

    dependencies:
      iteration_dependencies:
        - iteration-{global-1}  # Must complete iteration 1 first
      external_dependencies: []

    success_criteria:
      - "{Criterion 1}"
      - "{Criterion 2}"

    estimated_duration_hours: {Y}
    risk_level: {LOW | MEDIUM | HIGH}

    status: NOT_STARTED

# Global metadata
metadata:
  total_estimated_hours: {sum of all iteration hours}
  overall_risk_level: {LOW | MEDIUM | HIGH}
  requires_mvp_approval: true

  # Explorer recommendations (for reference)
  exploration_summary:
    architecture_complexity: "{from explorer 1}"
    dependency_risk: "{from explorer 2}"
    recommended_iterations: {N}
```

**Global Iteration Numbering:**
- Each iteration gets a globally unique number
- Read `.2L/config.yaml` to get `next_iteration_number`
- Assign sequential numbers starting from that value
- Update `next_iteration_number` in config after creating plan

---

## Step 7: Update .2L/config.yaml

Update the global config to reflect the completed planning:

```yaml
# Update the plan entry
plans:
  - plan_id: {CURRENT_PLAN}
    status: PLANNED  # Changed from VISIONED
    created_at: "{timestamp}"
    vision_file: .2L/{CURRENT_PLAN}/vision.md
    master_plan_file: .2L/{CURRENT_PLAN}/master-plan.yaml  # Added
    iterations:
      - iteration-{global-1}
      - iteration-{global-2}
      # ... all iterations

# Update global iteration counter
next_iteration_number: {global-N + 1}  # Next available iteration number

# Current plan remains the same
current_plan: {CURRENT_PLAN}
```

---

## Step 8: Confirm Completion

Present a summary to the user:

```markdown
✅ Master plan created successfully!

📍 Location: {PLAN_DIR}/master-plan.yaml
📊 Status: PLANNED

## Plan Summary

**Total Iterations:** {N}
**Estimated Total Time:** {X} hours
**Overall Risk Level:** {LOW | MEDIUM | HIGH}

### Iterations Overview

1. **Iteration {global-1}: {Phase Name}**
   - Scope: {brief summary}
   - Duration: {X} hours
   - Risk: {level}

2. **Iteration {global-2}: {Phase Name}**
   - Scope: {brief summary}
   - Duration: {Y} hours
   - Risk: {level}
   - Depends on: Iteration {global-1}

{Continue for all iterations...}

## Next Steps

1. **Review the master plan:**
   ```bash
   cat {PLAN_DIR}/master-plan.yaml
   ```

2. **Edit if needed** (YAML format)
   - You can manually adjust the plan before execution
   - Update scope, dependencies, or iteration breakdown

3. **When ready to execute:**
   ```bash
   /2l-mvp
   ```
   This will execute all iterations in sequence according to the master plan.

Would you like to review the plan or proceed to execution?
```

---

## Interactive Planning Conversation Flow

### Opening
"I've analyzed the vision and exploration reports. Let me present my recommendation for how we should break down this project into iterations..."

### Presenting Recommendation
- Clear, structured presentation of iteration breakdown
- Explain rationale for each decision
- Highlight key dependencies and risks
- Make it easy to understand

### Gathering Feedback
- "What are your thoughts on this breakdown?"
- "Does this align with your priorities?"
- "Are there any features you'd like to move to a different iteration?"
- "Do you have timeline constraints I should consider?"

### Refining the Plan
- Listen carefully to user input
- Adjust iteration breakdown based on feedback
- Explain implications of changes
- Present revised recommendations
- Confirm understanding

### Finalizing
- "Based on our discussion, here's the refined plan..."
- Summarize key changes from initial recommendation
- Ask for final approval
- Create the YAML file

### Handling Edge Cases

**If user wants to skip planning:**
- "I recommend going through the planning process to ensure we break down the work optimally, but if you'd like, I can create a default plan based on the explorer recommendations."

**If user is unsure:**
- Provide more context about trade-offs
- Explain benefits of different approaches
- Offer specific recommendations with reasoning

**If scope is unclear:**
- Ask clarifying questions
- Reference the vision document
- Suggest exploring specific areas further if needed

---

## Master Plan YAML Guidelines

### Iteration Breakdown Principles

1. **Dependency-driven:** Earlier iterations build foundations for later ones
2. **Risk-balanced:** High-risk items in early iterations when possible
3. **Value-focused:** Each iteration should deliver tangible value
4. **Scope-limited:** Iterations should be completable (not too ambitious)
5. **Clear boundaries:** Minimal overlap between iterations

### Iteration Sizing

- **Small iteration:** 3-6 hours (few features, focused scope)
- **Medium iteration:** 6-12 hours (moderate features, some complexity)
- **Large iteration:** 12-20 hours (many features or high complexity)
- **Very large:** >20 hours (consider splitting further)

### Success Criteria

Make them specific and measurable:
- ✅ "Authentication system allows login/logout/signup with email"
- ❌ "Authentication works"

- ✅ "Dashboard displays user's 10 most recent transactions"
- ❌ "Dashboard is built"

### Dependencies

**Iteration dependencies:**
- List other iterations that must complete first
- Example: `iteration_dependencies: [iteration-5]`

**External dependencies:**
- Third-party services or APIs
- Existing codebase components
- Manual setup tasks

---

## Output Structure

After `/2l-plan` completes:

```
.2L/
└── plan-{N}/
    ├── vision.md                           # ✅ Exists (from /2l-vision)
    ├── master-exploration/                 # ✅ Created
    │   ├── master-explorer-1-report.md     # ✅ Architecture & Complexity
    │   └── master-explorer-2-report.md     # ✅ Dependencies & Risk
    └── master-plan.yaml                    # ✅ Created (interactive)
```

**Config updated:**
```yaml
plans:
  - plan_id: plan-{N}
    status: PLANNED  # Changed from VISIONED
    master_plan_file: .2L/plan-{N}/master-plan.yaml  # Added
    iterations: [iteration-X, iteration-Y, ...]  # Added

next_iteration_number: {incremented}
```

---

## Integration with Other Commands

```bash
# Workflow 1: Full Control (Level 3)
/2l-vision    # Interactive requirements → vision.md
/2l-plan      # Interactive planning → master-plan.yaml
/2l-mvp       # Execute the plan

# Workflow 2: Vision Control (Level 2)
/2l-vision    # Interactive requirements → vision.md
/2l-mvp       # Auto-plan and execute

# Workflow 3: Full Autonomy (Level 1)
/2l-mvp "Build a todo app with auth"  # Auto everything
```

---

## Key Principles

### You Are the Master Planner

- Don't spawn a sub-agent for planning
- Conduct the planning conversation directly
- Make decisions based on exploration findings
- Guide the user through refinement
- Create the master-plan.yaml yourself

### Be Consultative

- Present recommendations, not dictates
- Explain your reasoning
- Listen to user feedback
- Adapt the plan based on input
- Confirm understanding

### Be Strategic

- Think about dependencies
- Consider risks
- Balance ambition with feasibility
- Focus on delivering value
- Plan for integration points

### Be Clear

- Use structured presentations
- Explain trade-offs
- Provide specific examples
- Make it easy to understand
- Confirm decisions

---

Now let's create your master plan through interactive planning! 🎯
