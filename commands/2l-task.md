# 2L Task - Lightweight Quick Fix Mode

Execute a streamlined 2L workflow for quick tasks and isolated fixes. Skip exploration and planning for clear, focused work.

## Usage

```
/2l-task "Add loading spinner to dashboard"
/2l-task "Fix TypeScript error in auth component"
/2l-task "Create utility function for date formatting"
```

---

## When to Use This

**Perfect for:**
- ✅ Clear, specific requirements (no exploration needed)
- ✅ Single file or small set of files
- ✅ Isolated changes (<1 hour of work)
- ✅ Bug fixes with known root cause
- ✅ Small enhancements to existing features

**NOT for:**
- ❌ Unknown problems (use `/2l-mvp` for exploration)
- ❌ Multi-feature builds (use `/2l-mvp` for planning)
- ❌ Complex integrations (use `/2l-mvp` for full protocol)

---

## Quick Assessment

Task description: $ARGUMENTS

Let me analyze what type of work this is:

### Determining Approach:

**Is this a fix or new code?**
- 🔧 **Fix/Debug:** Contains words like "fix", "bug", "error", "broken", "not working"
  → Spawn healer agent

- ✨ **New Code:** Contains words like "add", "create", "implement", "build"
  → Spawn builder agent

**Complexity check:**
- Simple (1-2 files, clear scope) → Single agent
- Medium (3-4 files, some integration) → Single agent + integration check
- Complex (5+ files, unclear scope) → Recommend `/2l-mvp` instead

---

## Task Execution

### Step 1: Create Task Directory

```bash
# Generate timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p .2L/tasks/task-${TIMESTAMP}
```

### Step 2: Document the Task

Write brief to: `.2L/tasks/task-${TIMESTAMP}/brief.md`

```markdown
# Task: $ARGUMENTS

## Type
FIX / NEW_CODE

## Timestamp
${TIMESTAMP}

## Context
- Related iteration: {if exists, reference latest iteration}
- Patterns to follow: {reference patterns.md if exists}
- MCP tools available: playwright, chrome-devtools, supabase-local, github, screenshot

## Scope
- Estimated files: {count}
- Estimated time: {minutes}
- Complexity: SIMPLE/MEDIUM

## Agent Assignment
Single {builder/healer} agent
```

### Step 3: Spawn Appropriate Agent

**If FIX (Healer Agent):**

```
Use Task tool with subagent_type: "2l-healer"

Prompt:
"You are a 2L Healer in Quick Task mode.

Task: $ARGUMENTS

Working directory: .2L/tasks/task-${TIMESTAMP}/

Your mission:
1. Identify the issue
2. Fix it with minimal changes
3. Verify the fix works
4. Create report

Available MCP tools:
- Chrome DevTools MCP: Debug in browser
- Playwright MCP: Test the fix
- Supabase MCP: Database debugging

Output report to: .2L/tasks/task-${TIMESTAMP}/healer-report.md

Follow patterns from existing codebase (check for patterns.md in latest iteration).

Focus: Quick, surgical fix. No refactoring unless necessary."
```

**If NEW_CODE (Builder Agent):**

```
Use Task tool with subagent_type: "2l-builder"

Prompt:
"You are a 2L Builder in Quick Task mode.

Task: $ARGUMENTS

Working directory: .2L/tasks/task-${TIMESTAMP}/

Your mission:
1. Build the requested feature/component
2. Follow existing code patterns
3. Write tests
4. Verify it works

Available MCP tools:
- Playwright MCP: Test in browser
- Chrome DevTools MCP: Verify functionality
- Supabase MCP: Database operations
- Screenshot MCP: Visual documentation

Output report to: .2L/tasks/task-${TIMESTAMP}/builder-report.md

Follow patterns from existing codebase (check for patterns.md in latest iteration).

Decision: You MUST COMPLETE (no splitting in task mode)."
```

**Wait for agent to complete.**

### Step 4: Quick Validation

After agent completes, run quick checks:

```bash
# TypeScript check (if TS project)
npx tsc --noEmit 2>&1 | tee .2L/tasks/task-${TIMESTAMP}/typescript-check.log

# Quick test (only affected files)
npm run test -- --findRelatedTests {affected_files} 2>&1 | tee .2L/tasks/task-${TIMESTAMP}/test-results.log

# Build check (quick)
npm run build 2>&1 | head -50 > .2L/tasks/task-${TIMESTAMP}/build-check.log
```

**Validation criteria (relaxed for quick tasks):**
- TypeScript: Zero errors in affected files
- Tests: Related tests passing
- Build: No critical errors

### Step 5: Self-Healing (If Needed)

**If validation FAILED:**

Check failure type:
- TypeScript errors? → Spawn quick healer for TS fixes
- Test failures? → Spawn quick healer for test fixes
- Build errors? → Spawn quick healer for build fixes

**Healing in task mode:**
```
Use Task tool with subagent_type: "2l-healer"

Prompt:
"You are a 2L Healer fixing validation issues from a quick task.

Original task: $ARGUMENTS

Issue: {TypeScript errors / Test failures / Build errors}

Working directory: .2L/tasks/task-${TIMESTAMP}/

Fix ONLY the validation issues. Minimal changes.

Output: .2L/tasks/task-${TIMESTAMP}/healer-fix-report.md"
```

**Re-validate after healing.**

**Healing limit in task mode: 1 attempt only**
- If still fails → Escalate to user

### Step 6: Create Task Summary

Write to: `.2L/tasks/task-${TIMESTAMP}/summary.md`

```markdown
# Task Summary

## Task
$ARGUMENTS

## Status
✅ COMPLETE / ⚠️ COMPLETE_WITH_WARNINGS / ❌ FAILED

## Agent Used
{Builder/Healer}

## Files Modified
- {file1} - {what changed}
- {file2} - {what changed}

## Validation Results
- TypeScript: ✅ PASS / ❌ FAIL
- Tests: ✅ PASS / ❌ FAIL
- Build: ✅ PASS / ❌ FAIL

## MCP Tools Used
- {List of MCP tools the agent used}

## Time
Started: {timestamp}
Completed: {timestamp}
Duration: {minutes}

## Notes
{Any important notes or warnings}

## Related
- Iteration: {if applicable}
- Pattern source: {if applicable}
```

---

## Progress Reporting

Throughout execution, I provide concise updates:

- "📋 Quick task mode: {FIX/NEW_CODE}"
- "🚀 Spawning {builder/healer} agent..."
- "⏳ Agent working..."
- "✅ Agent complete. Running validation..."
- "✅ Validation passed! Task complete."

OR

- "⚠️ Validation failed. Spawning healer..."
- "✅ Healing complete. Task done."

OR

- "❌ Healing failed. Manual intervention needed."

---

## Output Structure

```
.2L/tasks/task-20251002-143022/
├── brief.md                    # Task description & context
├── builder-report.md           # Agent's work (if builder)
├── healer-report.md           # Agent's work (if healer)
├── typescript-check.log        # Validation: TS results
├── test-results.log           # Validation: Test results
├── build-check.log            # Validation: Build results
├── healer-fix-report.md       # If healing was needed
└── summary.md                 # Final summary
```

---

## Context Management

**If I need to compact during task execution:**

Before compacting:
1. Ensure agent report is written
2. Save validation results
3. Instruct next session:

> /2l-continue is running…

The `/2l-continue` command will detect the interrupted task and resume it.

---

## Comparison: Task Mode vs Full Protocol

| Aspect | `/2l-task` | `/2l-mvp` |
|--------|-----------|-----------|
| **Phases** | 2 (Execute + Validate) | 6 (Explore → Plan → Build → Integrate → Validate → Heal) |
| **Agents** | 1-2 | 10+ |
| **Time** | 15-60 min | 3-8 hours |
| **Use Case** | Single clear task | Complex feature/unknown problem |
| **Exploration** | Skip | 2-3 explorers |
| **Planning** | Skip (use existing patterns) | Dedicated planner |
| **Integration** | Quick check only | Dedicated integrator |
| **Validation** | Quick (affected files only) | Full suite |
| **Healing** | 1 attempt | 2 iterations |
| **Output** | `.2L/tasks/` | `.2L/iteration-N/` |

---

## Examples

### Example 1: Bug Fix
```
/2l-task "Fix dashboard 404 error when navigating to /transactions"

→ Determines: FIX
→ Spawns: Healer agent
→ Healer: Identifies routing issue, fixes route definition
→ Validates: TypeScript ✅, Tests ✅, Build ✅
→ Result: COMPLETE in 12 minutes
```

### Example 2: New Feature
```
/2l-task "Add loading spinner to dashboard page"

→ Determines: NEW_CODE
→ Spawns: Builder agent
→ Builder: Creates LoadingSpinner component, adds to dashboard
→ Validates: TypeScript ✅, Tests ✅, Build ✅
→ Result: COMPLETE in 18 minutes
```

### Example 3: With Healing
```
/2l-task "Create utility function for date formatting"

→ Determines: NEW_CODE
→ Spawns: Builder agent
→ Builder: Creates utils/dateFormat.ts
→ Validates: TypeScript ❌ (missing export)
→ Spawns: Healer (quick fix)
→ Healer: Adds export, updates imports
→ Re-validates: TypeScript ✅
→ Result: COMPLETE in 22 minutes
```

---

## Commit Integration (Mission 3)

**If validation passes, task commits automatically:**

```bash
# After successful validation
if [ "$VALIDATION_STATUS" = "PASS" ]; then
    echo "💾 Auto-committing task..."

    # Determine context
    CURRENT_PLAN=$(yq eval '.current_plan' .2L/config.yaml 2>/dev/null || echo "none")
    CURRENT_ITER=$(yq eval '.global_iteration_counter' .2L/config.yaml 2>/dev/null || echo "0")

    # Stage all changes
    git add .

    # Create commit with task context
    COMMIT_MSG=$(cat <<EOF
Task: ${TASK_DESCRIPTION}

During: plan-${CURRENT_PLAN}, iteration-${CURRENT_ITER}
Type: ${TASK_TYPE}
Status: PASS

Files modified:
${FILES_MODIFIED}

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
    )

    git commit -m "${COMMIT_MSG}"

    if [ $? -eq 0 ]; then
        COMMIT_HASH=$(git rev-parse HEAD)
        echo "✅ Task committed: ${COMMIT_HASH:0:8}"

        # Update task summary with commit info
        echo "" >> .2L/tasks/task-${TIMESTAMP}/summary.md
        echo "## Git Commit" >> .2L/tasks/task-${TIMESTAMP}/summary.md
        echo "" >> .2L/tasks/task-${TIMESTAMP}/summary.md
        echo "Commit: ${COMMIT_HASH}" >> .2L/tasks/task-${TIMESTAMP}/summary.md
        echo "Message: Task: ${TASK_DESCRIPTION}" >> .2L/tasks/task-${TIMESTAMP}/summary.md
    else
        echo "⚠️  Commit failed (but task succeeded)"
    fi
fi
```

**Tasks roll back naturally with iteration rollback:**

When you rollback an iteration, task commits go with it:

```bash
# Created tasks during iteration 3
/2l-task "Add feature X"  # Committed
/2l-task "Fix bug Y"      # Committed

# Later, rollback to iteration 2
/2l-rollback 2

# Task commits are reverted along with iteration
# All work preserved in git history
```

**Manual task commit:**

```bash
# If you want to commit a task manually
cd .2L/tasks/task-20251002-143022
git add .
git commit -m "Manual commit: ${reason}"
```

---

## Error Handling

**If task is too complex:**
```
⚠️ This task appears complex (5+ files, unclear scope).

Recommendation: Use `/2l-mvp` instead for:
- Proper exploration
- Comprehensive planning
- Parallel builders
- Full integration & validation

Proceed with `/2l-task` anyway? (Higher chance of issues)
```

**If validation fails after healing:**
```
❌ Task validation failed after healing attempt.

Issues:
- {List of remaining problems}

Recommendation:
1. Review task output: .2L/tasks/task-${TIMESTAMP}/
2. Either:
   - Fix manually
   - Re-run with `/2l-task` (fresh attempt)
   - Escalate to `/2l-mvp` (if more complex than expected)
```

**If git commit fails:**
```
⚠️  Task completed but auto-commit failed.

Task output: .2L/tasks/task-${TIMESTAMP}/
Status: COMPLETE

Commit manually:
  cd .2L/tasks/task-${TIMESTAMP}
  git add .
  git commit -m "Task: ${DESCRIPTION}"
```

---

Now executing quick task mode for: "$ARGUMENTS"

Analyzing task type and spawning appropriate agent...
