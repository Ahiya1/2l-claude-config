# 2L Claude Code Configuration

A comprehensive two-level (2L) development system for Claude Code, featuring specialized agents and commands for systematic software development.

## Overview

The 2L system provides a structured approach to building complex software projects through:
- **10 specialized agents** for exploration, planning, building, integration, and validation
- **17 commands** for managing development workflows, plans, and iterations
- **Systematic iterative development** with built-in quality controls

## Components

### Agents (`agents/`)
- **2l-builder** - Implements features according to plan
- **2l-dashboard-builder** - Generates project-specific dashboards
- **2l-explorer** - Analyzes codebase architecture and patterns
- **2l-healer** - Fixes issues identified during validation
- **2l-integrator** - Merges builder outputs into cohesive codebase
- **2l-iplanner** - Creates integration plans from builder outputs
- **2l-ivalidator** - Validates integration for organic cohesion
- **2l-master-explorer** - Strategic exploration for master planning
- **2l-planner** - Creates development plans from exploration findings
- **2l-validator** - Tests and validates for production readiness

### Commands (`commands/`)
- **2l-abandon-plan** - Abandon current plan and clean up
- **2l-build** - Execute building phase
- **2l-commit-iteration** - Commit completed iteration
- **2l-continue** - Resume current workflow phase
- **2l-explore** - Start exploration phase
- **2l-heal** - Execute healing phase
- **2l-list-iterations** - Show all iterations in a plan
- **2l-list-plans** - Show all available plans
- **2l-mvp** - Create and execute MVP workflow
- **2l-next** - Move to next workflow phase
- **2l-plan** - Create comprehensive development plan
- **2l-rollback** - Rollback to previous iteration
- **2l-rollback-to-plan** - Rollback to start of plan
- **2l-status** - Show current workflow status
- **2l-task** - Execute specific development task
- **2l-validate** - Run validation checks
- **2l-vision** - Create new plan with vision

### Libraries (`lib/`)
Shared utilities and helper functions used across agents and commands.

### Schemas (`schemas/`)
Configuration schemas and validation rules for the 2L system.

## Installation

### Option 1: Direct Copy
```bash
# Clone this repository
git clone <your-repo-url> ~/2l-claude-config-repo

# Copy to your Claude config directory
cp -r ~/2l-claude-config-repo/agents ~/.claude/
cp -r ~/2l-claude-config-repo/commands ~/.claude/
cp -r ~/2l-claude-config-repo/lib ~/.claude/
cp -r ~/2l-claude-config-repo/schemas ~/.claude/
```

### Option 2: Symlinks (Recommended)
```bash
# Clone this repository
git clone <your-repo-url> ~/2l-claude-config-repo

# Create symlinks
ln -sf ~/2l-claude-config-repo/agents ~/.claude/agents
ln -sf ~/2l-claude-config-repo/commands ~/.claude/commands
ln -sf ~/2l-claude-config-repo/lib ~/.claude/lib
ln -sf ~/2l-claude-config-repo/schemas ~/.claude/schemas
```

### Option 3: Install Script
```bash
# Clone and run install script
git clone <your-repo-url> ~/2l-claude-config-repo
cd ~/2l-claude-config-repo
./install.sh  # Coming soon
```

## Usage

After installation, the 2L commands will be available in Claude Code:

```bash
# Start a new MVP project
/2l-mvp "Build a task management API"

# Create a detailed plan
/2l-vision "Create a real-time chat application"

# Check current status
/2l-status

# Continue with current phase
/2l-continue
```

## Project Structure

```
~/.claude/
├── agents/          # 2L specialized agents
├── commands/        # 2L workflow commands
├── lib/            # Shared utilities
└── schemas/        # Configuration schemas
```

## Requirements

- Claude Code CLI
- Git (for version control)
- Bash/Zsh shell

## Contributing

Contributions welcome! Please feel free to submit pull requests or open issues.

## License

[Your chosen license]

## Author

Ahiya (@Ahiya1)
