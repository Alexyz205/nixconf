{
  lib,
  ...
}: let
  yubiKey = "id_ed25519_sk_rk_alexis-perso";
  yubiPub = "${./config/ssh}/${yubiKey}.pub";
  handle = "${./config/ssh}/${yubiKey}";
  u2fOrigin = "pam://localhost";
  u2fMapping = ./config/Yubico/u2f_keys;

  yubiCfg = {
    pkgs,
    ...
  }: {
    home.packages = with pkgs; [
      yubikey-manager
      libu2f-host
      pam_u2f
    ];
    home.file.".ssh/${yubiKey}.pub".source = yubiPub;
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."*" = {
        IdentityFile = "~/.ssh/${yubiKey}";
        IdentitiesOnly = "yes";
        SecurityKeyProvider = "internal";
      };
    };
  } // lib.optionalAttrs (builtins.pathExists handle) {
    home.file.".ssh/${yubiKey}".source = handle;
  } // lib.optionalAttrs (builtins.pathExists u2fMapping) {
    home.file.".config/Yubico/u2f_keys".source = u2fMapping;
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
        description = "Use the resident FIDO2 YubiKey SSH key (~/.ssh/${yubiKey}) for git/ssh";
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

    # One-time enrollments:
    #
    # LUKS:     disko enrolls automatically during disko-install
    # Sudo/PAM: pre-register ONCE, bound to this ISO's YubiKey, and commit:
    #             pamu2fcfg -u <user> -o pam://localhost > modules/config/Yubico/u2f_keys
    # SSH:      recover the resident key handle ONCE into the repo:
    #             ssh-keygen -K
    #             mv ~/id_ed25519_sk_rk_alexis-perso modules/config/ssh/${yubiKey}
    #             mv ~/id_ed25519_sk_rk_alexis-perso.pub modules/config/ssh/${yubiKey}.pub
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
          origin = u2fOrigin;
        };
      };
      security.pam.services.sshd.u2f.enable = lib.mkIf config.modules.yubikey.sudoAuth false;

      programs.ssh = lib.mkIf config.modules.yubikey.sshKey {
        extraConfig = ''
          IdentityFile ~/.ssh/${yubiKey}
          IdentitiesOnly yes
          SecurityKeyProvider internal
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
