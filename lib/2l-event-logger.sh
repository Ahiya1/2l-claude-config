#!/usr/bin/env bash
#
# 2L Event Logger Library
# Provides log_2l_event function for streaming orchestration events to .2L/events.jsonl
#
# Usage:
#   source ~/.claude/lib/2l-event-logger.sh
#   log_2l_event "event_type" "data" "phase" "agent_id"
#

# Event logging function
# Arguments:
#   $1 - event_type (required): Type of event (plan_start, agent_spawn, etc.)
#   $2 - data (required): Event data/message
#   $3 - phase (optional): Current orchestration phase (defaults to "unknown")
#   $4 - agent_id (optional): Agent identifier (defaults to "orchestrator")
log_2l_event() {
  local event_type="$1"
  local data="$2"
  local phase="${3:-unknown}"
  local agent_id="${4:-orchestrator}"

  # Validate required parameters
  if [ -z "$event_type" ] || [ -z "$data" ]; then
    return 1
  fi

  # Generate ISO 8601 timestamp
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Event file location
  local event_file=".2L/events.jsonl"

  # Create .2L directory if needed
  mkdir -p .2L 2>/dev/null || true

  # Escape double quotes in data fields
  event_type="${event_type//\"/\\\"}"
  data="${data//\"/\\\"}"
  phase="${phase//\"/\\\"}"
  agent_id="${agent_id//\"/\\\"}"

  # Build JSON event object
  local json_event="{\"timestamp\":\"$timestamp\",\"event_type\":\"$event_type\",\"phase\":\"$phase\",\"agent_id\":\"$agent_id\",\"data\":\"$data\"}"

  # Append to event file (atomic operation, fails silently)
  echo "$json_event" >> "$event_file" 2>/dev/null || true
}

# Export function for use in other scripts
export -f log_2l_event
