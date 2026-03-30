# Fox Dev Container Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Docker-based isolated dev environment ("fox") to the nixos-config repo, deployable on shen VPS.

**Architecture:** Single privileged Docker container with systemd as PID 1, running sshd + dockerd + nix home-manager. Shared nix home configs with pix, parameterized by `hostName`. SSH access via shen's existing Tailscale, port 2222.

**Tech Stack:** Docker, systemd, Nix (Determinate Systems installer), home-manager (standalone), fish, tmux, Ubuntu 24.04

**Spec:** `docs/superpowers/specs/2026-03-30-fox-dev-container-design.md`

---

## File Structure

### Modified files
- `flake.nix` — add `homeConfigurations.fox`, add `extraSpecialArgs` to pix
- `home/default.nix` — accept `hostName`, host-specific scripts, add `home.packages`
- `home/cli/fish.nix` — accept `hostName`/`lib`, conditionalize nrs alias and exit node guard
- `home/cli/tmux.nix` — accept `hostName`, parameterize title string
- `README.md` — add fox section

### Moved files
- `bootstrap.sh` → `hosts/pix/bootstrap.sh`
- `doctor.sh` → `hosts/pix/doctor.sh`

### New files
- `hosts/fox/Dockerfile`
- `hosts/fox/docker-compose.yml`
- `hosts/fox/.env.example`
- `hosts/fox/.gitignore`
- `hosts/fox/bootstrap.sh`
- `hosts/fox/doctor.sh`
- `hosts/fox/systemd/fox-ssh-keys.service`
- `scripts/fox-connect.sh`
- `scripts/fox-connect.fish`

---

### Task 1: Move pix-specific scripts under hosts/pix/

**Files:**
- Move: `bootstrap.sh` → `hosts/pix/bootstrap.sh`
- Move: `doctor.sh` → `hosts/pix/doctor.sh`

- [ ] **Step 1: Create hosts/pix directory and move files**

```bash
cd ~/nixos-config
mkdir -p hosts/pix
git mv bootstrap.sh hosts/pix/bootstrap.sh
git mv doctor.sh hosts/pix/doctor.sh
```

- [ ] **Step 2: Update home/default.nix to reference new paths**

Change `home/default.nix` — update the source paths for bootstrap and doctor:

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./cli/git.nix
    ./cli/fish.nix
    ./cli/tmux.nix
    ./cli/direnv.nix
  ];

  home.username = "iorlas";
  home.homeDirectory = "/home/iorlas";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.file.".local/bin/bootstrap" = {
    source = ../hosts/pix/bootstrap.sh;
    executable = true;
  };
  home.file.".local/bin/doctor" = {
    source = ../hosts/pix/doctor.sh;
    executable = true;
  };
}
```

- [ ] **Step 3: Verify pix still builds**

```bash
nix flake check 2>&1 | head -20
```

Expected: no errors (warnings about unused args are OK at this stage).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: move bootstrap.sh and doctor.sh under hosts/pix/"
```

---

### Task 2: Parameterize tmux.nix with hostName

**Files:**
- Modify: `home/cli/tmux.nix`
- Modify: `flake.nix` (add extraSpecialArgs to pix)

- [ ] **Step 1: Update flake.nix to pass hostName to pix**

Replace the entire `flake.nix` with:

```nix
{
  description = "Dev environment configs — NixOS VMs and Docker containers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.pix = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./hosts/pix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.iorlas = import ./home;
          home-manager.extraSpecialArgs = { hostName = "pix"; };
        }
      ];
    };
  };
}
```

- [ ] **Step 2: Update home/cli/tmux.nix to accept and use hostName**

Replace the entire file with:

```nix
{ pkgs, hostName, ... }:

{
  programs.tmux = {
    enable = true;

    shell = "${pkgs.fish}/bin/fish";
    keyMode = "vi";
    mouse = true;
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    terminal = "tmux-256color";
    sensibleOnTop = true;
    clock24 = true;
    focusEvents = true;

    plugins = with pkgs.tmuxPlugins; [
      yank
      {
        plugin = better-mouse-mode;
        extraConfig = ''
          set -g @emulate-scroll-for-no-mouse-alternate-buffer "on"
        '';
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim "session"
          set -g @resurrect-capture-pane-contents "on"
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore "on"
          set -g @continuum-save-interval "10"
        '';
      }
    ];

    extraConfig = ''
      # True color (iTerm2)
      set -as terminal-overrides ",xterm-256color:RGB"

      # OSC 52 clipboard (works over SSH → local clipboard)
      set -s set-clipboard on

      # Window behavior
      set -g renumber-windows on

      # Window/terminal title — shows "session-name @ hostname"
      set -g set-titles on
      set -g set-titles-string "#S @ ${hostName}"
      set -g automatic-rename on

      # Don't kill sessions — detach instead of exit on window close
      set -g detach-on-destroy on
      set -g destroy-unattached off
      set -g exit-unattached off

      # Splits/windows inherit current directory
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # Vi copy mode
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-pipe-and-cancel

      # Pane navigation (no prefix)
      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      # Window navigation (no prefix)
      bind -n S-Left previous-window
      bind -n S-Right next-window

      # Pane resizing
      bind -n M-S-Left resize-pane -L 2
      bind -n M-S-Right resize-pane -R 2
      bind -n M-S-Up resize-pane -U 2
      bind -n M-S-Down resize-pane -D 2

      # Minimal status bar
      set -g status-position top
      set -g status-style "bg=default,fg=default"
      set -g status-left "#[bold] #S "
      set -g status-left-length 20
      set -g status-right ""
      set -g window-status-format "#[dim] #I:#W "
      set -g window-status-current-format "#[bold] #I:#W "
      set -g window-status-separator ""
      set -g pane-border-style "fg=colour240"
      set -g pane-active-border-style "fg=colour4"
    '';
  };
}
```

- [ ] **Step 3: Verify flake evaluates**

```bash
nix flake check 2>&1 | head -20
```

- [ ] **Step 4: Commit**

```bash
git add flake.nix home/cli/tmux.nix
git commit -m "feat: parameterize tmux title with hostName"
```

---

### Task 3: Parameterize fish.nix with hostName

**Files:**
- Modify: `home/cli/fish.nix`

- [ ] **Step 1: Replace home/cli/fish.nix with parameterized version**

Replace the entire file with:

```nix
{ config, pkgs, lib, hostName, ... }:

let
  isPix = hostName == "pix";
in
{
  programs.fish = {
    enable = true;

    shellInit = ''
      # Local scripts (bootstrap, doctor) + Claude Code (npm global)
      set -gx PATH $HOME/.local/bin $HOME/.npm-global/bin $PATH

      # fnm (Node version manager)
      fnm env --use-on-cd --shell fish | source

      # iTerm2 shell integration through tmux
      set -gx ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX YES

      # Source iTerm2 shell integration (installed on first bootstrap)
      test -e $HOME/.iterm2_shell_integration.fish && source $HOME/.iterm2_shell_integration.fish
    '';

    interactiveShellInit = ''
      # Colors
      set -g fish_color_autosuggestion brblack
      set -g fish_color_command green
      set -g fish_color_error red
      set -g fish_color_param blue

      # Tide prompt config (from tide configure)
      set -U tide_left_prompt_items pwd git newline character
      set -U tide_right_prompt_items status cmd_duration context jobs direnv node nix_shell time
      set -U tide_prompt_transient_enabled true
      set -U tide_prompt_add_newline_before false
      set -U tide_left_prompt_frame_enabled false
      set -U tide_right_prompt_frame_enabled false
      set -U tide_character_icon \u276f
      set -U tide_git_color_branch 5FD700
      set -U tide_git_color_dirty D7AF00
      set -U tide_git_color_untracked 00AFFF
      set -U tide_git_color_staged D7AF00
      set -U tide_pwd_color_anchors 00AFFF
      set -U tide_pwd_color_dirs 0087AF

      # Auto-attach tmux on interactive login (plain shell only)
      if status is-interactive; and not set -q TMUX
        exec tmux new-session -A -s main
      end
    '';

    shellAbbrs = {
      g = "git";
      ga = "git add";
      gc = "git commit";
      gco = "git checkout";
      gd = "git diff";
      gl = "git log --oneline";
      gp = "git push";
      gs = "git status";
      dc = "docker compose";
    };

    shellAliases = {
      nrs = if isPix
        then "sudo nixos-rebuild switch --flake /mnt/mac/Users/iorlas/nixos-config#pix --impure"
        else "home-manager switch --flake ~/nixos-config#fox";
    };

    functions = lib.mkMerge [
      # Shared functions (both hosts)
      {
        claude = {
          description = "Claude Code";
          body = if isPix then ''
            _check_exit_node; or return 1
            command claude $argv
          '' else ''
            command claude $argv
          '';
        };
        c = {
          description = "Claude Code shortcut";
          body = if isPix then ''
            _check_exit_node; or return 1
            command claude $argv
          '' else ''
            command claude $argv
          '';
        };
      }
      # Pix-only functions
      (lib.mkIf isPix {
        _check_exit_node = {
          description = "Block if traffic is not routed through shen";
          body = ''
            set -l exit_id (tailscale status -json 2>/dev/null | jq -r '.ExitNodeStatus.ID // empty' 2>/dev/null)
            if test -z "$exit_id"
              set_color red --bold
              echo "BLOCKED: traffic is not routed through shen."
              set_color normal
              echo "Run: doctor --fix"
              return 1
            end
          '';
        };
        fish_greeting = {
          description = "Check tailscale exit node on shell start";
          body = ''
            if command -q tailscale
              set -l exit_id (tailscale status -json 2>/dev/null | jq -r '.ExitNodeStatus.ID // empty' 2>/dev/null)
              if test -z "$exit_id"
                set_color -b red white --bold
                echo ""
                echo "  !! TRAFFIC IS NOT ROUTED THROUGH SHEN !!  "
                echo ""
                set_color normal
                set_color yellow
                echo "  run: doctor --fix"
                echo ""
                set_color normal
              end
            end
          '';
        };
      })
      # Fox-only functions
      (lib.mkIf (!isPix) {
        fish_greeting = {
          description = "Fox greeting";
          body = ''
            # No greeting on fox
          '';
        };
      })
    ];

    plugins = [
      { name = "tide"; src = pkgs.fishPlugins.tide.src; }
      { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
      { name = "done"; src = pkgs.fishPlugins.done.src; }
    ];
  };

  # Companion tools with native fish integration

  programs.zoxide = {
    enable = true;
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    flags = [ "--disable-up-arrow" ];
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [ "--height 40%" "--border" ];
  };

  programs.bat.enable = true;

  programs.eza = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.ripgrep.enable = true;
  programs.fd.enable = true;
}
```

- [ ] **Step 2: Verify flake evaluates**

```bash
nix flake check 2>&1 | head -20
```

- [ ] **Step 3: Commit**

```bash
git add home/cli/fish.nix
git commit -m "feat: parameterize fish.nix — nrs alias and exit node guard per host"
```

---

### Task 4: Update home/default.nix — hostName, dev tools, host-specific scripts

**Files:**
- Modify: `home/default.nix`

- [ ] **Step 1: Replace home/default.nix**

```nix
{ config, pkgs, hostName, ... }:

{
  imports = [
    ./cli/git.nix
    ./cli/fish.nix
    ./cli/tmux.nix
    ./cli/direnv.nix
  ];

  home.username = "iorlas";
  home.homeDirectory = "/home/iorlas";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.file.".local/bin/bootstrap" = {
    source = ../hosts/${hostName}/bootstrap.sh;
    executable = true;
  };
  home.file.".local/bin/doctor" = {
    source = ../hosts/${hostName}/doctor.sh;
    executable = true;
  };

  home.packages = with pkgs; [
    # Node.js
    nodejs_22
    fnm
    pnpm

    # Python
    uv
    python313
    pipx

    # JavaScript runtimes
    deno

    # Build tools
    gnumake
    gcc

    # Core CLI
    git
    gh
    curl
    wget
    jq
    yq
    btop
    nano
    unzip
    tree
    lazygit
    neovim

    # Linting / security
    gitleaks
    hadolint
    yamllint
  ];
}
```

Note: Using `nodejs_22` (verified to exist in nixpkgs-unstable) instead of `nodejs_24`.

- [ ] **Step 2: Verify pix flake still evaluates**

```bash
nix flake check 2>&1 | head -20
```

- [ ] **Step 3: Commit**

```bash
git add home/default.nix
git commit -m "feat: home/default.nix accepts hostName, adds dev tools to home.packages"
```

---

### Task 5: Add homeConfigurations.fox to flake.nix

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Update flake.nix to add fox configuration**

Replace the entire `flake.nix` with:

```nix
{
  description = "Dev environment configs — NixOS VMs and Docker containers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.pix = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./hosts/pix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.iorlas = import ./home;
          home-manager.extraSpecialArgs = { hostName = "pix"; };
        }
      ];
    };

    homeConfigurations.fox = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = { hostName = "fox"; };
      modules = [ ./home ];
    };
  };
}
```

- [ ] **Step 2: Create hosts/fox directory with bootstrap.sh and doctor.sh stubs**

These are needed because `home/default.nix` references `../hosts/fox/bootstrap.sh` and `../hosts/fox/doctor.sh` at evaluation time.

Create `hosts/fox/bootstrap.sh`:

```bash
#!/usr/bin/env bash
# First-run setup for fox (Docker dev container). Most tools baked into image.
set -euo pipefail

echo "==> Running doctor to check environment..."
doctor

echo ""
echo "==> First-time setup checklist:"
echo "  1. gh auth login     (GitHub CLI authentication)"
echo "  2. claude             (Claude Code first-run auth)"
echo ""
echo "Run these commands manually, then 'doctor' again to verify."
```

Create `hosts/fox/doctor.sh`:

```bash
#!/usr/bin/env bash
# Health check for fox (Docker dev container).
# Use --fix to auto-fix what can be fixed.
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
  NIX_VER=$(nix --version 2>/dev/null || echo "unknown")
  ok "$NIX_VER"
else
  fail "Nix not installed"
fi

# ─── Home Manager ─────────────────────────────────────────────────────────────

echo "==> Home Manager"
if command -v home-manager &> /dev/null; then
  HM_GEN=$(home-manager generations 2>/dev/null | head -1 || echo "unknown")
  ok "Active: $HM_GEN"
else
  fail "home-manager not on PATH"
  hint "Run: nix run home-manager/master -- switch --flake ~/nixos-config#fox"
fi

# ─── Claude Code ───────────────────────────────────────────────────────────────

echo "==> Claude Code"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$HOME/.nix-profile/bin:$PATH"
if command -v claude &> /dev/null; then
  CLAUDE_VER=$(claude --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  ok "Installed ($CLAUDE_VER)"
else
  fail "Not installed"
  hint "Run: pnpm add -g @anthropic-ai/claude-code"
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
    hint "Choose: GitHub.com → HTTPS → Login with browser"
  fi
else
  fail "gh not installed"
fi

# ─── Docker ────────────────────────────────────────────────────────────────────

echo "==> Docker"
if command -v docker &> /dev/null; then
  if docker info &>/dev/null; then
    DOCKER_VER=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    ok "Docker $DOCKER_VER"
  else
    fail "Docker daemon not responding"
    hint "Check: systemctl status docker"
  fi
else
  fail "Docker not installed"
fi

# ─── SSH ──────────────────────────────────────────────────────────────────────

echo "==> SSH"
if systemctl is-active --quiet ssh 2>/dev/null; then
  ok "sshd running"
else
  fail "sshd not running"
  hint "Check: systemctl status ssh"
fi

# ─── cgroup ───────────────────────────────────────────────────────────────────

echo "==> cgroup"
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
  ok "cgroupv2 available"
else
  warn "cgroupv2 not detected — systemd may have issues"
fi

# ─── Nix ad-hoc packages ─────────────────────────────────────────────────────

echo "==> Nix ad-hoc packages"
ADHOC=$(nix-env -q 2>/dev/null || echo "")
if [ -z "$ADHOC" ]; then
  ok "No ad-hoc packages (clean)"
else
  warn "Ad-hoc packages installed (not in config, will vanish on rebuild):"
  echo "$ADHOC" | while read -r pkg; do
    echo -e "    ${YELLOW}•${NC} $pkg"
  done
  hint "Add these to home/default.nix home.packages to persist them."
fi

# ─── Summary ───────────────────────────────────────────────────────────────────

echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo -e "${GREEN}All good.${NC}"
else
  echo -e "${YELLOW}$ISSUES issue(s) found.${NC}"
fi
```

- [ ] **Step 3: Verify both configurations evaluate**

```bash
nix flake check 2>&1 | head -20
```

- [ ] **Step 4: Commit**

```bash
git add flake.nix hosts/fox/bootstrap.sh hosts/fox/doctor.sh
git commit -m "feat: add homeConfigurations.fox to flake + fox bootstrap/doctor"
```

---

### Task 6: Create fox Docker files

**Files:**
- Create: `hosts/fox/Dockerfile`
- Create: `hosts/fox/docker-compose.yml`
- Create: `hosts/fox/.env.example`
- Create: `hosts/fox/.gitignore`
- Create: `hosts/fox/systemd/fox-ssh-keys.service`

- [ ] **Step 1: Create hosts/fox/systemd/fox-ssh-keys.service**

```bash
mkdir -p ~/nixos-config/hosts/fox/systemd
```

Create `hosts/fox/systemd/fox-ssh-keys.service`:

```ini
[Unit]
Description=Restore/save SSH host keys + ensure authorized_keys
Before=ssh.service
ConditionPathIsDirectory=/home/iorlas

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '\
  KEYS_DIR=/home/iorlas/.fox-ssh-keys; \
  if [ -d "$KEYS_DIR" ] && [ -n "$(ls -A $KEYS_DIR 2>/dev/null)" ]; then \
    cp $KEYS_DIR/ssh_host_* /etc/ssh/ && chmod 600 /etc/ssh/ssh_host_*_key; \
  else \
    mkdir -p $KEYS_DIR && cp /etc/ssh/ssh_host_* $KEYS_DIR/ && chown -R iorlas:iorlas $KEYS_DIR; \
  fi; \
  if [ ! -f /home/iorlas/.ssh/authorized_keys ]; then \
    mkdir -p /home/iorlas/.ssh && chmod 700 /home/iorlas/.ssh; \
    cp /etc/fox-defaults/.ssh/authorized_keys /home/iorlas/.ssh/; \
    chown -R iorlas:iorlas /home/iorlas/.ssh; \
  fi'

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 2: Create hosts/fox/Dockerfile**

```dockerfile
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV container=docker

# --- Systemd setup ---
RUN apt-get update && apt-get install -y \
    systemd systemd-sysv dbus \
    openssh-server \
    docker.io \
    curl git sudo \
    iptables iproute2 \
    ca-certificates gnupg \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /lib/systemd/system/multi-user.target.wants/* \
    && rm -f /etc/systemd/system/*.wants/* \
    && rm -f /lib/systemd/system/local-fs.target.wants/* \
    && rm -f /lib/systemd/system/sockets.target.wants/*udev* \
    && rm -f /lib/systemd/system/sockets.target.wants/*initctl* \
    && rm -f /lib/systemd/system/basic.target.wants/*

# --- User setup ---
RUN useradd -m -s /bin/bash -G sudo,docker iorlas \
    && echo "iorlas ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/iorlas \
    && chmod 440 /etc/sudoers.d/iorlas

# --- SSH authorized keys from GitHub (staged for first-boot copy) ---
RUN mkdir -p /etc/fox-defaults/.ssh \
    && curl -fsSL https://github.com/iorlas.keys > /etc/fox-defaults/.ssh/authorized_keys \
    && chmod 600 /etc/fox-defaults/.ssh/authorized_keys

# --- SSH host key persistence service ---
COPY hosts/fox/systemd/fox-ssh-keys.service /etc/systemd/system/
RUN systemctl enable fox-ssh-keys.service

# --- Disable password auth ---
RUN sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# --- Install Nix (single-user/root-only for Docker build) ---
RUN curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install linux \
    --no-confirm --init none --mode root-only

# --- Home-manager switch (layer caching: flake inputs first) ---
COPY --chown=iorlas:iorlas flake.nix flake.lock /home/iorlas/nixos-config/
COPY --chown=iorlas:iorlas home/ /home/iorlas/nixos-config/home/
COPY --chown=iorlas:iorlas hosts/fox/ /home/iorlas/nixos-config/hosts/fox/

USER iorlas
WORKDIR /home/iorlas/nixos-config
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix.sh \
    && nix build .#homeConfigurations.fox.activationPackage --no-link \
    && "$(nix path-info .#homeConfigurations.fox.activationPackage)"/activate

# --- Claude Code ---
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix.sh \
    && export PATH="$HOME/.nix-profile/bin:$HOME/.npm-global/bin:$PATH" \
    && mkdir -p /home/iorlas/.npm-global \
    && npm config set prefix /home/iorlas/.npm-global \
    && pnpm add -g @anthropic-ai/claude-code

USER root

# --- Clean up nix store ---
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix.sh \
    && nix-collect-garbage -d \
    && nix store optimise

# --- Enable services ---
RUN systemctl enable ssh docker

STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/sbin/init"]
```

- [ ] **Step 3: Create hosts/fox/docker-compose.yml**

```yaml
services:
  fox:
    build:
      context: ../..
      dockerfile: hosts/fox/Dockerfile
    container_name: fox
    hostname: fox
    restart: unless-stopped
    tty: true
    stdin_open: true
    cap_add:
      - SYS_ADMIN
      - NET_ADMIN
      - MKNOD
      - NET_RAW
    security_opt:
      - seccomp:unconfined
      - apparmor:unconfined
    # Fallback if capabilities aren't enough for systemd + dockerd:
    # privileged: true
    volumes:
      - home:/home/iorlas
      - docker:/var/lib/docker
    tmpfs:
      - /run
      - /run/lock
    ports:
      - "${TAILSCALE_IP}:2222:22"
    mem_limit: 16g
    cpus: 4
    healthcheck:
      test: ["CMD-SHELL", "systemctl is-system-running | grep -qE 'running|degraded'"]
      interval: 30s
      timeout: 5s
      retries: 3

volumes:
  home:
  docker:
```

- [ ] **Step 4: Create hosts/fox/.env.example**

```
# Shen's Tailscale IP — find with: tailscale ip -4
# Or use the MagicDNS name equivalent
TAILSCALE_IP=100.x.x.x
```

- [ ] **Step 5: Create hosts/fox/.gitignore**

```
.env
```

- [ ] **Step 6: Commit**

```bash
git add hosts/fox/
git commit -m "feat: add fox Dockerfile, compose, systemd units"
```

---

### Task 7: Create fox-connect scripts

**Files:**
- Create: `scripts/fox-connect.sh`
- Create: `scripts/fox-connect.fish`

- [ ] **Step 1: Create scripts/fox-connect.sh**

```bash
#!/usr/bin/env bash
# Connect to tmux sessions on fox via iTerm2 tmux -CC integration.
#
# Usage:
#   fox-connect                     # reconnect all existing sessions (or create default)
#   fox-connect project-name        # create/attach a project session
#   fox-connect project-name /path  # create in custom path
#
# Run this in an iTerm2 window. tmux -CC takes over and creates native windows.

set -uo pipefail

HOST="fox"
SESSION="${1:-}"
DIR="${2:-}"

# If a session name was given, create/attach just that one
if [ -n "$SESSION" ]; then
  DIR="${DIR:-~/Workspaces/$SESSION}"
  ssh "$HOST" "mkdir -p $DIR" 2>/dev/null
  echo "→ Connecting to $SESSION ($DIR)..."
  exec ssh "$HOST" -t "tmux -CC new-session -A -s $SESSION -c $DIR"
fi

# Otherwise, reconnect all existing sessions
SESSIONS=$(ssh "$HOST" "tmux list-sessions -F '#S'" 2>/dev/null || echo "")

if [ -z "$SESSIONS" ]; then
  echo "→ No sessions found. Creating default session..."
  exec ssh "$HOST" -t "tmux -CC new-session -s main"
fi

echo "→ Reconnecting $(echo "$SESSIONS" | wc -l | tr -d ' ') session(s)..."

FIRST=$(echo "$SESSIONS" | head -1)
exec ssh "$HOST" -t "tmux -CC attach -t $FIRST"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/fox-connect.sh
```

- [ ] **Step 3: Create scripts/fox-connect.fish**

```fish
# Fish completions for fox-connect
# Completes with existing tmux sessions + workspace directories on fox

complete -c fox-connect -f -a '(ssh fox tmux list-sessions -F "#S" 2>/dev/null)'
complete -c fox-connect -f -a '(ssh fox ls ~/Workspaces/ 2>/dev/null)'
```

- [ ] **Step 4: Commit**

```bash
git add scripts/fox-connect.sh scripts/fox-connect.fish
git commit -m "feat: add fox-connect scripts for iTerm2 tmux -CC"
```

---

### Task 8: Update TODO.md and README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update TODO.md**

Replace `TODO.md` with:

```markdown
# TODO

- [x] Split doctor.sh into modular checks when adding a second host
- [x] Extract host-specific config (exit node name, etc.) into a config file when adding a second host
- [ ] Automate home-manager switch on fox container boot (V2)
- [ ] Migrate fox from Docker to Incus for full NixOS support (V2)
- [ ] Add K auto-sync (git commit/push every 3 min) to fox (V2)
```

- [ ] **Step 2: Read current README**

Read `README.md` to understand current structure.

- [ ] **Step 3: Add fox section to README**

Add the following section after the existing pix documentation. Keep existing pix content unchanged. Add a new top-level section:

```markdown
## Fox (Docker dev container on shen)

Fox is a Docker container running on shen (personal VPS), providing an isolated dev environment safe from corporate MDM.

### First-time setup

1. SSH into shen: `ssh shen`
2. Clone this repo: `git clone git@github.com:iorlas/nixos-config.git && cd nixos-config`
3. Create `.env` in `hosts/fox/`:
   ```bash
   echo "TAILSCALE_IP=$(tailscale ip -4)" > hosts/fox/.env
   ```
4. Build and start: `cd hosts/fox && docker compose build && docker compose up -d`
5. Bootstrap: `docker exec -it fox bash -c "doctor"`
6. Authenticate (inside fox): `gh auth login`, then `claude`

### Mac-side setup

Add to `~/.ssh/config`:
```
Host fox
    HostName shen.your-tailnet.ts.net
    Port 2222
    User iorlas
```

Add to your fish config:
```fish
alias fox-connect="~/.local/bin/fox-connect"
```

### Day-to-day usage

| Command | What it does |
|---------|-------------|
| `fox-connect` | Reconnect all tmux sessions via iTerm2 |
| `fox-connect myproject` | Create/attach project session |
| `ssh fox` | Quick shell |
| `nrs` | Apply config changes (home-manager switch) |
| `doctor` | Health check |

### Dev port forwarding

```bash
ssh -L 8080:localhost:8080 fox    # forward one port
ssh -L 8080:localhost:8080 -L 5432:localhost:5432 fox  # multiple
```

### Weekly rebuild

```bash
ssh shen
cd nixos-config/hosts/fox
docker compose build && docker compose up -d
docker exec -u iorlas fox home-manager switch --flake ~/nixos-config#fox
```
```

- [ ] **Step 4: Commit**

```bash
git add TODO.md README.md
git commit -m "docs: add fox setup instructions, update TODO"
```

---

### Task 9: Verify and deploy on shen

**Files:** None (deployment task)

- [ ] **Step 1: Push to GitHub**

```bash
git push origin main
```

- [ ] **Step 2: Clone/pull on shen**

```bash
ssh iorlas@shen.iorlas.net -p 2201 "cd nixos-config 2>/dev/null && git pull || git clone git@github.com:iorlas/nixos-config.git"
```

- [ ] **Step 3: Create .env file on shen**

```bash
ssh iorlas@shen.iorlas.net -p 2201 "cd nixos-config/hosts/fox && echo 'TAILSCALE_IP='$(ssh iorlas@shen.iorlas.net -p 2201 'tailscale ip -4') > .env"
```

- [ ] **Step 4: Build fox**

```bash
ssh iorlas@shen.iorlas.net -p 2201 "cd nixos-config/hosts/fox && docker compose build"
```

Expected: Build completes successfully. May take 10-15 minutes on first build (nix downloads).

- [ ] **Step 5: Start fox**

```bash
ssh iorlas@shen.iorlas.net -p 2201 "cd nixos-config/hosts/fox && docker compose up -d"
```

- [ ] **Step 6: Verify systemd is running**

```bash
ssh iorlas@shen.iorlas.net -p 2201 "docker exec fox systemctl is-system-running"
```

Expected: `running` or `degraded` (degraded is OK — some systemd units fail in containers).

If this fails with permission errors, uncomment `privileged: true` in docker-compose.yml and comment out the `cap_add`/`security_opt` sections, then rebuild.

- [ ] **Step 7: Verify SSH access**

```bash
ssh -p 2222 iorlas@$(ssh iorlas@shen.iorlas.net -p 2201 'tailscale ip -4') "echo 'SSH works'"
```

Expected: `SSH works`

- [ ] **Step 8: Run doctor inside fox**

```bash
ssh iorlas@shen.iorlas.net -p 2201 "docker exec -u iorlas -it fox bash -l -c doctor"
```

Expected: Shows check results. gh and claude will be flagged as not authenticated (expected).

- [ ] **Step 9: Interactive auth setup**

```bash
ssh iorlas@shen.iorlas.net -p 2201 "docker exec -u iorlas -it fox bash"
# Inside fox:
gh auth login
claude
# Exit when done
```

- [ ] **Step 10: Test fox-connect from Mac**

Add to `~/.ssh/config` on Mac:
```
Host fox
    HostName shen.your-tailnet.ts.net
    Port 2222
    User iorlas
```

Then:
```bash
fox-connect
```

Expected: iTerm2 tmux -CC session opens with fish prompt showing `main @ fox`.

- [ ] **Step 11: Commit any deployment fixes**

If any changes were needed (e.g., switching to `privileged: true`), commit them:

```bash
git add -A
git commit -m "fix: deployment adjustments for fox on shen"
git push
```
