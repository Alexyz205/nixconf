{lib, ...}: let
  yubiPub = ./config/ssh/yubi_ed25519.pub;
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
      # disko's luks 'enrollFido2' enrolls the token during a fresh disko
      # install AND injects fido2-device=auto into the initrd crypttab, so the
      # runtime half (with passphrase-slot fallback) is declarative as well.
      # Stage-1 still needs the FIDO2 udev rules + libfido2 + systemd's
      # libcryptsetup-token-systemd-fido2.so inside the initrd image.
      disko.devices.disk.main.content.partitions.luks.content.enrollFido2 =
        lib.mkIf config.modules.yubikey.luksUnlock true;
      boot.initrd.systemd.fido2.enable = lib.mkIf config.modules.yubikey.luksUnlock true;

      # --- Touch instead of sudo/login password (pam_u2f) ----------------------
      # 'sufficient' -> touch replaces the password, falls back to it without the
      # key. Switch to 'required' to demand touch AND password (true 2FA).
      # sshd stays key-only: never ask for a touch on incoming SSH logins.
      security.pam.u2f = lib.mkIf config.modules.yubikey.sudoAuth {
        enable = true;
        control = "sufficient";
        settings = {
          cue = true;
          interactive = true;
        };
      };
      security.pam.services.sshd.u2f.enable = lib.mkIf config.modules.yubikey.sudoAuth false;

      # Offer the resident FIDO2 key to every host. The key handle (recovered once
      # with `ssh-keygen -K`, not a secret) is installed from the repo too when it
      # has been committed to config/ssh/yubi_ed25519.
      programs.ssh.extraConfig = lib.mkIf config.modules.yubikey.sshKey ''
        IdentityFile ~/.ssh/yubi_ed25519
      '';
      home-manager.users.${config.modules.users.userName} =
        lib.mkIf config.modules.yubikey.sshKey (let
          handle = ./config/ssh/yubi_ed25519;
        in {
          home.file.".ssh/yubi_ed25519.pub".source = yubiPub;
        } // lib.optionalAttrs (builtins.pathExists handle) {
          home.file.".ssh/yubi_ed25519" = {
            source = handle;
            mode = "0600";
          };
        });
    };
  };

  flake.modules.homeManager.yubikey = {pkgs, ...}: let
    handle = ./config/ssh/yubi_ed25519;
  in {
    home.packages = [pkgs.yubikey-manager pkgs.libu2f-host pkgs.pam_u2f];
    home.file.".ssh/yubi_ed25519.pub".source = yubiPub;
  } // lib.optionalAttrs (builtins.pathExists handle) {
    home.file.".ssh/yubi_ed25519" = {
      source = handle;
      mode = "0600";
    };
  };
}