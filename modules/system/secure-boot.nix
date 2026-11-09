{ inputs, ... }:
{
  flake-file.inputs.lanzaboote = {
    url = "github:nix-community/lanzaboote";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixconf.modules.nixos.secureBoot =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Import unconditionally so the options exist on every host that has this
      # feature in its tier; nothing changes until modules.secureBoot.enable.
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      options.modules.secureBoot = {
        enable = lib.mkEnableOption "UEFI Secure Boot via lanzaboote";
        pkiBundle = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/sbctl";
          description = "Directory holding the sbctl keys and GUID (persist it across reinstalls).";
        };
        autoGenerateKeys = lib.mkEnableOption "generate Secure Boot keys on first boot";
        autoEnrollKeys = lib.mkEnableOption "enroll the generated keys into the firmware on the next boot";
      };

      config = lib.mkIf config.modules.secureBoot.enable {
        # Lanzaboote replaces systemd-boot with its own external loader.
        boot.loader.systemd-boot.enable = lib.mkForce false;
        boot.lanzaboote = {
          enable = true;
          pkiBundle = config.modules.secureBoot.pkiBundle;
          autoGenerateKeys.enable = config.modules.secureBoot.autoGenerateKeys;
          autoEnrollKeys.enable = config.modules.secureBoot.autoEnrollKeys;
        };
        environment.systemPackages = [ pkgs.sbctl ];
      };
    };
}
