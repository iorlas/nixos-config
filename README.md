# nixos-config

NixOS configuration for OrbStack dev VMs. Flake-based, modular, with home-manager.

## Quick start

```bash
# Create VM
orb create nixos:25.11 pix

# Bootstrap (one-time setup)
orb run -m pix bash /mnt/mac/Users/iorlas/nixos-config/bootstrap.sh

# Connect Tailscale
orb run -m pix sudo tailscale up --exit-node=<vps-tailscale-ip> --accept-routes

# Authenticate Claude
orb run -m pix claude
```

## Day-to-day usage

```bash
orb shell pix        # enter the VM

doctor               # check health of everything
bootstrap            # rebuild system + check health
nrs                  # quick nixos-rebuild switch

c                    # claude code
```

## Structure

```
flake.nix                     Pins nixpkgs + home-manager
bootstrap.sh                  One-time idempotent setup
doctor.sh                     Read-only health check

hosts/pix/default.nix         OrbStack VM config

modules/
  nix/settings.nix            Flakes, GC, store optimization
  nix/nix-ld.nix              Run unpatched binaries
  services/docker.nix         Docker + compose
  services/tailscale.nix      Tailscale + firewall
  shell/fish.nix              System-level fish
  cli/dev-tools.nix           Node.js, fnm, uv, build tools, editors

home/
  default.nix                 Home-manager entry
  cli/fish.nix                Tide, plugins, zoxide, atuin, fzf, bat, eza
  cli/git.nix                 Git + delta
  cli/direnv.nix              Per-project nix environments
```

## What's installed

| Category | Tools |
|----------|-------|
| Shell | fish, tide, autopair, done |
| Navigation | zoxide, fzf, eza, fd, tree |
| Search | ripgrep |
| History | atuin |
| Git | git, delta, lazygit |
| Node.js | nodejs 22, fnm |
| Python | uv |
| Containers | docker, docker-compose |
| Network | tailscale |
| Editors | neovim, nano |
| AI | claude code (npm, self-updating) |
| Other | tmux, jq, yq, bat, htop, direnv, gcc, make |

## Workflow

- **Config lives on Mac** at `~/nixos-config`
- **VM reads it** via OrbStack mount at `/mnt/mac/Users/iorlas/nixos-config`
- **Edit on Mac**, commit with your existing git credentials
- **Rebuild from VM**: `nrs` or `bootstrap`
- **Claude Code** installed via npm (not nix) so it can self-update daily

## Adding a new tool

1. Add package to the appropriate module in `modules/` (system-level) or `home/` (user-level)
2. Commit + `nrs` from the VM

## Fresh VM from scratch

```bash
orb delete pix
orb create nixos:25.11 pix
orb run -m pix bash /mnt/mac/Users/iorlas/nixos-config/bootstrap.sh
```
