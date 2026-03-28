# Contributing to nixos-config

Guide for AI agents and humans working on this repository.

## Available tools inside pix

When developing this config, you have these tools available:

- `nh os switch .` — nicer alternative to `nixos-rebuild switch` with generation diffs
- `, <package>` — run any nix package without installing (via comma)
- `nix-locate <file>` — find which package provides a file
- `nix flake check` — validate the flake
- `nix flake update` — update all inputs (nixpkgs, home-manager)

## Structure

```
flake.nix                         Flake entry — defines hosts and inputs
hosts/<name>/default.nix          Per-host config (OrbStack-specific bits)
modules/<category>/<tool>.nix     System-level NixOS modules
home/<category>/<tool>.nix        User-level home-manager modules
scripts/                          Host-side (macOS) scripts
bootstrap.sh                      One-time VM setup
doctor.sh                         Health check + auto-fix
```

## Adding a new system package

1. Add to the appropriate module in `modules/` (or create a new one)
2. If it needs user-level config (dotfiles, shell integration), add to `home/`
3. Import new modules from `hosts/pix/default.nix` or `home/default.nix`
4. Test: `orb run -m pix sudo nixos-rebuild switch --flake /mnt/mac/Users/iorlas/nixos-config#pix --impure`

## Adding a new home-manager program

1. Create `home/<category>/<tool>.nix`
2. Import from `home/default.nix`
3. Check available options: `https://mynixos.com/home-manager/options/programs.<tool>`

## Module conventions

- One file per tool/service
- System-level (services, system packages) → `modules/`
- User-level (dotfiles, shell config, per-user programs) → `home/`
- If a tool needs both, create files in both places

## Testing changes

```bash
# From Mac:
orb run -m pix sudo nixos-rebuild switch --flake /mnt/mac/Users/iorlas/nixos-config#pix --impure

# Or from inside pix:
nrs                    # alias for the above
nh os switch .         # nicer output with diffs
```

## Important: --impure flag

Required because we import `/etc/nixos/orbstack.nix` (OrbStack-managed, lives on VM disk, not in this repo). Without `--impure`, flake evaluation fails on the absolute path.

## Docker

Docker runs natively inside the pix NixOS VM. OrbStack's Docker is separate — pix has its own Docker daemon. `docker` and `docker compose` are available in pix.

Docker-in-OrbStack (nested) is NOT supported — pix cannot control OrbStack's Docker. Use pix's native Docker for all container work.
