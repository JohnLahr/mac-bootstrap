# mac-bootstrap

Automated setup for a headless Mac Mini M4 running AI workflows (Claude Code, Claude Desktop).

Installs and configures: Homebrew, Node.js, CLI tools, desktop apps, Oh My Zsh, VS Code
extensions/settings, project templates, and headless macOS optimisations.

## Quick Start

```bash
git clone https://github.com/stevesimpson418/mac-bootstrap.git
cd mac-bootstrap
```

Follow the [Setup Guide](SETUP_GUIDE.md) for manual pre-requisites (Phases 1-4), then
run the automated installer:

```bash
chmod +x setup.sh
./setup.sh
```

The script is idempotent — safe to re-run if something fails halfway through.

## What the Script Installs

| Category        | Tools                                                              |
| --------------- | ------------------------------------------------------------------ |
| Shell           | zsh, bash, tmux, Oh My Zsh, Powerlevel10k                          |
| Version control | git, gh, glab, lefthook, commitlint                                |
| Python          | uv, ruff                                                           |
| Node.js         | nvm, Node LTS                                                      |
| Linting         | shellcheck, shfmt, markdownlint-cli2                               |
| Desktop apps    | Chrome, 1Password, iTerm2, VS Code, Claude Desktop, BetterDisplay  |
| IDE             | VS Code extensions + global settings                               |
| Templates       | Generic and Python project scaffolding via `newproject` command    |

## Repository Structure

```text
setup.sh                   # Automated installer (Phase 5)
SETUP_GUIDE.md             # Full step-by-step setup guide (all phases)
lefthook.yml               # Git hooks: markdownlint, shellcheck, shfmt, commitlint
commitlint.config.mjs      # Conventional Commits config
.markdownlint-cli2.jsonc    # Markdown linting rules
.github/workflows/ci.yml   # CI: shellcheck, shfmt, markdownlint
```

## Development

### Prerequisites

Install the linting tools (these are also installed by `setup.sh`):

```bash
brew install shellcheck shfmt markdownlint-cli2 lefthook commitlint
npm install -g @commitlint/config-conventional
```

### Git Hooks

This repo uses [Lefthook](https://github.com/evilmartians/lefthook) for pre-commit and
commit-msg hooks:

```bash
lefthook install
```

Hooks run automatically on commit:

- **markdownlint** — lints `*.md` files
- **shellcheck** — static analysis for `*.sh` files
- **shfmt** — formatting check for `*.sh` files
- **commitlint** — enforces [Conventional Commits](https://www.conventionalcommits.org/)

### Commit Message Format

All commits must follow Conventional Commits:

```text
type(scope): subject

# Examples:
feat: add Python project template
fix(setup): correct nvm path on Apple Silicon
docs: update network configuration steps
chore: bump shellcheck to latest
```

## License

MIT
