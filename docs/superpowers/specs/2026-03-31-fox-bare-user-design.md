# Fox V2 — Bare User on Shen (replacing Docker)

## Problem

Docker adds unnecessary complexity and overhead for fox's use case. The primary threat (DataArt MDM on Mac) is addressed by running on shen regardless of whether it's Docker or bare. CPU starvation from other containers, systemd-in-Docker headaches, 20-minute image rebuilds, and pam_nologin bugs made Docker more pain than value.

## Solution

A dedicated `fox` user on shen with nix home-manager (standalone). Same shared configs as the Docker version. Direct SSH access on shen's existing port 2201.

## What stays from V1

- `flake.nix` — `homeConfigurations.fox` (x86_64-linux, standalone home-manager)
- `home/` — all parameterized configs (fish.nix, tmux.nix, git.nix, direnv.nix, default.nix)
- `hosts/fox/doctor.sh` — health checks (modified)
- `hosts/fox/bootstrap.sh` — setup script (rewritten)
- `hosts/fox/defaults/bashrc` — fish trampoline
- `scripts/fox-connect.sh` — iTerm2 tmux -CC connector (modified)
- `scripts/fox-connect.fish` — completions (modified)

## What gets deleted

- `hosts/fox/Dockerfile`
- `hosts/fox/docker-compose.yml`
- `hosts/fox/.env.example`
- `hosts/fox/.gitignore`
- `hosts/fox/systemd/fox-ssh-keys.service`
- `hosts/fox/defaults/with-nix-daemon` (only needed for Docker build)

## Connectivity

Mac SSH config:
```
Host fox
    HostName shen.your-tailnet.ts.net
    Port 2201
    User fox
```

No port mapping, no Tailscale IP in .env, no Docker networking.

## bootstrap.sh (fox)

Full setup script, run once as the `fox` user on shen:

```bash
#!/usr/bin/env bash
# One-time setup for fox (bare user on shen). Idempotent — safe to re-run.
set -euo pipefail

REPO="$HOME/nixos-config"

echo "==> Nix"
if command -v nix &> /dev/null; then
  echo "  Already installed ($(nix --version))"
else
  echo "  Installing..."
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install linux \
    --no-confirm
fi

echo "==> nixos-config"
if [ -d "$REPO" ]; then
  echo "  Already cloned, pulling..."
  git -C "$REPO" pull
else
  git clone https://github.com/iorlas/nixos-config.git "$REPO"
fi

echo "==> Home Manager"
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
if command -v home-manager &> /dev/null; then
  echo "  Switching..."
  home-manager switch --flake "$REPO#fox"
else
  echo "  First install..."
  nix run home-manager/master -- switch --flake "$REPO#fox"
fi

echo "==> SSH authorized keys"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
curl -fsSL https://github.com/iorlas.keys > "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"
echo "  $(wc -l < "$HOME/.ssh/authorized_keys") keys installed"

echo "==> Bash → Fish trampoline"
if [ ! -f "$HOME/.bashrc" ] || ! grep -q "FISH_STARTED" "$HOME/.bashrc"; then
  cp "$REPO/hosts/fox/defaults/bashrc" "$HOME/.bashrc"
  echo "  Installed"
else
  echo "  Already configured"
fi

echo "==> Claude Code"
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global" 2>/dev/null
export PATH="$HOME/.npm-global/bin:$HOME/.nix-profile/bin:$PATH"
if command -v claude &> /dev/null; then
  echo "  Already installed ($(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1))"
else
  echo "  Installing..."
  npm install -g @anthropic-ai/claude-code
fi

echo ""
echo "==> Running doctor..."
"$HOME/.local/bin/doctor"
```

## doctor.sh (fox)

```bash
#!/usr/bin/env bash
# Health check for fox (bare user on shen).
set -uo pipefail

FIX=false
[[ "${1:-}" == "--fix" ]] && FIX=true

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
DIM='\033[2m'
NC='\033[0m'
ISSUES=0

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}→${NC} $1"; ISSUES=$((ISSUES + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ISSUES=$((ISSUES + 1)); }
hint() { echo -e "    ${DIM}$1${NC}"; }

# ─── Nix ──────────────────────────────────────────────────────────────────────

echo "==> Nix"
if command -v nix &> /dev/null; then
  ok "$(nix --version)"
else
  fail "Nix not installed"
  hint "Run: bootstrap"
fi

# ─── Home Manager ─────────────────────────────────────────────────────────────

echo "==> Home Manager"
if command -v home-manager &> /dev/null; then
  HM_GEN=$(home-manager generations 2>/dev/null | head -1 || echo "unknown")
  ok "Active: $HM_GEN"
else
  fail "home-manager not on PATH"
  hint "Run: bootstrap"
fi

# ─── Claude Code ───────────────────────────────────────────────────────────────

echo "==> Claude Code"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$HOME/.nix-profile/bin:$PATH"
if command -v claude &> /dev/null; then
  CLAUDE_VER=$(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  ok "Installed ($CLAUDE_VER)"
else
  fail "Not installed"
  hint "Run: npm install -g @anthropic-ai/claude-code"
fi

if [ -d "$HOME/.claude" ] && [ -f "$HOME/.claude/.credentials.json" ]; then
  ok "Authenticated"
else
  warn "Not authenticated"
  hint "Run: claude (first-run opens browser auth)"
fi

# ─── GitHub CLI ───────────────────────────────────────────────────────────────

echo "==> GitHub CLI"
if command -v gh &> /dev/null; then
  if gh auth status &>/dev/null; then
    GH_USER=$(gh api user -q .login 2>/dev/null || echo "unknown")
    ok "Authenticated as $GH_USER"
  else
    warn "Not authenticated"
    hint "Run: gh auth login"
  fi
else
  fail "gh not installed"
fi

# ─── Docker ────────────────────────────────────────────────────────────────────

echo "==> Docker"
if command -v docker &> /dev/null; then
  if docker info &>/dev/null; then
    ok "Docker $(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  else
    warn "Docker not accessible (check group membership)"
    hint "Run: sudo usermod -aG docker fox && newgrp docker"
  fi
else
  fail "Docker not found"
  hint "Docker should be installed on shen host"
fi

# ─── SSH Keys ─────────────────────────────────────────────────────────────────

echo "==> SSH Keys"
if [ -f "$HOME/.ssh/authorized_keys" ]; then
  KEY_COUNT=$(wc -l < "$HOME/.ssh/authorized_keys")
  ok "$KEY_COUNT authorized key(s)"
else
  warn "No authorized_keys"
  hint "Run: curl -fsSL https://github.com/iorlas.keys > ~/.ssh/authorized_keys"
fi

# ─── Fish Shell ───────────────────────────────────────────────────────────────

echo "==> Fish Shell"
if [ -x "$HOME/.nix-profile/bin/fish" ]; then
  ok "Fish available"
else
  warn "Fish not found in nix profile"
  hint "Run: nrs (home-manager switch)"
fi

if [ -f "$HOME/.bashrc" ] && grep -q "FISH_STARTED" "$HOME/.bashrc"; then
  ok "Bash → Fish trampoline configured"
else
  warn "Bash → Fish trampoline missing"
  hint "Run: cp ~/nixos-config/hosts/fox/defaults/bashrc ~/.bashrc"
fi

# ─── Nix ad-hoc packages ─────────────────────────────────────────────────────

echo "==> Nix ad-hoc packages"
ADHOC=$(nix-env -q 2>/dev/null || echo "")
if [ -z "$ADHOC" ]; then
  ok "No ad-hoc packages (clean)"
else
  warn "Ad-hoc packages installed (not in config, add to home.packages to persist):"
  echo "$ADHOC" | while read -r pkg; do
    echo -e "    ${YELLOW}•${NC} $pkg"
  done
fi

# ─── Summary ───────────────────────────────────────────────────────────────────

echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo -e "${GREEN}All good.${NC}"
else
  echo -e "${YELLOW}$ISSUES issue(s) found.${NC}"
fi
```

## fox-connect.sh

```bash
#!/usr/bin/env bash
# Connect to tmux sessions on fox via iTerm2 tmux -CC integration.
set -uo pipefail

HOST="fox"
SESSION="${1:-}"
DIR="${2:-}"

if [ -n "$SESSION" ]; then
  DIR="${DIR:-~/Workspaces/$SESSION}"
  ssh "$HOST" "mkdir -p $DIR" 2>/dev/null
  echo "→ Connecting to $SESSION ($DIR)..."
  exec ssh "$HOST" -t "tmux -CC new-session -A -s $SESSION -c $DIR"
fi

SESSIONS=$(ssh "$HOST" "tmux list-sessions -F '#S'" 2>/dev/null || echo "")

if [ -z "$SESSIONS" ]; then
  echo "→ No sessions found. Creating default session..."
  exec ssh "$HOST" -t "tmux -CC new-session -s main"
fi

echo "→ Reconnecting $(echo "$SESSIONS" | wc -l | tr -d ' ') session(s)..."
FIRST=$(echo "$SESSIONS" | head -1)
exec ssh "$HOST" -t "tmux -CC attach -t $FIRST"
```

## fox-connect.fish

```fish
# Fish completions for fox-connect
complete -c fox-connect -f -a '(ssh fox tmux list-sessions -F "#S" 2>/dev/null)'
complete -c fox-connect -f -a '(ssh fox ls ~/Workspaces/ 2>/dev/null)'
```

## Setup Sequence (on shen)

1. `sudo useradd -m -s /bin/bash -G sudo,docker fox`
2. `sudo passwd -d fox` (no password, SSH key only)
3. `sudo -u fox bash ~/nixos-config/hosts/fox/bootstrap.sh` (or clone first)
4. From Mac: add SSH config, test `ssh fox`
5. Inside fox: `gh auth login`, `claude`

## File Operations

### Deleted (5)
- `hosts/fox/Dockerfile`
- `hosts/fox/docker-compose.yml`
- `hosts/fox/.env.example`
- `hosts/fox/.gitignore`
- `hosts/fox/systemd/fox-ssh-keys.service`
- `hosts/fox/defaults/with-nix-daemon`

### Rewritten (3)
- `hosts/fox/bootstrap.sh` — full setup script
- `hosts/fox/doctor.sh` — bare-user health checks
- `scripts/fox-connect.sh` — HOST="fox", no port override

### Modified (1)
- `scripts/fox-connect.fish` — ssh fox instead of ssh fox with port

### Unchanged (all nix configs)
- `flake.nix`, `home/`, `hosts/fox/defaults/bashrc`
