# 2L Dashboard Stop - Stop Dashboard Server

Stop the dashboard HTTP server and free the port for other projects.

## Usage

```bash
/2l-dashboard-stop
```

No arguments needed. The command will:
1. Read PID from `.2L/dashboard/.server-pid`
2. Kill the server process gracefully
3. Clean up state files
4. Display confirmation

---

## What This Does

### Server Cleanup
- Stops the Python HTTP server process
- Removes `.2L/dashboard/.server-pid` file
- Removes `.2L/dashboard/.server-port` file
- Frees port for use by other projects

### Graceful Handling
- No error if server already stopped
- No error if state files missing
- Verifies PID ownership before killing
- Uses SIGTERM for clean shutdown

---

## Multi-Project Support

Each project has its own dashboard server. Running this command only stops the server for the current project. Other project dashboards remain running.

---

## Implementation

```bash
#!/bin/bash

# Check if PID file exists
if [ ! -f ".2L/dashboard/.server-pid" ]; then
  echo "No dashboard server found (PID file missing)"
  echo ""
  echo "The server may have already been stopped, or was never started."
  echo ""
  echo "To start the dashboard: /2l-dashboard"
  exit 0
fi

# Read PID and port from files
SERVER_PID=$(cat .2L/dashboard/.server-pid)
DASHBOARD_PORT=""

if [ -f ".2L/dashboard/.server-port" ]; then
  DASHBOARD_PORT=$(cat .2L/dashboard/.server-port)
fi

# Check if process is still running
if ps -p "$SERVER_PID" > /dev/null 2>&1; then
  # Verify process is owned by current user (safety check)
  PROCESS_USER=$(ps -p "$SERVER_PID" -o user= 2>/dev/null | tr -d ' ')
  CURRENT_USER=$(whoami)

  if [ "$PROCESS_USER" != "$CURRENT_USER" ]; then
    echo "Error: Process $SERVER_PID is owned by '$PROCESS_USER', not '$CURRENT_USER'"
    echo ""
    echo "Cannot kill process owned by another user."
    echo "Manual cleanup required:"
    echo "  rm .2L/dashboard/.server-pid .2L/dashboard/.server-port"
    exit 1
  fi

  # Kill the server process (SIGTERM for graceful shutdown)
  kill "$SERVER_PID" 2>/dev/null

  # Wait briefly for process to terminate
  sleep 0.5

  # Verify process terminated
  if ps -p "$SERVER_PID" > /dev/null 2>&1; then
    # Process still running, force kill
    echo "Process did not terminate gracefully, forcing..."
    kill -9 "$SERVER_PID" 2>/dev/null
    sleep 0.3
  fi

  echo "✓ Dashboard server stopped"
  echo ""
  echo "  PID: $SERVER_PID (terminated)"

  if [ -n "$DASHBOARD_PORT" ]; then
    echo "  Port: $DASHBOARD_PORT (now available)"
  fi
else
  echo "Dashboard server already stopped (PID $SERVER_PID not running)"

  if [ -n "$DASHBOARD_PORT" ]; then
    echo ""
    echo "  Port: $DASHBOARD_PORT (was allocated)"
  fi
fi

# Clean up state files
rm -f .2L/dashboard/.server-pid
rm -f .2L/dashboard/.server-port

echo ""
echo "State files cleaned up."
echo ""
echo "To restart the dashboard: /2l-dashboard"
```
