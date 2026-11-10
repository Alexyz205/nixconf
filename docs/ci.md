# CI and binary cache

## Workflows

`.github/workflows/ci.yml` (push to `main`, every PR):

1. `nix flake check -L --keep-going` — evaluates every NixOS, darwin and
   home-manager output, then builds all `checks.<system>` entries:
   - `format` — `nixfmt --check`, `shfmt -d`, `shellcheck`, `statix`, `deadnix`
     over the whole tree (same tools as the git hooks).
   - `lint` — `actionlint` on the workflows, `yamllint -c .yamllint.yml` and a
     `gitleaks dir` scan (the FIDO2 resident-key handle is allowlisted in
     `.gitleaks.toml`).
   - `server-boot` — boots the server feature set in a QEMU VM and asserts
     `sshd` is running, `fail2ban` is enabled, and `nix` works.
2. Cross-evaluates `darwinConfigurations.macbook` (no macOS runner needed;
   evaluation is enough to catch option errors).
3. `flake-checker` — advisory report for stale or unsupported nixpkgs inputs.

`.github/workflows/update.yml` runs every Monday at 04:00 UTC and opens a PR
with `nix flake update` (via `DeterminateSystems/update-flake-lock`). Review the
diff and let CI run before merging.

Heavy artifacts (installer ISO, Proxmox VM, CUDA/Blender/FreeCAD closures) are
**not** built on hosted runners: they need a lot of disk/time and are better
produced by the local pre-push hooks or a self-hosted runner. The pre-push hook
still covers `disko`, `iso` and `vm`.

## Cachix

CI uses [Cachix](https://cachix.org) so `checks` and system closures are built
once and substituted on later runs and on your machines.

1. Create a cache (e.g. `nixconf`) and an auth token in the Cachix dashboard.
2. In the GitHub repository: **Settings -> Variables -> Actions** add
   `CACHIX_CACHE_NAME` = `nixconf`.
3. Add the token as **Secrets -> Actions -> `CACHIX_AUTH_TOKEN`**.
4. If the variable is unset the Cachix step is skipped and CI still works,
   just without caching.

On a machine that should consume the cache:

```nix
nix.settings = {
  substituters = [ "https://nixconf.cachix.org" ];
  trusted-public-keys = [ "nixconf.cachix.org-1:<key>" ];
};
```

The public key is shown in the Cachix cache settings. Pushing from a local
machine is `cachix push nixconf $(nix build --no-link --print-out-paths .#...)`
or via `nix.settings.post-build-hook` (not enabled by default: it uploads every
build and needs the token available to the builder).

## Local equivalents

```bash
./scripts/test-all.sh                 # flake, eval, disko, iso, vm, shellcheck
./scripts/test-all.sh flake eval      # fast subset
nix flake check                       # eval + checks
nix build .#checks.x86_64-linux.format -L
nix build .#checks.x86_64-linux.lint -L
nix build .#checks.x86_64-linux.server-boot -L
nix run github:DeterminateSystems/flake-checker

# repo tasks (also installed as pre-commit hooks)
devenv tasks run repo:lint
devenv tasks run repo:secrets
devenv tasks run repo:security
devenv tasks run repo:stats
```

The host/profile lists used by `scripts/test-all.sh` are derived from the flake
(`nixosConfigurations`, `darwinConfigurations`, `homeConfigurations`, and the
hosts whose `modules.disko.enable` is true), so adding a host never leaves it
untested.
