# Dev environment for the nixconf repo itself.
#
# Purpose: provide the test prerequisites used by `scripts/test-all.sh`
#   (test_disko needs `disko`, test_shellcheck needs `shellcheck`).
# Devenv also gives auto-activation when you `cd` into this repo.
{pkgs, ...}: {
  name = "nixconf";
  packages = with pkgs; [
    disko
    shellcheck
    sops
    age-plugin-yubikey
  ];

  languages.nix.enable = true;
}
