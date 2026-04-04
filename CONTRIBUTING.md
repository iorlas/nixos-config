# Contributing to nixos-config

Guide for AI agents and humans working on this repository.

## Multi-host architecture

This repo manages three environments from one codebase:

| Host | Type | Config |
|------|------|--------|
| **pix** | OrbStack NixOS VM (aarch64-linux) | `nixosConfigurations.pix` + home-manager module |
| **fox** | Bare user on shen VPS (x86_64-linux) | `homeConfigurations.fox` (standalone home-manager) |
| **mac** | Native macOS | `hosts/mac/setup.sh` (manual dotfile management) |

**Key principle: shared first.** If a config applies to multiple hosts, put it in the shared location. Host-specific configs go under `hosts/<name>/`.

## Structure

```
flake.nix                         Flake entry — defines hosts and inputs
home/                             Shared home-manager modules (all hosts)
  default.nix                     Entry point — packages, bootstrap/doctor refs
  cli/fish.nix                    Fish shell (parameterized by hostName)
  cli/tmux.nix                    Tmux (parameterized by hostName)
  cli/git.nix                     Git config
  cli/direnv.nix                  Direnv + nix-direnv
  cli/claude-statusline.sh        Claude Code statusline script
modules/                          NixOS-only system modules (pix only)
hosts/
  lib/                            Shared check library (used by all doctors)
    doctor-common.sh              Loads all checks, runs common ones
    checks/                       Individual check functions
      common.sh                   Helpers: ok(), warn(), fail(), fix_or_hint()
      claude-code.sh              Claude Code: install, auth, statusline, npm→native
      gh.sh                       GitHub CLI auth
      nix.sh                      Nix install + ad-hoc package drift
      home-manager.sh             Home-manager generation
      docker.sh                   Docker access
      fish.sh                     Fish shell + bashrc trampoline
      ssh.sh                      SSH keys + agent
      nixos.sh                    NixOS version (pix only)
      tailscale.sh                Tailscale exit node (pix only)
      network.sh                  Network connectivity (pix only)
      dns.sh                      Quad9 DNS-over-TLS (pix only)
      home-dir.sh                 Home directory permissions (fox only)
  pix/                            Pix-specific: bootstrap.sh, doctor.sh
  fox/                            Fox-specific: bootstrap.sh, doctor.sh, defaults/
  mac/                            Mac-specific: setup.sh
scripts/                          Mac-side connect scripts
```

## Adding a doctor check

**IMPORTANT: Always add to the shared library first.**

1. Create `hosts/lib/checks/<name>.sh` with a `check_<name>()` function
2. Source it in `hosts/lib/doctor-common.sh`
3. If it applies to ALL hosts: add the call to `run_common_checks()` in `doctor-common.sh`
4. If it's host-specific: add the call in that host's `doctor.sh` only

**Never duplicate check logic in host doctors.** If you're writing the same check in both `pix/doctor.sh` and `fox/doctor.sh`, it belongs in the library.

Example — adding a new common check:

```bash
# 1. Create hosts/lib/checks/my-tool.sh
check_my_tool() {
  echo "==> My Tool"
  if command -v my-tool &> /dev/null; then
    ok "my-tool installed"
  else
    fail "my-tool not found"
    hint "Run: nrs"
  fi
}

# 2. Add to hosts/lib/doctor-common.sh
source "$LIB_DIR/checks/my-tool.sh"

# 3. Add to run_common_checks() if it applies everywhere
run_common_checks() {
  ...existing checks...
  check_my_tool
}
```

## Adding a user package

Packages go in `home/default.nix` under `home.packages` (shared between pix and fox). Do NOT add to `modules/cli/dev-tools.nix` — that file is deprecated.

## Adding home-manager config

1. Create `home/cli/<tool>.nix` (or `home/<category>/<tool>.nix`)
2. Import from `home/default.nix`
3. Accept `hostName` arg if behavior differs per host: `{ pkgs, hostName, ... }:`
4. Use `let isPix = hostName == "pix";` for conditionals

## Parameterization

`hostName` is passed via `extraSpecialArgs` from `flake.nix`. Available in all home modules. Use it for:
- Different aliases per host (`nrs`)
- Host-specific functions (exit node guard on pix)
- Username (`if hostName == "fox" then "fox" else "iorlas"`)

## Testing changes

```bash
# On pix (NixOS):
nrs                    # nixos-rebuild switch

# On fox (bare user):
nrs                    # git pull + home-manager switch + reload fish

# Verify:
doctor                 # health check
doctor --fix           # auto-fix what can be fixed
```

## Important: --impure flag (pix only)

Required because pix imports `/etc/nixos/orbstack.nix` (OrbStack-managed, lives on VM disk, not in this repo). Without `--impure`, flake evaluation fails on the absolute path. The `nrs` alias handles this.
