---
name: nix
description: Nix/NixOS standards for this dendritic repo - flake-parts + import-tree modules, feature composition tiers, home-manager sides, evaluation debugging
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: nixos
---

## Purpose

Standards for this repo's dendritic flake. Follow the tree structure, keep feature modules composable, catch evaluation errors early.

## Dendritic Model

- `flake.nix` is the trunk: one line of `outputs` delegating to `flake-parts` + `import-tree ./modules`
- `import-tree` recursively loads every `*.nix` under `modules/` as a flake-parts module — there is **no central registry**; the tree _is_ the config
- Feature modules are branches (`modules/<category>/`); hosts are leaves (`modules/hosts/`)
- Add a module = drop a file in the right directory; it is discovered automatically

## Feature Module Shape

Each feature declares a NixOS side and (where relevant) a home-manager side, and owns its `enable` option, packages, and aliases:

```nix
{
  flake.modules.nixos.lazygit = { config, pkgs, ... }: {
    options.modules.lazygit.enable = lib.mkEnableOption "Lazygit";
    config = lib.mkIf config.modules.lazygit.enable {
      environment.systemPackages = [ pkgs.lazygit ];
      home-manager.users.${config.modules.users.userName} = { ... };
    };
  };

  flake.modules.homeManager.lazygit = { pkgs, ... }: {
    home.packages = [ pkgs.lazygit ];
  };
}
```

- NixOS side: `options.modules.<feature>.enable` + `lib.mkIf`-gated `config`
- home-manager side: standalone, no `enable` needed (composed by `mkHome`)
- Cross-platform aliases gated per platform (NixOS / darwin / standalone home-manager)

## Composition Tiers

- `config.flake.modules.nixos` collects every feature module (from `import-tree`)
- `flake/nixos.nix` bundles them into tiers: `nixosFeatures.base` → `server` → `desktop` (each extends the previous)
- `flake/home-manager.nix` composes `baseModules` + `extras` (each extra = module + `enable` flag)
- Compose features into tiers instead of listing every module in every host

## Hosts (Leaves)

- A host selects a tier (`config.flake.nixosFeatures.desktop`) and adds only its **deltas**: hardware, disko, allowUnfree, stylix, per-app toggles
- Enable features with one line: `modules.<feature>.enable = true`
- Shared boilerplate lives in `mkHostCommon` (stateVersion, hostName, timezone, home-manager wiring) — don't repeat it per host
- Standalone profiles use `mkHome` (system + username + extra list); non-NixOS Linux auto-derives `targets.genericLinux`

## Reproducibility

- `flake.lock` committed; never edit by hand — run `nix flake lock`
- Pin inputs; all `inputs` follow `nixpkgs` where possible (`inputs.*.inputs.nixpkgs.follows`)
- Secrets via `sops-nix`, never `builtins.readFile` of plaintext
- Dotfiles/static assets under `config/`, referenced from modules

## Validation

```bash
nix flake check                          # zero warnings
nixos-rebuild build --flake $NIXCONF     # dry-run before switch
nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
disko --mode disko --dry-run             # for disk layouts
```

- `nixfmt` on all `.nix` changes

## Debugging Evaluation Errors

- Read the full trace, not just the first line
- `nix flake show` to list outputs; `nix eval --raw` on a leaf attr to isolate
- Infinite recursion → check self-referential `let`/`mkIf` cycles in feature modules
- Missing feature → confirm the module file is under `modules/` and named `*.nix`

## When to Use

- Adding/editing feature modules, hosts, or flake plumbing
- Debugging evaluation/build failures
- Reviewing a module for composability and reproducibility
