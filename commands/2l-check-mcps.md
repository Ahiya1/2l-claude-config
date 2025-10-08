# 2L Check MCPs - MCP Status and Setup Guide

Display information about available Model Context Protocol (MCP) servers and setup instructions. This command provides an educational resource listing all MCPs that can enhance 2L agent capabilities.

## Usage

```bash
/2l-check-mcps
```

No arguments needed. The command displays:
- All 4 available MCPs
- Purpose and capabilities of each
- Setup links to official repositories
- Clear reminder: ALL MCPs are OPTIONAL

---

## What This Does

### MCP Overview

This command lists the 4 MCP servers that can enhance 2L agent capabilities during orchestration:

1. **Playwright MCP** - Browser automation for frontend testing
2. **Chrome DevTools MCP** - Performance profiling and debugging
3. **Supabase Local MCP** - Database validation and SQL queries
4. **Screenshot MCP** - Visual capture for documentation

**Important:** All MCPs are OPTIONAL. 2L core functionality works perfectly without any MCPs installed. They only enhance what agents can do during building phases.

### Cannot Auto-Detect

Claude doesn't expose an API to detect MCP connection status. This command provides informational guidance only. To verify an MCP is working, try using it during an orchestration.

### What You'll See

The command displays formatted output with:
- MCP name and primary use case
- Purpose and capabilities
- Optional status indicator
- Setup link to official repository
- What the MCP enables for agents

---

## MCP Details

### 1. Playwright MCP (Browser Automation)

**Purpose:** E2E testing, user flow validation, frontend testing

**Capabilities:**
- Navigate to URLs
- Fill forms and click elements
- Execute JavaScript in browser
- Get page content via accessibility tree
- Wait for elements and page loads

**Setup:** https://github.com/executeautomation/playwright-mcp-server

**What it enables:**
- Frontend component testing
- Form automation and validation
- Navigation checks
- User flow verification

**Status:** ⚠️ Optional - 2L works without this MCP

---

### 2. Chrome DevTools MCP (Performance & Debugging)

**Purpose:** Performance analysis, debugging, frontend profiling

**Capabilities:**
- Record performance traces
- Analyze network requests
- Capture console messages
- CPU/network emulation
- Take screenshots
- Execute JavaScript

**Setup:** https://github.com/MCP-Servers/chrome-devtools

**What it enables:**
- Performance profiling
- Network request analysis
- Console error checking
- Testing under slow network/CPU conditions

**Status:** ⚠️ Optional - 2L works without this MCP

---

### 3. Supabase Local MCP (Database Validation)

**Purpose:** PostgreSQL schema validation, SQL queries, database testing

**Capabilities:**
- Execute SQL queries
- Create tables and schemas
- Manage migrations
- Seed test data
- Inspect database schemas

**Prerequisites:** Database running on port 5432

**Setup:** https://github.com/MCP-Servers/supabase-local

**What it enables:**
- Database schema verification
- SQL query testing
- Data seeding
- Migration validation

**Status:** ⚠️ Optional - 2L works without this MCP

---

### 4. Screenshot MCP (Visual Capture)

**Purpose:** Screenshot capture for documentation and visual verification

**Capabilities:**
- Capture screen regions
- Save images to disk
- Visual documentation

**Setup:** https://github.com/MCP-Servers/screenshot

**What it enables:**
- Visual documentation during orchestration
- Screenshot-based verification
- Build artifacts with images

**Status:** ⚠️ Optional - 2L works without this MCP

---

## Setup Instructions

To configure MCPs in Claude Desktop:

1. **Open Claude Desktop settings**
2. **Edit configuration file:** `claude_desktop_config.json`
3. **Add MCP server configurations** for the MCPs you want
4. **Restart Claude Desktop** to activate MCPs

For detailed setup instructions for each MCP, follow the setup links above.

### Configuration Location

- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Linux:** `~/.config/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

### Example Configuration

```json
{
  "mcpServers": {
    "playwright": {
      "command": "node",
      "args": ["/path/to/playwright-mcp-server/index.js"]
    }
  }
}
```

---

## Verification

You cannot technically verify MCP connection status from this command (Claude doesn't expose MCP status API).

**To verify an MCP is working:**
- Use it during a 2L orchestration
- Agents will report if MCP tools are available
- Check agent reports for "MCP Testing Performed" sections

**Remember:** All MCPs are optional. If an MCP is unavailable, agents gracefully continue without it.

---

## For More Information

See the [MCP Integration](../../../README.md#mcp-integration) section in the README for:
- Detailed MCP capabilities
- Setup walkthroughs
- Troubleshooting common issues
- MCP usage examples during orchestration

---

## Implementation

```bash
#!/bin/bash

echo "🔍 2L MCP Connection Status"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "MCP Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 All MCPs are OPTIONAL - 2L works without them!"
echo ""
echo "MCPs enhance agent capabilities during orchestration. 2L core functionality"
echo "works perfectly without any MCPs installed."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Available MCPs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Playwright MCP (Browser Automation)"
echo "   Purpose: E2E testing, user flow validation"
echo "   Status: ⚠️  Optional"
echo "   Setup: https://github.com/executeautomation/playwright-mcp-server"
echo "   Enables: Frontend testing, form automation, navigation checks"
echo ""
echo "2. Chrome DevTools MCP (Performance Profiling)"
echo "   Purpose: Performance analysis, debugging"
echo "   Status: ⚠️  Optional"
echo "   Setup: https://github.com/MCP-Servers/chrome-devtools"
echo "   Enables: Performance traces, network analysis, console debugging"
echo ""
echo "3. Supabase Local MCP (Database Validation)"
echo "   Purpose: PostgreSQL schema validation, SQL queries"
echo "   Status: ⚠️  Optional"
echo "   Setup: https://github.com/MCP-Servers/supabase-local"
echo "   Enables: Database testing, schema verification, SQL validation"
echo ""
echo "4. Screenshot MCP (Visual Capture)"
echo "   Purpose: Screenshot capture for documentation"
echo "   Status: ⚠️  Optional"
echo "   Setup: https://github.com/MCP-Servers/screenshot"
echo "   Enables: Visual documentation during orchestration"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Setup Instructions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Open Claude Desktop settings"
echo "2. Edit claude_desktop_config.json"
echo "3. Add MCP server configurations"
echo "4. Restart Claude Desktop"
echo ""
echo "For detailed setup: See README.md \"MCP Integration\" section"
echo ""
echo "Note: Cannot auto-detect MCP connections. Verify by using MCPs"
echo "      during orchestration - agents will report availability."
echo ""
```
