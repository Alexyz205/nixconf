{
  lib,
  ...
}: let
  yubiPub = ./config/ssh/yubi_ed25519.pub;
  handle = ./config/ssh/yubi_ed25519;

  yubiCfg = {
    pkgs,
    ...
  }: {
    home.packages = with pkgs; [
      yubikey-manager
      libu2f-host
      pam_u2f
    ];
    home.file.".ssh/yubi_ed25519.pub".source = yubiPub;
    programs.ssh = {
      enable = true;
      extraConfig = ''
        IdentityFile ~/.ssh/yubi_ed25519
        IdentitiesOnly yes
      '';
    };
  } // lib.optionalAttrs (builtins.pathExists handle) {
    home.file.".ssh/yubi_ed25519".source = handle;
  };
in {
  flake.modules.nixos.yubikey = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.yubikey = {
      enable = lib.mkEnableOption "YubiKey hardware auth";
      sshKey = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use the resident FIDO2 YubiKey SSH key (~/.ssh/yubi_ed25519) for git/ssh";
      };
      luksUnlock = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description =
          "Unlock the disko LUKS volume (crypted) with a FIDO2 YubiKey at boot (touch, optional PIN)";
      };
      sudoAuth = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Authenticate sudo/login by touching the YubiKey (password stays as fallback)";
      };
    };

    # One-time enrollments (they touch the disk/credential databases and cannot
    # be scripted from here):
    #
    # LUKS: on a NEW install disko enrolls automatically (see luksUnlock).
    #       On an already-installed disk this ever happens once, manually:
    #         sudo systemd-cryptenroll --fido2-device=auto <luks-device>   # LUKS2
    # Sudo: pamu2fcfg > ~/.config/Yubico/u2f_keys
    # SSH : recover the resident key handle ONCE into the repo (it is not a secret):
    #         ssh-keygen -K && mv ~/id_ed25519_sk modules/config/ssh/yubi_ed25519
    config = lib.mkIf config.modules.yubikey.enable {
      environment.systemPackages = with pkgs; [
        yubikey-manager
        libu2f-host
        pam_u2f
      ];
      services.udev.packages = [pkgs.yubikey-personalization];

      # --- LUKS unlock with a FIDO2 token via systemd stage-1 -----------------
      disko.devices.disk.main.content.partitions.luks.content.enrollFido2 =
        lib.mkIf config.modules.yubikey.luksUnlock true;
      boot.initrd.systemd.fido2.enable = lib.mkIf config.modules.yubikey.luksUnlock true;

      # --- Touch instead of sudo/login password (pam_u2f) ----------------------
      security.pam.u2f = lib.mkIf config.modules.yubikey.sudoAuth {
        enable = true;
        control = "sufficient";
        settings = {
          cue = true;
          interactive = true;
        };
      };
      security.pam.services.sshd.u2f.enable = lib.mkIf config.modules.yubikey.sudoAuth false;

      programs.ssh = lib.mkIf config.modules.yubikey.sshKey {
        extraConfig = ''
          IdentityFile ~/.ssh/yubi_ed25519
          IdentitiesOnly yes
        '';
      };
      users.users.${config.modules.users.userName}.openssh.authorizedKeys.keys =
        lib.mkIf config.modules.yubikey.sshKey [(lib.trim (builtins.readFile yubiPub))];
      home-manager.users.${config.modules.users.userName} =
        lib.mkIf config.modules.yubikey.sshKey yubiCfg;
    };
  };

  flake.modules.homeManager.yubikey = yubiCfg;
}
