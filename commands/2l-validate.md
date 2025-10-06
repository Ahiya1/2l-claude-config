# 2L Validate - Quality Verification Phase

Run comprehensive validation on integrated codebase to verify production readiness.

## Usage

```
/2l-validate
```

## Requirements

Must have completed integration phase:
- `.2L/iteration-1/integration/integration-report.md` must exist
- Integrated codebase should be in working state

## What This Does

Spawns the **2l-validator** agent who will:
1. Run TypeScript compilation check
2. Run linting
3. Run code formatting check
4. Run unit tests
5. Run integration tests
6. Run build process
7. Verify success criteria from plan
8. Assess code quality
9. Create validation report with PASS or FAIL status

## Output

Validation report at `.2L/iteration-1/validation/validation-report.md`

Status will be **PASS** or **FAIL**

## Validation Checks

- ✅ TypeScript compiles with no errors
- ✅ Linting passes
- ✅ Code formatting correct
- ✅ All tests passing (>80% coverage)
- ✅ Build succeeds
- ✅ Development server starts
- ✅ Success criteria met
- ✅ Code quality acceptable

## Duration

- **Typical validation:** 10-20 minutes

## Next Steps

**If validation PASS:**
- 🎉 MVP complete!
- Review the application
- Deploy if ready

**If validation FAIL:**
```
/2l-heal
```

---

Now let's validate!

1. Verify integration completed:
```bash
ls .2L/iteration-1/integration/integration-report.md
```

2. Create validation directory:
```bash
mkdir -p .2L/iteration-1/validation
```

3. Use Task tool to spawn 2l-validator agent

4. Wait for validator to complete

5. Read validation report: `.2L/iteration-1/validation/validation-report.md`

6. Check status: PASS or FAIL

7. Report result to user with next steps
