#!/bin/bash
# =============================================================================
# Mac Mini M4 — Headless Server Setup Script
# =============================================================================
# Purpose: Always-on headless Mac for AI workflows (Claude Code, Claude Desktop)
# Run this after completing Phases 1-4 of the setup checklist (OS config,
# always-on settings, remote access, and HDMI dummy plug / virtual display).
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#
# Notes:
#   - Idempotent: safe to re-run if something fails halfway through
#   - Requires internet connection
#   - Will prompt for sudo password once at the start
#   - Estimated time: 15-25 minutes depending on connection speed
# =============================================================================

set -euo pipefail

# -- Colours and formatting ---------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No colour

log_header() { echo -e "\n${BLUE}${BOLD}━━━ $1 ━━━${NC}\n"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_skip() { echo -e "${YELLOW}⊘${NC} $1 (already installed)"; }
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# -- Pre-flight checks --------------------------------------------------------
log_header "Pre-flight Checks"

if [[ "$(uname)" != "Darwin" ]]; then
	log_error "This script is for macOS only."
	exit 1
fi

log_success "Running on macOS $(sw_vers -productVersion)"

# Cache sudo credentials upfront
log_info "You may be prompted for your password once..."
sudo -v
# Keep sudo alive for the duration of the script
while true; do
	sudo -n true
	sleep 60
	kill -0 "$$" || exit
done 2>/dev/null &

# -- Homebrew ------------------------------------------------------------------
log_header "Homebrew"

if command -v brew &>/dev/null; then
	log_skip "Homebrew"
	log_info "Updating Homebrew..."
	brew update
else
	log_info "Installing Homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	# Add Homebrew to PATH for Apple Silicon Macs
	if [[ -f /opt/homebrew/bin/brew ]]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
		# Persist for future sessions (will be in .zshrc later, but needed now)
		# shellcheck disable=SC2016
		echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$HOME/.zprofile"
	fi

	log_success "Homebrew installed"
fi

brew analytics off
log_success "Homebrew analytics disabled"

# -- Homebrew Formulae (CLI tools) ---------------------------------------------
log_header "CLI Tools (Homebrew Formulae)"

FORMULAE=(
	# Shell
	zsh
	bash
	tmux

	# Version control
	git
	gh   # GitHub CLI
	glab # GitLab CLI

	# Python development
	uv   # Fast Python package manager (Rust-based, from Astral)
	ruff # Fast Python linter/formatter (Rust-based, from Astral)

	# Markdown
	markdownlint-cli2 # Markdown linting (used by VS Code extension)

	# Shell scripting
	shellcheck # Shell script static analysis
	shfmt      # Shell script formatter

	# Git hooks
	lefthook   # Fast, polyglot Git hooks manager
	commitlint # Conventional commit message linter

	# Terminal theme
	powerlevel10k # Powerline theme for zsh

	# Node.js version management
	nvm # Node Version Manager
)

for formula in "${FORMULAE[@]}"; do
	if brew list "$formula" &>/dev/null; then
		log_skip "$formula"
	else
		log_info "Installing $formula..."
		brew install "$formula"
		log_success "$formula installed"
	fi
done

# -- Node.js (via nvm) --------------------------------------------------------
log_header "Node.js (via nvm)"

# Create nvm directory
export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"

# Source nvm (Homebrew installs it as a shell script, not a binary)
# shellcheck disable=SC1091
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && . "$(brew --prefix)/opt/nvm/nvm.sh"

if command -v node &>/dev/null; then
	log_skip "Node.js $(node --version) already installed"
else
	log_info "Installing Node.js LTS via nvm..."
	nvm install --lts
	nvm alias default lts/*
	log_success "Node.js $(node --version) installed"
fi

# -- npm Global Packages ------------------------------------------------------
log_header "npm Global Packages"

NPM_GLOBALS=(
	"@commitlint/config-conventional" # Conventional commits ruleset for commitlint
)

for pkg in "${NPM_GLOBALS[@]}"; do
	if npm list -g "$pkg" &>/dev/null 2>&1; then
		log_skip "$pkg"
	else
		log_info "Installing $pkg..."
		npm install -g "$pkg"
		log_success "$pkg installed"
	fi
done

# -- Homebrew Casks (GUI apps and desktop tools) -------------------------------
log_header "Desktop Apps (Homebrew Casks)"

CASKS=(
	# User apps
	brave-browser
	notion
	todoist

	# Window management
	rectangle

	# Terminal
	iterm2

	# IDE
	visual-studio-code

	# Claude
	claude # Claude Desktop (Cowork)

	# Fonts
	font-fira-code          # Editor font (ligatures)
	font-meslo-lg-nerd-font # Terminal font (powerline glyphs for p10k)

	# Headless display management
	betterdisplay
)

for cask in "${CASKS[@]}"; do
	if brew list --cask "$cask" &>/dev/null; then
		log_skip "$cask"
	else
		log_info "Installing $cask..."
		brew install --cask "$cask"
		log_success "$cask installed"
	fi
done

# -- Claude Code (native installer, auto-updates) -----------------------------
log_header "Claude Code"

if command -v claude &>/dev/null; then
	log_skip "Claude Code ($(claude --version 2>/dev/null || echo 'installed'))"
else
	log_info "Installing Claude Code via native installer..."
	curl -fsSL https://claude.ai/install.sh | bash
	log_success "Claude Code installed"
fi

# -- Oh My Zsh ----------------------------------------------------------------
log_header "Oh My Zsh"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
	log_skip "Oh My Zsh"
else
	log_info "Installing Oh My Zsh..."
	# RUNZSH=no prevents it from switching to zsh immediately and breaking the script
	# CHSH=no prevents it from changing the default shell mid-script
	RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	log_success "Oh My Zsh installed"
fi

# -- Oh My Zsh Plugins --------------------------------------------------------
log_header "Oh My Zsh Plugins"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# zsh-autosuggestions: suggests commands as you type based on history
if [[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
	log_skip "zsh-autosuggestions"
else
	log_info "Installing zsh-autosuggestions..."
	git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
	log_success "zsh-autosuggestions installed"
fi

# zsh-syntax-highlighting: colours valid/invalid commands as you type
if [[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
	log_skip "zsh-syntax-highlighting"
else
	log_info "Installing zsh-syntax-highlighting..."
	git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
	log_success "zsh-syntax-highlighting installed"
fi

# Powerlevel10k theme
if [[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
	log_skip "Powerlevel10k theme"
else
	log_info "Installing Powerlevel10k theme..."
	git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
	log_success "Powerlevel10k installed"
fi

# -- ZSH Configuration --------------------------------------------------------
log_header "ZSH Configuration"

# Back up existing .zshrc if it exists and wasn't created by this script
if [[ -f "$HOME/.zshrc" ]] && ! grep -q "# Managed by setup.sh" "$HOME/.zshrc"; then
	cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d%H%M%S)"
	log_info "Existing .zshrc backed up"
fi

cat >"$HOME/.zshrc" <<'ZSHRC'
# Managed by setup.sh — edit freely, but keep this comment for backup detection

# -- Powerlevel10k Instant Prompt ----------------------------------------------
# Should stay close to the top of ~/.zshrc. Initialization code that may require
# console input (password prompts, [y/n] confirmations, etc.) must go above this block.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -- Homebrew ------------------------------------------------------------------
eval "$(/opt/homebrew/bin/brew shellenv)"

# -- Oh My Zsh -----------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"

# Theme: Powerlevel10k (powerline prompt with git status, execution time, etc.)
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
# git:                    git aliases and branch info in prompt
# gh:                     GitHub CLI completions
# tmux:                   tmux session management aliases
# vscode:                 VS Code launcher aliases
# zsh-autosuggestions:    history-based command suggestions (custom plugin)
# zsh-syntax-highlighting: colours commands as you type (custom plugin)
plugins=(
    git
    gh
    tmux
    vscode
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# -- Path additions ------------------------------------------------------------
# uv-managed Python (if installed via uv)
export PATH="$HOME/.local/bin:$PATH"

# -- nvm (Node Version Manager) -----------------------------------------------
export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && . "$(brew --prefix)/opt/nvm/nvm.sh"
[ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && . "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm"

# -- Tool completions ----------------------------------------------------------
# uv shell completion
eval "$(uv generate-shell-completion zsh)"

# ruff shell completion
eval "$(ruff generate-shell-completion zsh)"

# -- Aliases -------------------------------------------------------------------
# General
alias ll="ls -la"
alias ..="cd .."
alias ...="cd ../.."

# tmux: attach to existing session or create new one named 'main'
alias ta="tmux attach -t main || tmux new -s main"

# Git shortcuts (beyond what oh-my-zsh git plugin provides)
alias gs="git status"
alias gp="git pull"

# Claude
alias cc="claude"

# Brew maintenance
alias brewup="brew update && brew upgrade && brew cleanup"

# Quick system check
alias syscheck="echo '--- Uptime ---' && uptime && echo '--- Disk ---' && df -h / && echo '--- Memory ---' && memory_pressure | head -1"

# -- Functions -----------------------------------------------------------------
# Scaffold a new project with lefthook, commitlint, and VS Code config
# Usage: newproject <name> [python]  (defaults to generic)
newproject() {
  if [[ -z "$1" ]]; then
    echo "Usage: newproject <project-name> [python]"
    echo ""
    echo "Templates:"
    echo "  (default)  Generic git repo — lefthook, commitlint, markdownlint, shellcheck"
    echo "  python     Python project  — adds uv, ruff, pytest, debug configs"
    return 1
  fi

  local name="$1"
  local type="${2:-generic}"
  local template_dir="$HOME/.project-templates/$type"

  if [[ ! -d "$template_dir" ]]; then
    echo "Unknown template: $type"
    echo "Available: generic, python"
    return 1
  fi

  mkdir -p "$name" && cd "$name" || return 1

  # Copy template files
  cp -r "$template_dir/." .

  # Initialise git
  git init

  # Type-specific setup
  if [[ "$type" == "python" ]]; then
    uv init --name "$name"
    uv add --dev pytest ruff
    echo ""
    echo "✓ Project '$name' created (python) with:"
    echo "  • uv project (pyproject.toml + .venv)"
    echo "  • lefthook hooks (ruff, markdownlint, shellcheck, commitlint)"
    echo "  • VS Code workspace settings + debug configs"
    echo "  • ruff.toml + .markdownlint-cli2.jsonc"
  else
    echo ""
    echo "✓ Project '$name' created (generic) with:"
    echo "  • lefthook hooks (markdownlint, shellcheck, commitlint)"
    echo "  • VS Code workspace settings"
    echo "  • .markdownlint-cli2.jsonc"
  fi

  # Install lefthook git hooks
  lefthook install

  echo ""
  echo "Next: open in VS Code with 'code .'"
}

# -- Environment ---------------------------------------------------------------
export EDITOR="code --wait"
export LANG="en_GB.UTF-8"
export LC_ALL="en_GB.UTF-8"

# -- Powerlevel10k Config ------------------------------------------------------
# To customise prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
ZSHRC

log_success ".zshrc configured"
log_info "Run 'p10k configure' on first terminal launch to set up your prompt style"

# -- Set ZSH as default shell --------------------------------------------------
log_header "Default Shell"

BREW_ZSH="/opt/homebrew/bin/zsh"
if [[ "$SHELL" == "$BREW_ZSH" ]]; then
	log_skip "Homebrew zsh is already the default shell"
else
	# Add Homebrew zsh to allowed shells if not already there
	if ! grep -q "$BREW_ZSH" /etc/shells; then
		echo "$BREW_ZSH" | sudo tee -a /etc/shells >/dev/null
		log_info "Added Homebrew zsh to /etc/shells"
	fi
	chsh -s "$BREW_ZSH"
	log_success "Default shell set to Homebrew zsh"
fi

# -- VS Code Extensions -------------------------------------------------------
log_header "VS Code Extensions"

VSCODE_EXTENSIONS=(
	anthropic.claude-code              # Claude Code extension
	ms-python.python                   # Python language support
	charliermarsh.ruff                 # Ruff linter/formatter
	DavidAnson.vscode-markdownlint     # Markdownlint (uses markdownlint-cli2)
	timonwong.shellcheck               # ShellCheck linting for shell scripts
	mkhl.shfmt                         # Shell script formatter
	eamodio.gitlens                    # Git supercharged
	vivaxy.vscode-conventional-commits # Guided conventional commit UI
	zhuangtongfa.material-theme        # One Dark Pro theme
)

for ext in "${VSCODE_EXTENSIONS[@]}"; do
	if code --list-extensions 2>/dev/null | grep -qi "$ext"; then
		log_skip "VS Code extension: $ext"
	else
		log_info "Installing VS Code extension: $ext..."
		code --install-extension "$ext" --force 2>/dev/null || log_warn "Could not install $ext (VS Code may need to be opened first)"
	fi
done

# -- VS Code Settings ---------------------------------------------------------
log_header "VS Code Settings (Global)"

VSCODE_SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$VSCODE_SETTINGS_DIR"

# Back up existing settings if present and not ours
if [[ -f "$VSCODE_SETTINGS_DIR/settings.json" ]] && ! grep -q "Managed by setup.sh" "$VSCODE_SETTINGS_DIR/settings.json"; then
	cp "$VSCODE_SETTINGS_DIR/settings.json" "$VSCODE_SETTINGS_DIR/settings.json.backup.$(date +%Y%m%d%H%M%S)"
	log_info "Existing VS Code settings.json backed up"
fi

cat >"$VSCODE_SETTINGS_DIR/settings.json" <<'VSCODE_SETTINGS'
{
  // Managed by setup.sh

  // ==========================================================================
  // EDITOR — Core editing behaviour
  // ==========================================================================

  // Font: FiraCode-Retina for editor (ligatures), MesloLGS NF for terminal (powerline)
  "editor.fontFamily": "FiraCode-Retina, Menlo, Monaco, 'Courier New', monospace",
  "editor.fontLigatures": true,
  "editor.fontSize": 14,
  "editor.lineHeight": 1.6,

  // Indentation
  "editor.tabSize": 4,
  "editor.insertSpaces": true,
  "editor.detectIndentation": false,

  // Whitespace and formatting
  "editor.renderWhitespace": "all",
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "files.trimFinalNewlines": true,

  // Line length guide (80 = traditional, 120 = readable on wide screens)
  "editor.rulers": [80, 120],

  // Word wrap off for code (use rulers as visual guide instead)
  "editor.wordWrap": "off",

  // Cursor and scrolling
  "editor.cursorBlinking": "smooth",
  "editor.smoothScrolling": true,
  "editor.stickyScroll.enabled": true,

  // Bracket handling
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": "active",

  // Minimap — off (saves horizontal space, especially over Screen Sharing)
  "editor.minimap.enabled": false,

  // Suggestions and autocomplete
  "editor.suggestSelection": "first",
  "editor.acceptSuggestionOnCommitCharacter": false,
  "editor.quickSuggestions": {
    "other": "on",
    "comments": "off",
    "strings": "off"
  },

  // ==========================================================================
  // FILES — Global file behaviour
  // ==========================================================================

  "files.autoSave": "off",
  "files.encoding": "utf8",

  // Exclude clutter from explorer and search
  "files.exclude": {
    "**/__pycache__": true,
    "**/.pytest_cache": true,
    "**/.mypy_cache": true,
    "**/.ruff_cache": true,
    "**/*.pyc": true,
    "**/.DS_Store": true,
    "**/.git": true,
    "**/node_modules": true,
    "**/.venv": true
  },
  "search.exclude": {
    "**/.venv": true,
    "**/node_modules": true,
    "**/__pycache__": true,
    "**/uv.lock": true
  },

  // ==========================================================================
  // PYTHON — uv + ruff as the primary toolchain
  // ==========================================================================

  // Ruff as the sole formatter and linter (replaces Black, Flake8, isort, pylint)
  "[python]": {
    "editor.defaultFormatter": "charliermarsh.ruff",
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.fixAll.ruff": "explicit",
      "source.organizeImports.ruff": "explicit"
    }
  },

  // Ruff extension settings
  "ruff.configurationPreference": "filesystemFirst",
  "ruff.fixAll": true,
  "ruff.organizeImports": true,

  // Python analysis
  "python.analysis.autoImportCompletions": true,
  "python.analysis.typeCheckingMode": "basic",

  // ==========================================================================
  // MARKDOWN — markdownlint
  // ==========================================================================

  "[markdown]": {
    "editor.defaultFormatter": "DavidAnson.vscode-markdownlint",
    "editor.formatOnSave": true,
    "editor.wordWrap": "on",
    "editor.rulers": []
  },

  // ==========================================================================
  // SHELL — shellcheck + shfmt
  // ==========================================================================

  "[shellscript]": {
    "editor.tabSize": 2,
    "editor.defaultFormatter": "mkhl.shfmt",
    "editor.formatOnSave": true
  },

  "shellcheck.executablePath": "/opt/homebrew/bin/shellcheck",
  "shellcheck.run": "onSave",

  // ==========================================================================
  // JSON / YAML / TOML — common config file formatting
  // ==========================================================================

  "[json]": {
    "editor.defaultFormatter": "vscode.json-language-features",
    "editor.formatOnSave": true,
    "editor.tabSize": 2
  },
  "[jsonc]": {
    "editor.defaultFormatter": "vscode.json-language-features",
    "editor.formatOnSave": true,
    "editor.tabSize": 2
  },
  "[yaml]": {
    "editor.tabSize": 2,
    "editor.formatOnSave": true
  },
  "[toml]": {
    "editor.tabSize": 2
  },

  // ==========================================================================
  // CLAUDE CODE — terminal mode, not the GUI widget
  // ==========================================================================

  "claudeCode.useTerminal": true,

  // ==========================================================================
  // GIT — Source control settings
  // ==========================================================================

  "git.autofetch": true,
  "git.confirmSync": false,
  "git.enableSmartCommit": true,
  "git.pruneOnFetch": true,
  "scm.defaultViewMode": "tree",
  "git.openRepositoryInParentFolders": "always",

  // ==========================================================================
  // TERMINAL — iTerm2 as external, MesloLGS NF for powerline in integrated
  // ==========================================================================

  "terminal.external.osxExec": "iTerm.app",
  "terminal.integrated.defaultProfile.osx": "zsh",
  "terminal.integrated.fontFamily": "MesloLGS NF",
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.scrollback": 10000,
  "terminal.integrated.cursorStyle": "line",
  "terminal.integrated.cursorBlinking": true,

  // ==========================================================================
  // EXPLORER and WORKBENCH
  // ==========================================================================

  "workbench.colorTheme": "One Dark Pro",
  "workbench.startupEditor": "none",
  "workbench.editor.enablePreview": true,
  "workbench.sideBar.location": "left",
  "workbench.tree.indent": 16,
  "explorer.confirmDelete": false,
  "explorer.confirmDragAndDrop": false,
  "explorer.compactFolders": false,

  // ==========================================================================
  // TELEMETRY — off
  // ==========================================================================

  "telemetry.telemetryLevel": "off",
  "redhat.telemetry.enabled": false,

  // ==========================================================================
  // EXTENSIONS — GitLens
  // ==========================================================================

  "gitlens.codeLens.enabled": false,
  "gitlens.currentLine.enabled": true,
  "gitlens.hovers.currentLine.over": "line",
  "gitlens.statusBar.enabled": true
}
VSCODE_SETTINGS

log_success "VS Code settings.json installed"

# -- Project Templates ---------------------------------------------------------
log_header "Project Templates"

# =============================================================================
# GENERIC template — baseline for any git repo
# =============================================================================
GENERIC_DIR="$HOME/.project-templates/generic"
mkdir -p "$GENERIC_DIR/.vscode"

# lefthook.yml (generic — markdown, shell, commitlint only)
cat >"$GENERIC_DIR/lefthook.yml" <<'LEFTHOOK'
# lefthook.yml — Git hooks baseline (markdownlint + shellcheck + commitlint)
# Install hooks: lefthook install
# Run manually:  lefthook run pre-commit

pre-commit:
  parallel: true
  jobs:
    - name: markdownlint
      glob: "*.md"
      run: markdownlint-cli2 {staged_files}

    - name: shellcheck
      glob: "*.sh"
      run: shellcheck {staged_files}

    - name: shfmt
      glob: "*.sh"
      run: shfmt -d {staged_files}
      stage_fixed: true

commit-msg:
  jobs:
    - name: commitlint
      run: commitlint --edit {1}
LEFTHOOK

# commitlint.config.mjs
cat >"$GENERIC_DIR/commitlint.config.mjs" <<'COMMITLINT'
// commitlint.config.mjs — Conventional Commits enforcement
// Uses @commitlint/config-conventional (installed globally via npm)
// Valid format: type(scope): subject
// Examples:  feat: add auth  |  fix(api): resolve null pointer  |  docs: update README

export default {
  extends: ["@commitlint/config-conventional"],
  rules: {
    // Override: max header length 100 (default is 72)
    "header-max-length": [2, "always", 100],
  },
};
COMMITLINT

# .markdownlint-cli2.jsonc
cat >"$GENERIC_DIR/.markdownlint-cli2.jsonc" <<'MDLINT'
{
  "MD013": { "line_length": 120 },
  "MD033": false,
  "MD041": false
}
MDLINT

# .gitignore (generic)
cat >"$GENERIC_DIR/.gitignore" <<'GITIGNORE'
# IDE
.vscode/*
!.vscode/settings.json
!.vscode/extensions.json
!.vscode/launch.json

# OS
.DS_Store
Thumbs.db

# Lefthook local overrides (personal, not committed)
lefthook-local.yml

# Environment
.env
.env.*

# Node
node_modules/
GITIGNORE

# .vscode/settings.json (generic workspace — intentionally minimal)
cat >"$GENERIC_DIR/.vscode/settings.json" <<'VSCODE_WS'
{
  // Generic workspace settings
  // Global settings handle: editor, font, terminal, Claude Code, Git, etc.
  // Add project-specific overrides here.
}
VSCODE_WS

# .vscode/extensions.json (generic recommendations)
cat >"$GENERIC_DIR/.vscode/extensions.json" <<'VSCODE_EXT'
{
  "recommendations": [
    "anthropic.claude-code",
    "DavidAnson.vscode-markdownlint",
    "timonwong.shellcheck",
    "mkhl.shfmt",
    "eamodio.gitlens",
    "vivaxy.vscode-conventional-commits"
  ]
}
VSCODE_EXT

log_success "Generic template installed to ~/.project-templates/generic/"

# =============================================================================
# PYTHON template — extends generic with uv + ruff tooling
# =============================================================================
PYTHON_DIR="$HOME/.project-templates/python"
mkdir -p "$PYTHON_DIR/.vscode"

# Start by copying generic as the base
cp -r "$GENERIC_DIR/." "$PYTHON_DIR/"

# lefthook.yml (Python — adds ruff on top of generic hooks)
cat >"$PYTHON_DIR/lefthook.yml" <<'LEFTHOOK'
# lefthook.yml — Git hooks for Python projects (uv + ruff + markdownlint + shellcheck)
# Install hooks: lefthook install
# Run manually:  lefthook run pre-commit

pre-commit:
  parallel: true
  jobs:
    - name: ruff format
      glob: "*.py"
      run: ruff format {staged_files}
      stage_fixed: true

    - name: ruff check
      glob: "*.py"
      run: ruff check --fix {staged_files}
      stage_fixed: true

    - name: markdownlint
      glob: "*.md"
      run: markdownlint-cli2 {staged_files}

    - name: shellcheck
      glob: "*.sh"
      run: shellcheck {staged_files}

    - name: shfmt
      glob: "*.sh"
      run: shfmt -d {staged_files}
      stage_fixed: true

commit-msg:
  jobs:
    - name: commitlint
      run: commitlint --edit {1}
LEFTHOOK

# ruff.toml
cat >"$PYTHON_DIR/ruff.toml" <<'RUFF'
# ruff.toml — Project-level ruff configuration
line-length = 88
target-version = "py312"

[lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort (import sorting)
    "N",    # pep8-naming
    "UP",   # pyupgrade
    "B",    # flake8-bugbear
    "SIM",  # flake8-simplify
    "RUF",  # ruff-specific rules
]
ignore = ["E501"]
fixable = ["ALL"]

[lint.isort]
known-first-party = []

[lint.per-file-ignores]
"__init__.py" = ["F401"]
"tests/**" = ["S101"]

[format]
quote-style = "double"
line-ending = "lf"
RUFF

# .gitignore (Python — extends generic)
cat >"$PYTHON_DIR/.gitignore" <<'GITIGNORE'
# Python
__pycache__/
*.py[cod]
*$py.class
*.egg-info/
dist/
build/
*.egg

# Virtual environments
.venv/

# Ruff
.ruff_cache/

# Testing
.pytest_cache/
.coverage
htmlcov/
.mypy_cache/

# IDE
.vscode/*
!.vscode/settings.json
!.vscode/extensions.json
!.vscode/launch.json

# OS
.DS_Store

# Node
node_modules/

# Lefthook local overrides
lefthook-local.yml

# Environment
.env
.env.*
GITIGNORE

# .vscode/settings.json (Python workspace)
cat >"$PYTHON_DIR/.vscode/settings.json" <<'VSCODE_WS'
{
  // -- Python interpreter (uv-managed) ----------------------------------------
  // Uncomment and adjust after running `uv sync`:
  // "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",

  // -- Testing ----------------------------------------------------------------
  "python.testing.pytestEnabled": true,
  "python.testing.unittestEnabled": false,
  "python.testing.pytestArgs": ["tests"],

  // -- Files ------------------------------------------------------------------
  "files.exclude": {
    "**/__pycache__": true,
    "**/.pytest_cache": true,
    "**/.mypy_cache": true,
    "**/.ruff_cache": true,
    "**/*.pyc": true,
    "**/.venv": true,
    "**/dist": true,
    "**/*.egg-info": true
  },
  "search.exclude": {
    "**/.venv": true,
    "**/__pycache__": true,
    "**/uv.lock": true,
    "**/dist": true
  }
}
VSCODE_WS

# .vscode/extensions.json (Python recommendations)
cat >"$PYTHON_DIR/.vscode/extensions.json" <<'VSCODE_EXT'
{
  "recommendations": [
    "anthropic.claude-code",
    "ms-python.python",
    "charliermarsh.ruff",
    "DavidAnson.vscode-markdownlint",
    "timonwong.shellcheck",
    "mkhl.shfmt",
    "eamodio.gitlens",
    "vivaxy.vscode-conventional-commits"
  ]
}
VSCODE_EXT

# .vscode/launch.json (Python debug configs)
cat >"$PYTHON_DIR/.vscode/launch.json" <<'VSCODE_LAUNCH'
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Python: Current File",
      "type": "debugpy",
      "request": "launch",
      "program": "${file}",
      "console": "integratedTerminal",
      "justMyCode": true
    },
    {
      "name": "Pytest: Current File",
      "type": "debugpy",
      "request": "launch",
      "module": "pytest",
      "args": ["${file}", "-v"],
      "console": "integratedTerminal",
      "justMyCode": true
    },
    {
      "name": "Pytest: All",
      "type": "debugpy",
      "request": "launch",
      "module": "pytest",
      "args": ["tests/", "-v"],
      "console": "integratedTerminal",
      "justMyCode": true
    }
  ]
}
VSCODE_LAUNCH

log_success "Python template installed to ~/.project-templates/python/"
log_info "Use 'newproject <name> [python]' to scaffold a project"

# -- tmux Configuration -------------------------------------------------------
log_header "tmux Configuration"

cat >"$HOME/.tmux.conf" <<'TMUX'
# -- General -------------------------------------------------------------------
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set -g history-limit 50000
set -g mouse on

# -- Prefix key ----------------------------------------------------------------
# Keep default Ctrl-b (change to Ctrl-a if you prefer)
# unbind C-b
# set -g prefix C-a
# bind C-a send-prefix

# -- Window and pane management ------------------------------------------------
# Split panes with | and -
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# New windows keep the current path
bind c new-window -c "#{pane_current_path}"

# Start window numbering at 1
set -g base-index 1
setw -g pane-base-index 1

# Renumber windows when one is closed
set -g renumber-windows on

# -- Status bar ----------------------------------------------------------------
set -g status-position bottom
set -g status-interval 5
set -g status-left-length 30
set -g status-right-length 60
set -g status-left '#[fg=green,bold] #S '
set -g status-right '#[fg=yellow] %H:%M #[fg=white]│ #[fg=cyan]%d %b '

# -- Quality of life -----------------------------------------------------------
# Don't wait for escape sequences (faster response)
set -sg escape-time 0

# Activity monitoring
setw -g monitor-activity on
set -g visual-activity off
TMUX

log_success ".tmux.conf configured"

# -- iTerm2 Configuration -----------------------------------------------------
log_header "iTerm2 Configuration"

# Set iTerm2 as the default terminal
# (registers as handler for .command, .sh, and terminal:// URLs)
defaults write com.googlecode.iterm2 "Default Terminal" -bool true
log_success "iTerm2 set as default terminal"

# Don't prompt when quitting
defaults write com.googlecode.iterm2 PromptOnQuit -bool false
log_success "Quit confirmation disabled"

# Don't warn when closing a session with a running process
defaults write com.googlecode.iterm2 NeverWarnAboutShortLivedSessions_selection -int 0
log_success "Short-lived session warning disabled"

# Silence the bell (you're headless, nobody's listening)
defaults write com.googlecode.iterm2 SilenceBell -bool true
log_success "Terminal bell silenced"

# Unlimited scrollback
defaults write com.googlecode.iterm2 UnlimitedScrollback -bool true
log_success "Unlimited scrollback enabled"

# Note: iTerm2 needs to be launched once before some preferences take full effect.
# On first Screen Sharing session, open iTerm2 manually to finalise setup.
log_info "Open iTerm2 once via Screen Sharing to finalise default terminal registration"

# -- Rectangle Configuration ---------------------------------------------------
log_header "Rectangle Configuration"

# Launch at login and skip first-launch dialog
defaults write com.knollsoft.Rectangle launchOnLogin -bool true
defaults write com.knollsoft.Rectangle SUHasLaunchedBefore -bool true
log_success "Rectangle: launch at login enabled"

# Custom shortcuts: Cmd+Arrow for window halves/maximize
# Note: this overrides macOS text navigation (Home/End) in text fields
defaults write com.knollsoft.Rectangle leftHalf -dict keyCode -int 123 modifierFlags -int 1048576
defaults write com.knollsoft.Rectangle rightHalf -dict keyCode -int 124 modifierFlags -int 1048576
defaults write com.knollsoft.Rectangle maximize -dict keyCode -int 126 modifierFlags -int 1048576
defaults write com.knollsoft.Rectangle bottomHalf -dict keyCode -int 125 modifierFlags -int 1048576
log_success "Rectangle: Cmd+Arrow shortcuts configured"
log_warn "Cmd+Arrow overrides macOS text navigation (Home/End) in text fields"
log_info "Rectangle requires Accessibility permissions — grant via System Settings on first launch"

# -- macOS Defaults (headless server optimisations) ----------------------------
log_header "macOS Defaults (Headless Optimisations)"

# Disable Spotlight indexing (saves SSD writes, not needed on a headless server)
sudo mdutil -a -i off &>/dev/null
log_success "Spotlight indexing disabled"

# Disable the "Are you sure you want to open this application?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false
log_success "Gatekeeper first-launch dialog disabled"

# Disable auto-correct and smart quotes (causes issues in terminal and code)
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
log_success "Auto-correct and smart punctuation disabled"

# Finder: show hidden files (useful when Screen Sharing in)
defaults write com.apple.finder AppleShowAllFiles -bool true
log_success "Finder: hidden files visible"

# Prevent Photos from opening when connecting devices
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
log_success "Photos auto-launch disabled"

# Disable App Nap (prevents macOS from throttling background apps)
defaults write NSGlobalDomain NSAppSleepDisabled -bool true
log_success "App Nap disabled"

# Prevent Time Machine from prompting to use new drives as backup
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
log_success "Time Machine new disk prompts disabled"

# -- Summary -------------------------------------------------------------------
log_header "Setup Complete"

echo -e "${GREEN}${BOLD}Everything is installed and configured.${NC}\n"
echo -e "Next steps:"
echo -e "  1. Open iTerm2 (to finalise default terminal registration)"
echo -e "  2. iTerm2 → Settings → Profiles → Text → Font → set to ${BOLD}MesloLGS NF${NC}"
echo -e "  3. Run ${BOLD}exec zsh${NC} — Powerlevel10k wizard will launch automatically"
echo -e "  4. Run ${BOLD}ta${NC} to start a tmux session named 'main'"
echo -e "  5. Open Claude Desktop and sign in with your Anthropic account"
echo -e "  6. Run ${BOLD}claude${NC} in terminal to authenticate Claude Code"
echo -e "  7. Open VS Code and sign in to the Claude Code extension"
echo -e "  8. Sign in to Brave, Notion, and Todoist"
echo -e "  9. Grant Accessibility permissions to Rectangle (System Settings → Privacy & Security → Accessibility)"
echo -e " 10. Configure BetterDisplay for your preferred virtual display resolution"
echo -e ""
echo -e "Useful commands:"
echo -e "  ${BOLD}ta${NC}              — attach to tmux session 'main' (or create it)"
echo -e "  ${BOLD}brewup${NC}          — update all Homebrew packages"
echo -e "  ${BOLD}syscheck${NC}        — quick system health check (uptime, disk, memory)"
echo -e "  ${BOLD}cc${NC}              — launch Claude Code"
echo -e "  ${BOLD}p10k configure${NC}  — re-run Powerlevel10k prompt wizard"
echo -e "  ${BOLD}newproject foo${NC}        — scaffold a generic repo with lefthook, commitlint"
echo -e "  ${BOLD}newproject foo python${NC} — scaffold a Python project with uv, ruff, pytest"
echo -e ""
echo -e "${YELLOW}Note:${NC} Some macOS default changes require a logout/restart to take effect."
echo -e "Since this is a headless server, a reboot is recommended: ${BOLD}sudo reboot${NC}"
echo -e ""
echo -e "${YELLOW}Important:${NC} Grant Full Disk Access to iTerm and VS Code before going headless."
echo -e "  System Settings → Privacy & Security → Full Disk Access → add iTerm + Visual Studio Code"
echo -e "  Without this, macOS will pop permission dialogs that block the apps when no one is at the screen."
