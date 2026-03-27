# infra-scripts

Minimal, non-interactive, and repeatable **instance bootstrap script**.

Brings up a complete development environment on fresh machines
(GPU rentals, bare-metal servers, VMs) with **a single command** — no prompts, no manual selection.

## What it installs

| Component | Method |
|-----------|--------|
| System update & upgrade | apt |
| curl | apt |
| nvtop (GPU monitor) | apt |
| tmux + custom config | apt |
| uv (Astral) | installer script |
| Node.js v25 (via nvm) | nvm |
| OpenAI Codex CLI | npm |
| Cursor CLI | installer script |
| Claude Code CLI | installer script |

All components are installed in dependency order and skipped if already present.

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/emre570/infra-scripts/main/instance-boot.sh | bash
```

After it finishes, reload your shell to pick up PATH changes:

```bash
exec bash -l
```

## Design

- Detects active shell (bash / zsh) and modifies only the correct rc file
- Handles PATH, NVM, and environment setup within the same session
- Idempotent — safe to re-run; already-installed tools are skipped
- Individual failures are caught and reported without aborting the rest
