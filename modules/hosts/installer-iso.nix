{
  config,
  inputs,
  lib,
  self,
  ...
}:
let
  diskoPkg = inputs.disko.packages.x86_64-linux.disko;
in
{
  flake.nixosConfigurations.installer-iso = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit diskoPkg; };
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      { nixpkgs.overlays = config.nixconf.modules.overlays; }
      (
        {
          pkgs,
          diskoPkg,
          ...
        }:
        let
          installerScript = pkgs.writeShellApplication {
            name = "nixos-installer";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.gum
              pkgs.gawk
              pkgs.gnugrep
              pkgs.gnused
              pkgs.iputils
              pkgs.libfido2
              pkgs.nix
              pkgs.nixos-install-tools
              pkgs.shadow
              pkgs.usbutils
              pkgs.util-linux
              diskoPkg
            ];
            # Kept in scripts/ so shellcheck/shfmt see it like any other script.
            text = builtins.readFile ../../scripts/nixos-installer.sh;
          };
        in
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          isoImage = {
            edition = "custom-iso";
            contents = [
              {
                source = self.sourceInfo.outPath;
                target = "/nixconf";
              }
            ];
          };

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          services.openssh.enable = true;
          users.users.root = {
            password = "nixos";
            # The install-CD profile sets initialHashedPassword = ""; force it
            # null so only `password` is set (silences the multiple-password
            # options warning without changing root login).
            initialHashedPassword = lib.mkForce null;
          };

          environment.etc."yubi-age-identity".source = ../../config/sops/yubi-age-identity;

          services.udev.packages = [ pkgs.yubikey-personalization ];

          environment.systemPackages = [
            pkgs.gum
            pkgs.libfido2
            pkgs.pam_u2f
            pkgs.usbutils
            diskoPkg
            installerScript
          ];

          users.motd = ''
            ============================================
            nixconf installer
            ============================================

            Run 'nixos-installer' to begin installation.
          '';
        }
      )
    ];
  };
}
