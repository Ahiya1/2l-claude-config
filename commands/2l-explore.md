# 2L Explore - Reconnaissance Phase

Deploy explorer agents to analyze project requirements and gather intelligence for planning.

## Usage

```
/2l-explore
```

Reads requirements from your project and spawns 1-3 explorer agents based on complexity.

## What This Does

Creates `.2L/iteration-1/exploration/` and spawns explorers:

- **Explorer 1:** Architecture & structure analysis
- **Explorer 2:** Technology patterns & dependencies
- **Explorer 3:** Complexity & integration points (if needed)

## Requirements

Before running:
- Requirements document exists in project (REQUIREMENTS.md, README.md, etc.)
- You're in project root directory

## Output

Exploration reports in `.2L/iteration-1/exploration/`:
- `explorer-1-report.md`
- `explorer-2-report.md`
- `explorer-3-report.md` (if deployed)

## Next Step

After exploration completes, review the reports then run:
```
/2l-plan
```

---

Now let's explore the project requirements!

1. Check for iteration directory, create if needed:
```bash
mkdir -p .2L/iteration-1/exploration
```

2. Determine number of explorers needed based on project complexity

3. Use Task tool to spawn explorers in parallel with specific focus areas

4. Wait for all explorers to complete

5. Confirm all reports written to `.2L/iteration-1/exploration/`
