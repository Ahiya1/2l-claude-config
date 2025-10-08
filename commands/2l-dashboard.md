# 2L Dashboard - Start Dashboard Server

Start a local HTTP server to view the 2L orchestration dashboard in your browser. The dashboard displays real-time events, active agents, and orchestration progress.

## Usage

```bash
/2l-dashboard
```

No arguments needed. The command will:
1. Generate dashboard HTML if needed
2. Find an available port (8080-8099)
3. Start HTTP server
4. Open dashboard in browser
5. Reuse existing port if server already running

---

## What This Does

### Dashboard Features
- Real-time event timeline (polls `.2L/events.jsonl` every 2 seconds)
- Active agent tracking with duration calculation
- Orchestration metrics (elapsed time, total events, active agents)
- Phase visualization (exploration → planning → building → integration → validation)
- Last 50 events displayed with color coding

### Multi-Project Support
- Each project gets a unique port (8080-8099)
- 20 concurrent project dashboards supported
- Port and PID tracked in `.2L/dashboard/.server-port` and `.server-pid`
- Reuses same port on subsequent runs if server still running

### Server Details
- Uses Python 3 `http.server` module (no dependencies)
- Binds to localhost only (127.0.0.1)
- Serves `.2L/dashboard/` directory
- Runs in background until stopped

---

## Stopping the Dashboard

Use `/2l-dashboard-stop` to stop the server and free the port.

---

## Implementation

```bash
#!/bin/bash

# Check if dashboard HTML exists, spawn builder if missing
if [ ! -f ".2L/dashboard/index.html" ]; then
  echo "Dashboard HTML not found. Generating..."
  echo ""
  echo "Please run the 2l-dashboard-builder agent to generate the dashboard:"
  echo "  1. In Claude chat, type: @2l-dashboard-builder"
  echo "  2. Or use Task tool to spawn the agent"
  echo ""
  echo "After the agent completes, run /2l-dashboard again."
  exit 1
fi

# Check if server already running (port reuse)
if [ -f ".2L/dashboard/.server-port" ] && [ -f ".2L/dashboard/.server-pid" ]; then
  STORED_PORT=$(cat .2L/dashboard/.server-port)
  STORED_PID=$(cat .2L/dashboard/.server-pid)

  # Verify process still running
  if ps -p "$STORED_PID" > /dev/null 2>&1; then
    echo "Dashboard already running on port $STORED_PORT (PID: $STORED_PID)"
    echo "Opening browser to http://localhost:$STORED_PORT/dashboard/index.html"
    echo ""
    echo "To stop: /2l-dashboard-stop"

    # Open browser to existing server
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "http://localhost:$STORED_PORT/dashboard/index.html" >/dev/null 2>&1 &
    elif command -v open >/dev/null 2>&1; then
      open "http://localhost:$STORED_PORT/dashboard/index.html"
    else
      echo ""
      echo "Could not auto-open browser. Please open manually:"
      echo "  http://localhost:$STORED_PORT/dashboard/index.html"
    fi

    exit 0
  else
    # Process died, clean up stale files
    echo "Cleaning up stale server files (process $STORED_PID not running)..."
    rm -f .2L/dashboard/.server-pid .2L/dashboard/.server-port
  fi
fi

# Find available port in range 8080-8099
DASHBOARD_PORT=""
for port in {8080..8099}; do
  if ! lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
    DASHBOARD_PORT=$port
    break
  fi
done

if [ -z "$DASHBOARD_PORT" ]; then
  echo "Error: All dashboard ports (8080-8099) are in use"
  echo ""
  echo "You have 20 concurrent dashboard servers running!"
  echo ""
  echo "To free a port, navigate to another project and run:"
  echo "  /2l-dashboard-stop"
  echo ""
  echo "Or manually check ports:"
  echo "  lsof -i :8080-8099"
  exit 1
fi

# Verify Python 3 is available
if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: Python 3 not found"
  echo ""
  echo "Dashboard requires Python 3 for HTTP server."
  echo ""
  echo "Install Python 3:"
  echo "  - Ubuntu/Debian: sudo apt install python3"
  echo "  - macOS: brew install python3"
  echo "  - Or download from: https://www.python.org/downloads/"
  exit 1
fi

# Start Python HTTP server in background
# Serve from .2L/ directory so both dashboard/ and events.jsonl are accessible
cd .2L || exit 1
python3 -m http.server "$DASHBOARD_PORT" --bind 127.0.0.1 > /dev/null 2>&1 &
SERVER_PID=$!

# Wait briefly to ensure server started
sleep 0.5

# Verify server process is running
if ! ps -p "$SERVER_PID" > /dev/null 2>&1; then
  echo "Error: Failed to start HTTP server"
  echo ""
  echo "The Python http.server process died immediately."
  echo "Check if port $DASHBOARD_PORT is truly available:"
  echo "  lsof -i :$DASHBOARD_PORT"
  exit 1
fi

# Store port and PID for reuse and cleanup
echo "$DASHBOARD_PORT" > dashboard/.server-port
echo "$SERVER_PID" > dashboard/.server-pid

# Return to project root
cd ..

echo "✓ Dashboard server started"
echo ""
echo "  URL: http://localhost:$DASHBOARD_PORT/dashboard/index.html"
echo "  Port: $DASHBOARD_PORT"
echo "  PID: $SERVER_PID"
echo ""
echo "The dashboard will auto-refresh every 2 seconds to show:"
echo "  - Real-time event timeline"
echo "  - Active agents and their progress"
echo "  - Orchestration metrics"
echo ""
echo "To stop the server: /2l-dashboard-stop"
echo ""

# Open browser (platform-specific)
if command -v xdg-open >/dev/null 2>&1; then
  # Linux
  xdg-open "http://localhost:$DASHBOARD_PORT/dashboard/index.html" >/dev/null 2>&1 &
  echo "Opening browser..."
elif command -v open >/dev/null 2>&1; then
  # macOS
  open "http://localhost:$DASHBOARD_PORT/dashboard/index.html"
  echo "Opening browser..."
else
  # Fallback
  echo "Could not auto-open browser. Please open manually:"
  echo "  http://localhost:$DASHBOARD_PORT/dashboard/index.html"
fi
```
