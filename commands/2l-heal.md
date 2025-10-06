# 2L Heal - Issue Resolution Phase

Fix validation failures with specialized healer agents. Max 2 healing iterations before escalation.

## Usage

```
/2l-heal
```

## Requirements

Must have validation FAIL:
- `.2L/iteration-1/validation/validation-report.md` must exist with FAIL status

## What This Does

1. Reads validation report
2. Categorizes issues by type (TypeScript, tests, linting, build, logic, etc.)
3. Spawns 1-3 healer agents (one per issue category) in parallel
4. Each healer fixes their assigned category
5. Spawns mini-integrator to merge healer fixes
6. Spawns validator again to re-check
7. Reports PASS or FAIL

## Issue Categories

Common categories:
- **TypeScript errors** - Type issues, missing types
- **Test failures** - Failing unit or integration tests
- **Linting issues** - Code style violations
- **Build errors** - Compilation or bundling failures
- **Logic bugs** - Incorrect behavior
- **Integration problems** - Component connection issues

## Healing Iterations

- **Iteration 1:** First attempt to fix issues
- **Iteration 2:** Second attempt if iteration 1 didn't fully succeed
- **After iteration 2:** Escalate to human if still failing

## Output

Healing directory created for each iteration:

**Iteration 1:**
```
.2L/iteration-1/healing-1/
├── healer-1-report.md  (TypeScript fixes)
├── healer-2-report.md  (Test fixes)
├── healer-3-report.md  (Build fixes)
├── integration-report.md
└── validation-report.md
```

**Iteration 2 (if needed):**
```
.2L/iteration-1/healing-2/
└── ...
```

## Duration

- **Per healing iteration:** 30-60 minutes

## Next Steps

**If healing PASS:**
- 🎉 MVP complete!
- Issues resolved
- Ready for deployment

**If healing FAIL after iteration 1:**
- Automatically starts iteration 2

**If healing FAIL after iteration 2:**
- ⚠️ Escalate to human
- Manual intervention required
- Review validation report for remaining issues

---

Now let's heal!

1. Read validation report:
```bash
cat .2L/iteration-1/validation/validation-report.md
```

2. Check current healing iteration:
```bash
ls .2L/iteration-1/healing-* 2>/dev/null | wc -l
```

3. Verify we haven't exceeded 2 iterations

4. Determine next iteration number (1 or 2)

5. Create healing directory:
```bash
mkdir -p .2L/iteration-1/healing-{N}
```

6. Analyze validation report and categorize issues

7. Determine number of healers needed (1-3 based on issue categories)

8. Use Task tool to spawn healer agents in parallel, each with specific category

9. Wait for all healers to complete

10. Spawn mini-integrator to merge healer fixes

11. Spawn validator to re-check

12. Read new validation report

13. Check status:
    - If PASS: Report success!
    - If FAIL and iteration < 2: Report "Starting healing iteration 2..."
    - If FAIL and iteration = 2: Escalate to user with issue summary

---

**Healing Strategy:**

The system learns from iteration 1 failures to improve iteration 2 approach.

**Escalation includes:**
- Summary of all issues attempted
- What was fixed
- What remains broken
- Suggestions for manual intervention
