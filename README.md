# 2L - Two-Level Orchestration System

2L is an AI agent orchestration system that breaks down complex development tasks into manageable iterations executed by specialized agents. It provides real-time observability through an event system and dashboard, enabling you to monitor agent progress, track phases, and debug orchestrations.

## Overview & Quick Start

### What is 2L?

2L (Two-Level) orchestrates AI agents to build software projects by:
- Breaking your vision into iterations
- Spawning specialized agents (explorers, planners, builders, integrators, validators)
- Coordinating their work through a structured workflow
- Tracking everything via events for real-time monitoring
- Committing results to git and optionally pushing to GitHub

**Target audience:** Developers who want to build MVPs, prototypes, or complete features using AI agents with full visibility into the orchestration process.

### Core Workflow

```bash
# Option 1: Interactive requirements gathering
/2l-vision

# Option 2: Full autonomy mode (recommended for quick starts)
/2l-mvp "Build a todo app with React and Supabase"
```

The `/2l-mvp` command will:
1. Break your vision into iterations (based on complexity)
2. For each iteration:
   - **Exploration phase:** Explorers analyze requirements and codebase
   - **Planning phase:** Planner creates detailed implementation plan
   - **Building phase:** Builders implement features (with potential sub-builders if complex)
   - **Integration phase:** Integrator merges all builder work
   - **Validation phase:** Validator tests everything
   - **Healing phase:** If validation fails, healer fixes issues
3. Commit completed work to git
4. Push to GitHub (if `gh` CLI configured)
5. Emit events throughout for real-time monitoring

### Quick Example

```bash
# Navigate to your project directory
cd ~/projects/my-app

# Start orchestration
/2l-mvp "Create a REST API with authentication and user management"

# Open dashboard in another terminal to watch progress
/2l-dashboard
```

The dashboard will show:
- Real-time event timeline
- Active agents and their progress
- Current phase and metrics
- All events color-coded by type

---

## Event System Architecture

### Why Events?

The 2L event system provides:
- **Observability:** See exactly what each agent is doing in real-time
- **Debugging:** Trace problems back to specific agents and phases
- **Non-blocking:** Events don't slow down orchestration
- **Historical record:** Full audit trail of orchestration decisions

### Event Flow

```
┌─────────────────┐
│  Orchestrator   │ (28 emission points)
└────────┬────────┘
         │
         ├─> plan_start
         ├─> iteration_start
         ├─> phase_change (exploration → planning → building → ...)
         ├─> agent_start/agent_complete (spawns agents)
         ├─> validation_result
         └─> iteration_complete
         │
         ▼
   .2L/events.jsonl (JSONL format)
         │
         ▲
         │
┌────────┴────────┐
│     Agents      │ (All 10 agent types)
└─────────────────┘
         │
         ├─> agent_start (before work begins)
         └─> agent_complete (after work finishes)

         │
         ▼
   Dashboard polls events.jsonl every 2 seconds
         │
         ▼
   Real-time display in browser
```

### 8 Event Types

All events in 2L use one of these standardized types:

1. **plan_start** - Orchestration begins for a plan
   - Emitted when: `/2l-mvp` starts execution
   - Contains: Plan ID, mode (MASTER/AUTO), project name

2. **iteration_start** - New iteration begins
   - Emitted when: Starting iteration N
   - Contains: Iteration number, goals, estimated complexity

3. **phase_change** - Phase transition occurs
   - Emitted when: Moving between phases (exploration → planning → building → integration → validation → completion)
   - Contains: Previous phase, new phase, reason

4. **complexity_decision** - Builder makes COMPLETE or SPLIT decision
   - Emitted when: Builder assesses task complexity
   - Contains: Builder ID, decision (COMPLETE/SPLIT), reasoning

5. **agent_start** - Agent begins work
   - Emitted when: Any agent starts processing (explorer, planner, builder, integrator, validator)
   - Contains: Agent ID, agent type, task description

6. **agent_complete** - Agent finishes work
   - Emitted when: Agent completes task and writes report
   - Contains: Agent ID, status (COMPLETE/SPLIT/PASS/FAIL), duration

7. **validation_result** - Validation outcome
   - Emitted when: Validator completes testing
   - Contains: PASS/FAIL status, confidence level, issues found

8. **iteration_complete** - Iteration finishes
   - Emitted when: All validation passed and iteration committed
   - Contains: Iteration number, duration, files changed, git tag

### Event Format Schema

All events follow this JSON schema:

```json
{
  "timestamp": "2025-10-08T18:00:00Z",
  "event_type": "plan_start",
  "phase": "initialization",
  "agent_id": "orchestrator",
  "data": "Plan test-plan started in MASTER mode"
}
```

**Required fields:**
- `timestamp` - ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ)
- `event_type` - One of 8 types listed above
- `phase` - Current orchestration phase
- `agent_id` - Identifier for event source (orchestrator, explorer-1, builder-2, etc.)
- `data` - Event-specific information (string)

### Event File Location

Events are written to `.2L/events.jsonl` in the project root.

**JSONL format:** One JSON object per line, no commas between objects. This allows:
- Append-only writes (no file locking required)
- Streaming parsing (read line by line without loading entire file)
- Human-readable debugging (each line is valid JSON)

Example `.2L/events.jsonl`:
```jsonl
{"timestamp": "2025-10-08T18:00:00Z", "event_type": "plan_start", "phase": "initialization", "agent_id": "orchestrator", "data": "Plan test-plan started in MASTER mode"}
{"timestamp": "2025-10-08T18:00:15Z", "event_type": "phase_change", "phase": "exploration", "agent_id": "orchestrator", "data": "Transitioning from initialization to exploration"}
{"timestamp": "2025-10-08T18:00:20Z", "event_type": "agent_start", "phase": "exploration", "agent_id": "explorer-1", "data": "Explorer-1: Analyzing project requirements"}
```

### Emission Points

**Orchestrator emissions:** 28 documented `log_2l_event` calls throughout `/2l-mvp` orchestration:
- Lifecycle events: plan_start, iteration_start, iteration_complete (3 emissions)
- Phase transitions: phase_change for each phase entry (7+ emissions)
- Agent spawning: agent_start/agent_complete tracking for each agent spawned (variable)
- Validation: validation_result after validator runs (1 emission)
- Error handling: Events for failures and healing attempts (variable)

**Agent emissions:** All 10 agent types emit exactly 2 events:
- `agent_start` - After reading context, before beginning work
- `agent_complete` - After completing work, before writing final report

**Total events per orchestration:** 28 (orchestrator) + (2 × number of agents spawned)

For a typical 2-iteration plan with 5 agents per iteration:
- Orchestrator: 28 events
- Agents: 2 × 10 agents = 20 events
- **Total: ~48 events**

### Graceful Degradation

All event emission is optional and non-blocking:
- If event logger library is missing, agents continue normally
- All emissions wrapped in conditional checks: `if [ -f "$HOME/.claude/lib/2l-event-logger.sh" ]; then ... fi`
- Orchestration never fails due to event issues
- Missing events simply means reduced observability

---

## Dashboard Access

### Starting the Dashboard

Use the `/2l-dashboard` command to start the dashboard server:

```bash
/2l-dashboard
```

**What happens:**
1. Checks if dashboard HTML exists (spawns builder to generate if missing)
2. Checks if server already running for this project (reuses port if so)
3. Finds available port in range 8080-8099
4. Starts Python 3 HTTP server bound to localhost (127.0.0.1)
5. Opens browser automatically to `http://localhost:{port}/dashboard/index.html`

**Expected output:**
```
✓ Dashboard server started

  URL: http://localhost:8080/dashboard/index.html
  Port: 8080
  PID: 123456

The dashboard will auto-refresh every 2 seconds to show:
  - Real-time event timeline
  - Active agents and their progress
  - Orchestration metrics

To stop the server: /2l-dashboard-stop

Opening browser...
```

### Why HTTP Server?

**Browser security restriction:** Modern browsers block `file://` protocol from fetching local files (CORS policy). The dashboard needs to fetch `.2L/events.jsonl` every 2 seconds to display real-time events.

**Solution:** Python HTTP server serves both:
- Dashboard HTML: `.2L/dashboard/index.html`
- Events file: `.2L/events.jsonl`

Both accessible from same origin (localhost), satisfying CORS requirements.

**Security:** Server binds only to 127.0.0.1 (localhost), not accessible from network.

### Port Allocation

**Dynamic allocation:** Dashboard finds first available port in range 8080-8099.

**Port reuse:** On subsequent `/2l-dashboard` runs:
1. Checks `.2L/dashboard/.server-port` for previously used port
2. Checks `.2L/dashboard/.server-pid` for server process ID
3. Verifies process still running: `ps -p $PID`
4. Reuses same port if server active
5. Opens browser to existing server

**Port exhaustion:** If all 20 ports (8080-8099) occupied:
```
Error: All dashboard ports (8080-8099) are in use

You have 20 concurrent dashboard servers running!

To free a port, navigate to another project and run:
  /2l-dashboard-stop

Or manually check ports:
  lsof -i :8080-8099
```

### Multi-Project Support

**Each project gets unique port:**
- State files stored in project-specific `.2L/dashboard/` directory
- `.server-port` - Stores allocated port (e.g., "8080")
- `.server-pid` - Stores server process ID (e.g., "123456")

**20 concurrent dashboards supported:**
- Port range 8080-8099 = 20 ports
- Each project occupies one port
- Work on 20 different projects simultaneously with separate dashboards

**Example:**
```bash
# Project A
cd ~/projects/app-a
/2l-dashboard  # Uses port 8080

# Project B
cd ~/projects/app-b
/2l-dashboard  # Uses port 8081

# Both dashboards running independently
```

### Stopping the Dashboard

Use `/2l-dashboard-stop` to stop the server:

```bash
/2l-dashboard-stop
```

**What happens:**
1. Reads `.2L/dashboard/.server-pid` to get process ID
2. Verifies process ownership (security check)
3. Kills server process: `kill -TERM $PID`
4. Removes state files: `.server-pid` and `.server-port`

**Expected output:**
```
✓ Dashboard server stopped (port 8080, PID 123456)
```

**Port cleanup:** Port becomes immediately available for other projects.

### Dashboard Features

The dashboard displays:

1. **Real-time event timeline** (polls `.2L/events.jsonl` every 2 seconds)
   - Shows last 50 events
   - Color-coded by event type
   - Timestamps with relative time
   - Expandable event data

2. **Active agent tracking**
   - Lists all agents currently working
   - Shows duration since agent_start
   - Updates in real-time as agents complete

3. **Orchestration metrics**
   - Total elapsed time
   - Total events emitted
   - Number of active agents
   - Current phase

4. **Phase visualization**
   - Progress bar showing: exploration → planning → building → integration → validation
   - Highlights current phase
   - Shows completed phases

5. **Last 50 events display**
   - Scrollable event list
   - Color coding:
     - Blue: plan_start, iteration_start
     - Green: agent_complete, validation_result (PASS)
     - Orange: phase_change, complexity_decision
     - Red: validation_result (FAIL)
     - Gray: agent_start, iteration_complete

**Auto-refresh:** Dashboard polls events.jsonl every 2 seconds. No manual refresh needed.

---

## MCP Integration

### What are MCPs?

**Model Context Protocol (MCP)** servers extend Claude's capabilities by providing tools for specific tasks like browser automation, database queries, or performance profiling.

**IMPORTANT: ALL MCPs ARE OPTIONAL.** 2L core functionality works perfectly without any MCPs installed. They only enhance what agents can do during building phases.

### 4 Available MCPs

#### 1. Playwright MCP (Browser Automation)

**When to use:** Testing frontend features, automating user flows

**Capabilities:**
- Navigate to URLs
- Fill forms and click elements
- Execute JavaScript in browser
- Get page content via accessibility tree (no screenshots needed)
- Wait for elements and page loads

**What it enables for agents:**
- Test frontend components (buttons, forms, navigation)
- Verify user flows work end-to-end
- Check form submissions
- Validate navigation between pages

**Setup:** https://github.com/executeautomation/playwright-mcp-server

**Status:** ⚠️ Optional - 2L works without this MCP

---

#### 2. Chrome DevTools MCP (Performance & Debugging)

**When to use:** Frontend work, performance optimization, debugging

**Capabilities:**
- Record performance traces
- Analyze network requests
- Capture console messages
- CPU/network emulation
- Take screenshots
- Execute JavaScript

**What it enables for agents:**
- Profile component render performance
- Check for console errors
- Verify API calls in network tab
- Test under slow network/CPU conditions

**Setup:** https://github.com/MCP-Servers/chrome-devtools

**Status:** ⚠️ Optional - 2L works without this MCP

---

#### 3. Supabase Local MCP (Database Validation)

**When to use:** Backend features, database schema, data operations

**Capabilities:**
- Execute SQL queries
- Create tables and schemas
- Manage migrations
- Seed test data
- Query for testing

**Prerequisites:**
```bash
# Database already running on port 5432
# Connection: postgresql://postgres:postgres@127.0.0.1:5432/postgres
```

**What it enables for agents:**
- Verify database schemas
- Test SQL queries
- Seed test data
- Validate migrations

**Setup:** https://github.com/MCP-Servers/supabase-local

**Status:** ⚠️ Optional - 2L works without this MCP

---

#### 4. Screenshot MCP (Visual Capture)

**When to use:** Visual documentation, screenshot-based verification

**Capabilities:**
- Capture screen regions
- Save images to disk
- Visual documentation

**What it enables for agents:**
- Visual documentation during orchestration
- Screenshot-based verification
- Build artifacts with images

**Setup:** https://github.com/MCP-Servers/screenshot

**Status:** ⚠️ Optional - 2L works without this MCP

---

### MCP Setup Instructions

To configure MCPs in Claude Desktop:

1. **Open Claude Desktop settings**
2. **Locate configuration file:**
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Linux: `~/.config/Claude/claude_desktop_config.json`
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`

3. **Edit configuration file** to add MCP servers:
   ```json
   {
     "mcpServers": {
       "playwright": {
         "command": "node",
         "args": ["/path/to/playwright-mcp-server/index.js"]
       },
       "chrome-devtools": {
         "command": "node",
         "args": ["/path/to/chrome-devtools-mcp/index.js"]
       }
     }
   }
   ```

4. **Restart Claude Desktop** to activate MCPs

5. **Verify** by using the MCP during orchestration (agents will report availability)

### Checking MCP Status

Use the `/2l-check-mcps` command for a quick reference:

```bash
/2l-check-mcps
```

This displays:
- All 4 MCPs with descriptions
- Setup links to official repositories
- What each MCP enables
- Reminder that all are optional

**Note:** Cannot technically verify MCP connection status (Claude doesn't expose MCP API). The command provides informational guidance only.

### MCP Graceful Degradation

If an MCP is unavailable during orchestration:
- Agents detect unavailability and continue without it
- Builder reports include "MCP Testing Performed" or "Limitations" section
- Provides recommendations for manual testing
- **Orchestration never fails due to missing MCPs**

---

## GitHub Integration

### Why `gh` CLI?

2L uses the GitHub CLI (`gh`) for GitHub integration instead of GitHub MCP because:

1. **Reliability:** Direct CLI is more stable than managing MCP server processes
2. **Simplicity:** Standard tool with consistent behavior across platforms
3. **Authentication:** Leverages existing `gh auth login` workflow (secure, tested)
4. **Graceful degradation:** Works offline or without GitHub - shows clear warnings
5. **Consistency:** Same behavior whether using MCP or CLI environments

### GitHub CLI Setup

#### Step 1: Install GitHub CLI

**Ubuntu/Debian:**
```bash
sudo apt install gh
```

**macOS:**
```bash
brew install gh
```

**Windows or alternative:**
Download from https://cli.github.com/

**Verify installation:**
```bash
gh --version
# Expected: gh version 2.x.x (or higher)
```

#### Step 2: Authenticate

```bash
gh auth login
```

**Follow prompts:**
```
? What account do you want to log into? GitHub.com
? What is your preferred protocol for Git operations? HTTPS
? Authenticate Git with your GitHub credentials? Yes
? How would you like to authenticate GitHub CLI? Login with a web browser
```

Browser will open for authentication. After authorizing, return to terminal.

#### Step 3: Verify Authentication

```bash
gh auth status
```

**Expected output:**
```
github.com
  ✓ Logged in to github.com as username
  ✓ Git operations for github.com configured to use https protocol.
  ✓ Token: *******************
```

### What Gets Pushed Automatically

When you run `/2l-mvp`, the orchestrator automatically:

1. **Creates GitHub repository:**
   - Uses project directory name as repo name (e.g., `my-app` → `my-app` repo)
   - Public repository by default
   - Description: First line from `vision.md` (truncated to 100 chars)
   - Command: `gh repo create {name} --public --source=. --remote=origin`

2. **Pushes commits after each iteration:**
   - Commits created after validation passes
   - Format:
     ```
     feat: Iteration {N} - {description}

     {Detailed changes}
     - Feature 1
     - Feature 2

     🤖 Generated with 2L
     ```

3. **Pushes git tags:**
   - Tag format: `2l-plan-{X}-iter-{Y}`
   - Example: `2l-plan-1-iter-2` (Plan 1, Iteration 2)
   - Tags pushed to remote: `git push origin {tag}`

### Graceful Degradation

If GitHub CLI is not available, 2L continues with local git only:

**If `gh` CLI not installed:**
```
⚠️  GitHub CLI (gh) not installed - skipping GitHub integration
   Install: https://cli.github.com/
```

**If not authenticated:**
```
⚠️  GitHub CLI not authenticated - skipping GitHub integration
   Run: gh auth login
```

**If repository creation fails:**
```
⚠️  Failed to create GitHub repo: {error message}
```

**Orchestration continues normally** - all work committed to local git. Push manually later:
```bash
gh auth login
git push origin main
git push origin --tags
```

### Troubleshooting GitHub Integration

#### Issue 1: "gh not found"

**Solution:** Install GitHub CLI (see setup above)

#### Issue 2: "gh not authenticated"

**Solution:**
```bash
gh auth login
# Follow authentication prompts
```

#### Issue 3: "Failed to create repo"

**Check 1:** Network connection
```bash
ping github.com
```

**Check 2:** Authentication still valid
```bash
gh auth status
```

**Check 3:** Account has repo creation permissions
- Free GitHub accounts have unlimited public repos
- Check if you've hit any limits

**Solution:** Re-authenticate if needed
```bash
gh auth logout
gh auth login
```

#### Issue 4: "Push failed"

**Check 1:** Remote exists
```bash
git remote -v
# Should show: origin  https://github.com/username/repo.git
```

**Check 2:** Branch exists on remote
```bash
git branch -r
```

**Solution:** Retry push manually
```bash
git push origin main
git push origin --tags
```

---

## Setup Verification

### Prerequisites Checklist

Before running your first orchestration, verify:

- [ ] **Python 3 installed** (for dashboard HTTP server)
  ```bash
  python3 --version
  # Expected: Python 3.x.x
  ```

- [ ] **Git installed** (for version control)
  ```bash
  git --version
  # Expected: git version 2.x.x
  ```

- [ ] **gh CLI installed and authenticated** (optional, for GitHub integration)
  ```bash
  gh auth status
  # Expected: ✓ Logged in to github.com
  ```

- [ ] **Claude Desktop with 2L commands** configured
  - Commands in `~/.claude/commands/`
  - Agents in `~/.claude/agents/`

### Verification Steps

#### Step 1: Check MCP Status (Optional)

```bash
/2l-check-mcps
```

**Expected output:**
```
🔍 2L MCP Connection Status

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MCP Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 All MCPs are OPTIONAL - 2L works without them!

1. Playwright MCP (Browser Automation)
   Status: ⚠️  Optional
   ...
```

**Remember:** All MCPs optional. If unavailable, continue to next step.

#### Step 2: Check GitHub CLI (Optional)

```bash
gh auth status
```

**Expected output:**
```
github.com
  ✓ Logged in to github.com as username
```

**If not authenticated:**
```bash
gh auth login
# Follow prompts
```

**Remember:** GitHub integration optional. If unavailable, continue to next step.

#### Step 3: Test Orchestration

```bash
# Navigate to test project directory
mkdir -p ~/test-2l
cd ~/test-2l

# Run simple orchestration
/2l-mvp "Create a simple hello world app"
```

**Expected behavior:**
- `.2L/` directory created
- `events.jsonl` file populated with events
- Agents spawn and complete work
- Git commit created

**Verify:**
```bash
# Check .2L directory
ls -la .2L/
# Expected: config.yaml, events.jsonl, plan-1/

# Check events file
cat .2L/events.jsonl | head -5
# Expected: JSON objects, one per line

# Check git commit
git log --oneline -1
# Expected: Commit message starting with "feat: Iteration"
```

#### Step 4: Open Dashboard

```bash
/2l-dashboard
```

**Expected behavior:**
- Server starts on port 8080-8099
- Browser opens automatically
- Dashboard displays events from `.2L/events.jsonl`
- Real-time updates every 2 seconds

**Verify in browser:**
- See event timeline
- See orchestration metrics
- Events update in real-time (run another `/2l-mvp` in another terminal to see live updates)

**Stop dashboard when done:**
```bash
/2l-dashboard-stop
```

### Success Criteria

Setup is complete when:
- [x] Test orchestration runs without errors
- [x] Events appear in `.2L/events.jsonl`
- [x] Dashboard displays events correctly
- [x] Git commits created successfully
- [x] (Optional) GitHub push succeeds (if `gh` CLI configured)

---

## Troubleshooting

### Issue 1: Dashboard Shows No Events

**Symptom:** Dashboard opens but timeline is empty

**Check 1:** Does `.2L/events.jsonl` exist?
```bash
ls -la .2L/events.jsonl
```

**If file missing:** No events have been generated yet
```bash
# Solution: Run an orchestration to generate events
/2l-mvp "Simple test task"
```

**If file exists but empty:** Check file permissions
```bash
cat .2L/events.jsonl
# Should show JSON objects
```

**Cause:** Dashboard polls events.jsonl every 2 seconds. If file doesn't exist or is empty, timeline will be blank.

---

### Issue 2: MCP Connection Issues

**Symptom:** Agent mentions "MCP not available" in report

**Check 1:** MCPs configured in `claude_desktop_config.json`
```bash
# macOS
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json

# Linux
cat ~/.config/Claude/claude_desktop_config.json
```

**Verify:** JSON contains `"mcpServers"` section with MCP configurations

**Solution 1:** Add MCP configuration if missing (see [MCP Integration](#mcp-integration))

**Solution 2:** Restart Claude Desktop after config changes
- Quit Claude Desktop completely
- Reopen Claude Desktop
- MCPs will be loaded on startup

**Solution 3:** Check MCP status
```bash
/2l-check-mcps
# See setup links for each MCP
```

**Remember:** All MCPs are optional - 2L works without them! If MCP unavailable, agents continue with manual testing recommendations.

---

### Issue 3: GitHub Push Failures

**Symptom:** "Failed to push to GitHub" error during orchestration

**Check 1:** `gh` CLI authenticated
```bash
gh auth status
```

**Expected output:**
```
✓ Logged in to github.com as username
```

**If not authenticated:**
```bash
gh auth login
# Follow authentication prompts
```

**Check 2:** Network connection
```bash
ping github.com
# Should receive responses
```

**Check 3:** Remote exists
```bash
git remote -v
# Should show: origin  https://github.com/username/repo.git
```

**If remote missing:** Create manually
```bash
gh repo create my-repo --public --source=. --remote=origin
```

**Solution:** Retry push manually
```bash
git push origin main
git push origin --tags
```

**Remember:** GitHub integration is optional - 2L works with local git only. Push when connection available.

---

### Issue 4: Port Conflicts (Dashboard)

**Symptom:** "All dashboard ports (8080-8099) are in use"

**Check 1:** Which ports are occupied
```bash
lsof -i :8080-8099
```

**Expected output:**
```
COMMAND    PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
python3  12345  user   3u  IPv4  ...      TCP localhost:8080 (LISTEN)
python3  12346  user   3u  IPv4  ...      TCP localhost:8081 (LISTEN)
...
```

**Solution:** Stop a dashboard in another project
```bash
# Navigate to other project
cd /path/to/other/project

# Stop dashboard
/2l-dashboard-stop
```

**Alternative:** Manually kill server processes
```bash
# Kill specific port
kill $(lsof -t -i:8080)

# Or kill all Python http.server processes
pkill -f "python3 -m http.server"
```

**Cause:** 20 concurrent dashboards already running (8080-8099 = 20 ports). Maximum reached.

---

### Issue 5: Agent Doesn't Emit Events

**Symptom:** Some agents don't appear in dashboard

**Check 1:** Event logger library exists
```bash
ls -la ~/.claude/lib/2l-event-logger.sh
```

**If missing:** Event emission unavailable for this agent
- **Expected behavior:** Graceful degradation - agent works without events
- **Impact:** Reduced observability - agent progress not visible in dashboard
- **Solution:** None required - orchestration continues normally

**Check 2:** Verify events.jsonl is being written
```bash
tail -f .2L/events.jsonl
# Should show new events appearing during orchestration
```

**Cause:** Event emission is non-blocking. If event logger unavailable, agents continue without emitting events.

**Remember:** All event emission is optional. Missing events means reduced visibility, but orchestration succeeds normally.

---

## Architecture Decisions

### Decision 1: Why JSONL for Events?

**Chosen:** JSONL (JSON Lines) - one JSON object per line

**Rationale:**

1. **Append-only format** - No file locking required
   - Multiple agents can write simultaneously
   - No coordination needed between processes
   - Simple `echo {json} >> events.jsonl`

2. **Streaming-friendly** - Parse line by line
   - Dashboard reads line by line without loading entire file
   - Efficient for large event files (thousands of events)
   - Tail-friendly: `tail -f events.jsonl` shows live events

3. **Human-readable** - Easy debugging
   - Each line is valid JSON - can copy/paste to validator
   - Grep-able: `grep "agent_start" events.jsonl`
   - jq-compatible: `cat events.jsonl | jq '.event_type'`

4. **Tool-friendly** - Standard format
   - Many tools support JSONL (jq, streaming parsers, log analyzers)
   - No custom parser required

**Alternative considered:** SQLite database

**Why not SQLite:**
- More complexity (table schema, SQL queries)
- File locking required (slower writes)
- Not human-readable (binary format)
- Over-engineering for MVP scope

**Conclusion:** JSONL provides simplicity, performance, and debuggability for 2L's event system.

---

### Decision 2: Why `gh` CLI Instead of GitHub MCP?

**Chosen:** GitHub CLI (`gh`) for all GitHub operations

**Rationale:**

1. **Simpler dependency** - Standard tool
   - Widely installed developer tool
   - Single binary, no server process
   - Consistent installation across platforms

2. **More reliable** - Direct CLI
   - No MCP server process to manage
   - No additional failure points
   - Simpler error handling

3. **Graceful degradation** - Clear error messages
   - If not installed: "Install gh CLI at https://cli.github.com/"
   - If not authenticated: "Run: gh auth login"
   - Orchestration continues with local git only

4. **Consistent behavior** - Same everywhere
   - Ubuntu, macOS, Windows all use same commands
   - No MCP configuration differences
   - Easier to document and debug

**Alternative considered:** GitHub MCP

**Why not GitHub MCP:**
- Additional complexity (MCP server configuration)
- Less reliable (MCP server process can fail)
- Harder to debug (MCP communication layer)
- No significant benefit over direct CLI

**Conclusion:** `gh` CLI provides simplicity and reliability for 2L's GitHub integration.

---

### Decision 3: Why Polling for Dashboard?

**Chosen:** Dashboard polls `events.jsonl` every 2 seconds

**Rationale:**

1. **Simplicity** - No WebSocket server needed
   - Static file serving only (Python http.server)
   - No server-side code (just HTML/JS/CSS)
   - Easy to implement and maintain

2. **Cross-platform** - Works everywhere
   - No additional dependencies
   - Works on any OS with Python 3
   - No firewall issues (localhost only)

3. **Low overhead** - 2-second interval
   - Minimal CPU usage
   - Small file reads (events.jsonl rarely > 100KB)
   - Acceptable latency for observability use case

4. **Works with static serving** - No backend required
   - Dashboard is pure frontend
   - Can be served from any HTTP server
   - Portable (copy dashboard directory anywhere)

**Alternative considered:** WebSocket real-time streaming

**Why not WebSocket:**
- Over-engineering for MVP
- Requires server-side code (not just static files)
- More complexity (connection management, reconnection logic)
- Polling is sufficient for observability (2-second latency acceptable)

**Conclusion:** Polling provides adequate real-time updates with minimal complexity.

---

### Decision 4: Why HTTP Server for Dashboard?

**Chosen:** Python HTTP server bound to localhost

**Rationale:**

1. **Browser security** - CORS blocks `file://` protocol
   - Modern browsers prevent `file://` from fetching local files
   - Security policy: `file://` origin cannot fetch other files
   - HTTP origin (localhost) CAN fetch files from same origin

2. **Modern web standards** - fetch API requires HTTP
   - Dashboard uses `fetch('/events.jsonl')` to poll events
   - Works with HTTP origin, blocked by file:// origin
   - Standard web development pattern

3. **Localhost-only binding** - Secure
   - Server binds to 127.0.0.1 (localhost) only
   - Not accessible from network
   - No external security risk

4. **Multi-project support** - Dynamic port allocation
   - Each project gets unique port (8080-8099)
   - State files track port and PID
   - 20 concurrent projects supported

**Alternative considered:** File watching and reload

**Why not file watching:**
- Browser security prevents `file://` protocol from fetching `.2L/events.jsonl`
- Would need browser extension (non-standard)
- HTTP server is simpler and standard

**Conclusion:** HTTP server solves browser CORS restrictions while maintaining security (localhost-only).

---

## Additional Resources

### Commands Reference

- `/2l-vision` - Interactive requirements gathering
- `/2l-plan` - Create master plan from vision
- `/2l-mvp` - Full autonomy mode (vision → plan → execute)
- `/2l-status` - Show current orchestration state
- `/2l-dashboard` - Start dashboard server
- `/2l-dashboard-stop` - Stop dashboard server
- `/2l-check-mcps` - Show MCP status and setup links

### File Structure

```
project/
├── .2L/
│   ├── config.yaml              # Global 2L configuration
│   ├── events.jsonl             # Event stream (JSONL format)
│   ├── dashboard/
│   │   ├── index.html           # Dashboard HTML
│   │   ├── .server-port         # Allocated port (e.g., "8080")
│   │   └── .server-pid          # Server process ID
│   └── plan-1/
│       ├── vision.md            # Project vision
│       ├── master-plan.yaml     # Multi-iteration plan
│       └── iteration-1/
│           ├── exploration/     # Explorer reports
│           ├── plan/            # Planner outputs
│           ├── building/        # Builder reports
│           ├── integration/     # Integrator outputs
│           └── validation/      # Validator reports
├── src/                         # Your application code
└── README.md                    # This file
```

### Learn More

- **Event System:** See [Event System Architecture](#event-system-architecture)
- **Dashboard:** See [Dashboard Access](#dashboard-access)
- **MCPs:** See [MCP Integration](#mcp-integration)
- **GitHub:** See [GitHub Integration](#github-integration)
- **Troubleshooting:** See [Troubleshooting](#troubleshooting)

---

**Built with 2L** 🤖
