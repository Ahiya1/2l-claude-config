# 2L Build - Parallel Implementation Phase

Deploy builder agents to implement features according to plan. Automatically handles builder splits.

## Usage

```
/2l-build
```

## Requirements

Must have completed planning phase:
- `.2L/iteration-1/plan/*.md` files must exist

## What This Does

1. Reads `plan/builder-tasks.md` to identify all builder tasks
2. Spawns all builders in parallel using Task tool
3. Waits for all builders to complete
4. Checks each builder report for COMPLETE or SPLIT status
5. **If any builder SPLIT:** Handles splits sequentially:
   - Spawns sub-builders for Builder-1 (if split) → waits
   - Spawns sub-builders for Builder-2 (if split) → waits
   - Continues until all splits resolved

## Output

Builder reports in `.2L/iteration-1/building/`:
- `builder-1-report.md`
- `builder-1A-report.md` (if Builder-1 split)
- `builder-1B-report.md` (if Builder-1 split)
- `builder-2-report.md`
- etc.

## Split Handling

**Builders can decide to SPLIT if task is too complex:**
- Builder creates foundation code
- Reports SPLIT with subtask breakdown
- This command automatically spawns sub-builders
- Sub-builders MUST complete (no further splitting)

**Split handling is SEQUENTIAL:**
- All primary builders finish first
- Then handle Builder-1 splits
- Then handle Builder-2 splits
- Continue until all done

## Duration

- **No splits:** 1-3 hours (parallel execution)
- **With splits:** 2-4 hours (sequential sub-builder phases)

## Next Step

After all builders complete:
```
/2l-integrate
```

---

Now let's build!

1. Verify plan exists:
```bash
ls .2L/iteration-1/plan/builder-tasks.md
```

2. Create building directory:
```bash
mkdir -p .2L/iteration-1/building
```

3. Read plan/builder-tasks.md to identify all builder tasks

4. Use Task tool to spawn all primary builders in parallel

5. Wait for all builders to complete

6. Read all builder reports from `.2L/iteration-1/building/`

7. Check for SPLIT decisions

8. If any SPLIT found:
   - For each builder that split (in order):
     - Read subtask breakdown from builder report
     - Spawn sub-builders in parallel
     - Wait for sub-builders to complete
     - Verify sub-builder reports written

9. Confirm all builders (including sub-builders) have completed
