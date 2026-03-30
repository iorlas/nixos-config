# Fox — Remote Dev Container on Shen

## Problem

Denis's Mac is corporate-managed (DataArt MDM). The MDM can scan local files and remote-wipe the device. Personal projects, the Knowledge base (K), and Claude Code sessions need to run somewhere safe. Shen is a personal VPS (Contabo, x86_64, Ubuntu 22.04) already running ~30 Docker containers via Dokploy.

## Solution

A single Docker container ("fox") on shen providing an isolated dev environment. Systemd as PID 1. Docker-in-Docker and sshd as native systemd services. User environment managed by Nix home-manager (shared configs with pix, the local OrbStack VM). SSH access via shen's existing Tailscale connection.

## Architecture

```
┌─── shen (host) ──────────────────────────────────────┐
│  Tailscale (host-level, existing)                    │
│  Dokploy / Docker Swarm (~30 containers)             │
│                                                      │
│  ┌─── fox (Docker container) ──────────────────────┐ │
│  │  systemd (PID 1)                                │ │
│  │  ├── sshd                                       │ │
│  │  ├── dockerd (DinD)                             │ │
│  │  ├── nix-daemon                                 │ │
│  │  └── fox-ssh-keys.service (boot-time key copy)  │ │
│  │                                                  │ │
│  │  User env (nix home-manager):                    │ │
│  │  fish + tmux + git + direnv + dev tools          │ │
│  │  Claude Code (pnpm global)                       │ │
│  │                                                  │ │
│  │  Volumes: /home/iorlas, /var/lib/docker          │ │
│  └──────────────────────────────────────────────────┘ │
│                                                      │
│  Port: ${TAILSCALE_IP}:2222 → fox:22                 │
│  No public port exposure                             │
└──────────────────────────────────────────────────────┘

┌─── Mac ──────────────────────────────────┐
│  ~/.ssh/config: Host fox → shen:2222     │
│  fox-connect → ssh -t fox "tmux -CC ..." │
│  Dev ports via SSH forwarding            │
└──────────────────────────────────────────┘
```

## Container Specification

### docker-compose.yml

```yaml
services:
  fox:
    build:
      context: ../..        # repo root (needed for flake.nix, home/, etc.)
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

Requires `.env` file alongside compose (gitignored):
```
TAILSCALE_IP=100.x.x.x
```

A `.env.example` is committed to the repo with instructions.

### Dockerfile

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
    # Remove unnecessary systemd units
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

# --- Install Nix (single-user/root-only for Docker build, daemon runs at runtime) ---
RUN curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install linux \
    --no-confirm --init none --mode root-only

# --- Home-manager switch (layer caching: flake inputs first) ---
COPY --chown=iorlas:iorlas flake.nix flake.lock /home/iorlas/nixos-config/
COPY --chown=iorlas:iorlas home/ /home/iorlas/nixos-config/home/
# hosts/fox is needed for fox-specific bootstrap/doctor referenced by home/default.nix
COPY --chown=iorlas:iorlas hosts/fox/ /home/iorlas/nixos-config/hosts/fox/

# Run home-manager switch as iorlas using the flake's pinned home-manager
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

# --- Clean up nix store (requires root for root-only nix install) ---
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix.sh \
    && nix-collect-garbage -d \
    && nix store optimise

# --- Enable services ---
RUN systemctl enable ssh docker

STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/sbin/init"]
```

### Systemd Units

**fox-ssh-keys.service** — persists SSH host keys and sets up authorized_keys on the /home volume:

```ini
[Unit]
Description=Restore/save SSH host keys + ensure authorized_keys
Before=ssh.service
ConditionPathIsDirectory=/home/iorlas

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '\
  # --- SSH host keys --- \
  KEYS_DIR=/home/iorlas/.fox-ssh-keys; \
  if [ -d "$KEYS_DIR" ] && [ -n "$(ls -A $KEYS_DIR 2>/dev/null)" ]; then \
    cp $KEYS_DIR/ssh_host_* /etc/ssh/ && chmod 600 /etc/ssh/ssh_host_*_key; \
  else \
    mkdir -p $KEYS_DIR && cp /etc/ssh/ssh_host_* $KEYS_DIR/ && chown -R iorlas:iorlas $KEYS_DIR; \
  fi; \
  # --- Authorized keys (first boot from image defaults) --- \
  if [ ! -f /home/iorlas/.ssh/authorized_keys ]; then \
    mkdir -p /home/iorlas/.ssh && chmod 700 /home/iorlas/.ssh; \
    cp /etc/fox-defaults/.ssh/authorized_keys /home/iorlas/.ssh/; \
    chown -R iorlas:iorlas /home/iorlas/.ssh; \
  fi'

[Install]
WantedBy=multi-user.target
```

On first boot: copies image-generated host keys to persistent volume, seeds `~/.ssh/authorized_keys` from image defaults.
On subsequent boots (including after rebuild): restores host keys from volume, leaves existing authorized_keys untouched.
To update authorized_keys: edit `~/.ssh/authorized_keys` on the volume directly, or rebuild image and delete the file to re-seed.

## Volume Initialization Note

The `/home/iorlas` volume interacts with the Docker image as follows:
- **First run (empty volume):** Docker copies the image's `/home/iorlas` contents into the volume. This includes home-manager profile links, `.npm-global`, `.ssh` defaults, etc.
- **Subsequent runs:** Volume takes precedence over image. New packages added to the image's home-manager config won't appear until `home-manager switch` is re-run inside the container.
- **After weekly rebuild:** Run `nrs` (home-manager switch) inside fox to reconcile the volume with the new image's config. This is a manual step in V1; V2 could automate it via a boot-time service.

## Nix Configuration (Mono-Repo Changes)

### flake.nix

Add `homeConfigurations.fox` alongside existing `nixosConfigurations.pix`:

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

### home/default.nix

Accept `hostName`. Point bootstrap/doctor to host-specific scripts. Add dev tools to `home.packages`:

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
    # Node.js (verify nodejs_24 exists in nixpkgs, fallback to nodejs_22)
    nodejs_24
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

### home/cli/fish.nix

Accept `hostName` and `lib`. Conditionalize pix-only features:

- **iTerm2 integration** — shared (works over SSH)
- **nrs alias** — pix: `sudo nixos-rebuild switch --flake /mnt/mac/.../nixos-config#pix --impure`, fox: `home-manager switch --flake ~/nixos-config#fox`
- **Exit node guard** (`_check_exit_node`, `claude`/`c` wrappers, `fish_greeting`) — pix only. Fox: `claude`/`c` are plain passthrough, `fish_greeting` is empty.

### home/cli/tmux.nix

Accept `hostName`. Title string: `"#S @ ${hostName}"`.

## File Operations

### Files moved (2)
- `bootstrap.sh` → `hosts/pix/bootstrap.sh`
- `doctor.sh` → `hosts/pix/doctor.sh`

### Files modified (5)
- `flake.nix` — add homeConfigurations.fox, add extraSpecialArgs to pix
- `home/default.nix` — accept hostName, host-specific scripts, add home.packages
- `home/cli/fish.nix` — accept hostName/lib, conditionalize nrs/exit-guard
- `home/cli/tmux.nix` — accept hostName, parameterize title
- `README.md` — add fox section

### Files created (~8)
- `hosts/fox/Dockerfile`
- `hosts/fox/docker-compose.yml`
- `hosts/fox/.env.example`
- `hosts/fox/.gitignore` (ignores `.env`)
- `hosts/fox/bootstrap.sh`
- `hosts/fox/doctor.sh`
- `hosts/fox/systemd/fox-ssh-keys.service`
- `scripts/fox-connect.sh`
- `scripts/fox-connect.fish`

## Connectivity

### Mac SSH config

```
Host fox
    HostName shen.tailnet-name.ts.net
    Port 2222
    User iorlas
```

Uses shen's MagicDNS name (not raw Tailscale IP) for stability.

### fox-connect.sh

```bash
#!/usr/bin/env bash
SESSION="${1:-main}"
DIR="${2:-\$HOME}"
exec ssh -t fox "tmux -CC new-session -A -s $SESSION -c $DIR"
```

### Dev port access

Via SSH port forwarding:
```bash
ssh -L 8080:localhost:8080 fox    # forward one port
ssh -L 8080:localhost:8080 -L 5432:localhost:5432 fox  # multiple
```

## Bootstrap Flow (First Run)

1. On shen: create `.env` with `TAILSCALE_IP=...`
2. `docker compose build && docker compose up -d`
3. `docker exec -it fox bash` (escape hatch, no SSH yet)
4. Run `doctor` — flags missing auth for gh and claude
5. `gh auth login` (interactive, copies URL to browser)
6. `claude` (first-run auth)
7. From Mac: add SSH config, test `ssh fox`
8. From Mac: `fox-connect` for iTerm2 tmux -CC

## bootstrap.sh (Fox)

Minimal — most tools are baked into the image. Bootstrap handles first-run tasks only:

```bash
#!/usr/bin/env bash
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

## doctor.sh (Fox)

Checks:
- Nix installation (`nix --version`)
- Home-manager generation (`home-manager generations | head -1`)
- Claude Code installed + authenticated
- GitHub CLI authenticated (`gh auth status`)
- Docker working (`docker info`)
- sshd running (`systemctl is-active ssh`)
- Ad-hoc nix packages not in config (warns about `nix-env` drift)
- cgroupv2 available (`/sys/fs/cgroup/cgroup.controllers` exists)

## Deferred (V2)

- **Incus migration** — full NixOS, `nixosConfigurations.fox`, drop Docker
- **Own Tailscale identity** — separate device on tailnet
- **K clone + auto-sync** — git commit/push every 3 min, Mac-side pull
- **VSCode Server** — code tunnel or code-server
- **Mac-side k-pull** — launchd plist pulling K every 5 min
