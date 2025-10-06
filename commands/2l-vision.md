# 2L Vision - Interactive Requirements Gathering

Have a conversation to crystallize your ideas into a structured vision document.

## Usage

```bash
/2l-vision
```

No arguments needed - I'll guide you through clarifying questions interactively.

---

## What This Does

1. **Interactive Conversation** - Direct requirements engineering session with you
2. **Guided Questions** - I'll ask clarifying questions about your project
3. **Creates Vision Document** - Comprehensive `vision.md` with all requirements
4. **Initializes Plan** - Creates `.2L/plan-{N}/` directory structure
5. **Updates Config** - Registers new plan with VISIONED status

---

## When to Use

✅ Starting a new project or major feature set
✅ Have a rough idea but need to clarify scope
✅ Want to document requirements before building
✅ Need to think through features and priorities

❌ Quick one-off tasks (use `/2l-task` instead)
❌ Already have a complete vision document (just run `/2l-mvp`)

---

## Conversation Flow

I'll guide you through:

### 1. Discovery
- What problem you're solving
- Who the users are
- Core value proposition

### 2. Features
- Must-have for MVP
- Should-have for later
- Could-have for future

### 3. User Flows
- How users interact with the system
- Edge cases and error handling

### 4. Success Criteria
- Measurable outcomes
- Acceptance criteria

---

## Example Session

```
You: /2l-vision

Me: Let's build a clear vision for your project!
    What problem are you trying to solve?

You: I want to track my personal finances

Me: Great! What frustrates you about current solutions?

You: They're all too complicated. I just need simple expense tracking.

Me: Perfect - simplicity is key. A few questions:
    1. Who's the primary user - just you or others too?
    2. What data do you want to track for each expense?
    3. How do you want to view your spending?

You: Just me. Amount, category, date, and a note. I want to see monthly totals.

Me: Excellent! Let me clarify scope...
    [Conversation continues with probing questions]

Me: Based on our discussion, here's what I'm capturing:

    Vision: Simple Personal Expense Tracker
    - Manual transaction entry
    - Category-based tracking
    - Monthly spending views
    - Simple charts and lists

    Does this match your vision?

You: Yes, exactly!

Me: ✅ Vision created!

    Location: .2L/plan-3/vision.md
    Status: VISIONED

    Review and edit the vision if needed.

    When ready:
      /2l-plan    - Interactive master planning
      /2l-mvp     - Auto-plan and execute
```

---

## Output Structure

```
.2L/
└── plan-{N}/
    └── vision.md         # Comprehensive vision document
```

The vision.md includes:
- Problem statement
- Target users
- Feature list (categorized by priority)
- User flows
- Data model overview
- Technical requirements
- Success criteria
- Out of scope items
- Assumptions and open questions

---

## Next Steps

After `/2l-vision` completes:

### Option 1: Review and Plan Interactively (Recommended)
```bash
# 1. Review the generated vision
cat .2L/plan-{N}/vision.md

# 2. Edit if needed
vim .2L/plan-{N}/vision.md

# 3. Create master plan interactively
/2l-plan

# 4. Execute the plan
/2l-mvp
```

### Option 2: Auto-Plan and Execute
```bash
# Skip interactive planning, let orchestrator decide iteration breakdown
/2l-mvp
```

---

## Tips for Great Vision Sessions

**Be Specific**
- ❌ "I want user management"
- ✅ "Users can sign up with email, log in, and reset password"

**Focus on Value**
- ❌ "Need a database"
- ✅ "Store user transactions persistently so they don't lose data"

**Prioritize Ruthlessly**
- Distinguish between must-have (MVP) and nice-to-have (later)
- I'll help you scope appropriately

**Think User-First**
- Frame features as user needs, not technical requirements
- "Users can..." vs "System has..."

---

## Editing the Vision

The vision document is yours to edit:

```bash
# After vision creation, before planning
vim .2L/plan-{N}/vision.md

# Make changes:
# - Add forgotten features
# - Clarify acceptance criteria
# - Adjust scope
# - Add technical constraints

# Then proceed with planning
/2l-plan
```

---

## Plan States

After `/2l-vision` runs, your plan will be in **VISIONED** state:

```
plan-{N}: VISIONED
  ↓
  Has: vision.md
  Needs: master-plan.yaml (created by /2l-plan or /2l-mvp)
```

Check status: `/2l-status`

---

## Multiple Plans

You can create multiple visions for different feature sets:

```bash
# Initial MVP
/2l-vision
# ... conversation for initial features ...
# Creates plan-1

/2l-mvp
# ... executes plan-1 ...

# Later: New feature set
/2l-vision
# ... conversation for new features ...
# Creates plan-2

/2l-mvp
# ... executes plan-2 ...
```

Each plan maintains its own vision and iteration history.

---

Now let's build your vision! 🎯

---

## Orchestration Logic

```yaml
# When user runs /2l-vision:

step_1_check_config:
  - Read .2L/config.yaml (or create if missing)
  - Determine next plan number (N = last plan + 1)

step_2_interactive_conversation:
  # Conduct conversation DIRECTLY - no agent spawning
  - Start with: "Let's build a clear vision for your project!"
  - Ask discovery questions:
    * "What problem are you trying to solve?"
    * "Who are the users?"
    * "What frustrates you about current solutions?"

  - Explore features:
    * "What are the must-have features for MVP?"
    * "What would be nice to have later?"
    * "What user flows are critical?"

  - Define success criteria:
    * "How will you know this is successful?"
    * "What are the acceptance criteria?"

  - Clarify scope:
    * "What's explicitly out of scope for now?"
    * "Any technical constraints or preferences?"

step_3_create_structure:
  - mkdir -p .2L/plan-{N}
  - Create vision.md with comprehensive specification

step_4_update_config:
  - Update/create .2L/config.yaml
  - Add new plan entry:
    ```yaml
    plans:
      plan-{N}:
        status: VISIONED
        created: {timestamp}
        vision_file: plan-{N}/vision.md
    ```

step_5_report_to_user:
  - "✅ Vision created!"
  - "Location: .2L/plan-{N}/vision.md"
  - "Status: VISIONED"
  - "Next steps: /2l-plan or /2l-mvp"

step_6_github_setup:
  # Optionally create GitHub repository
  - Ask user: "Would you like to create a GitHub repository for this plan? (y/N)"
  - If yes:
    * Initialize git if not already: `git init && git branch -M main`
    * Create GitHub repo using gh CLI
    * Configure remote origin
    * Store repo URL in config
    * Initial commit of vision.md
    * Push to GitHub
  - If no or gh not available:
    * Continue without GitHub integration
    * User can set up manually later

# KEY: No Task tool usage, no agent spawning
# This session BECOMES the vision gathering directly
```

---

## Vision Document Template

```markdown
# Project Vision: {Project Name}

**Created:** {ISO timestamp}
**Plan:** plan-{N}

---

## Problem Statement

{What problem this project solves}

**Current pain points:**
- {Pain point 1}
- {Pain point 2}
- {Pain point 3}

---

## Target Users

**Primary user:** {Description}
- {User characteristic 1}
- {User characteristic 2}

**Secondary users (if any):** {Description}

---

## Core Value Proposition

{One sentence: What makes this valuable}

**Key benefits:**
1. {Benefit 1}
2. {Benefit 2}
3. {Benefit 3}

---

## Feature Breakdown

### Must-Have (MVP)

1. **{Feature 1}**
   - Description: {What it does}
   - User story: As a {user}, I want to {action} so that {benefit}
   - Acceptance criteria:
     - [ ] {Criterion 1}
     - [ ] {Criterion 2}

2. **{Feature 2}**
   - Description: {What it does}
   - User story: As a {user}, I want to {action} so that {benefit}
   - Acceptance criteria:
     - [ ] {Criterion 1}
     - [ ] {Criterion 2}

[Continue for all must-have features]

### Should-Have (Post-MVP)

1. **{Feature}** - {Brief description}
2. **{Feature}** - {Brief description}

### Could-Have (Future)

1. **{Feature}** - {Brief description}
2. **{Feature}** - {Brief description}

---

## User Flows

### Flow 1: {Primary flow name}

**Steps:**
1. User {action}
2. System {response}
3. User {action}
4. System {response}

**Edge cases:**
- {Edge case 1}: {How handled}
- {Edge case 2}: {How handled}

**Error handling:**
- {Error scenario}: {User sees what}

[Repeat for all critical flows]

---

## Data Model Overview

**Key entities:**

1. **{Entity 1}**
   - Fields: {field1}, {field2}, {field3}
   - Relationships: {Related to X, Y}

2. **{Entity 2}**
   - Fields: {field1}, {field2}
   - Relationships: {Related to Z}

---

## Technical Requirements

**Must support:**
- {Requirement 1}
- {Requirement 2}
- {Requirement 3}

**Constraints:**
- {Constraint 1}
- {Constraint 2}

**Preferences:**
- {Preference 1 (e.g., "Use TypeScript")}
- {Preference 2 (e.g., "Deploy to Vercel")}

---

## Success Criteria

**The MVP is successful when:**

1. **{Measurable criterion 1}**
   - Metric: {How measured}
   - Target: {Specific number/state}

2. **{Measurable criterion 2}**
   - Metric: {How measured}
   - Target: {Specific number/state}

3. **{Measurable criterion 3}**
   - Metric: {How measured}
   - Target: {Specific number/state}

---

## Out of Scope

**Explicitly not included in MVP:**
- {Feature/aspect 1}
- {Feature/aspect 2}
- {Feature/aspect 3}

**Why:** {Brief rationale for scope decisions}

---

## Assumptions

1. {Assumption 1}
2. {Assumption 2}
3. {Assumption 3}

---

## Open Questions

1. {Question 1 that needs answering during planning/building}
2. {Question 2}

---

## Next Steps

- [ ] Review and refine this vision
- [ ] Run `/2l-plan` for interactive master planning
- [ ] OR run `/2l-mvp` to auto-plan and execute

---

**Vision Status:** VISIONED
**Ready for:** Master Planning
```
