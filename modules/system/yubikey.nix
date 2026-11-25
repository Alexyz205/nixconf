{
  lib,
  ...
}:
let
  yubiKey = "id_ed25519_sk_rk_alexis-perso";
  yubiPub = "${../../config/ssh}/${yubiKey}.pub";
  u2fOrigin = "pam://localhost";
  u2fMapping = ../../config/Yubico/u2f_keys;

  yubiCfg =
    {
      pkgs,
      ...
    }:
    let
      u2fKeyFile = lib.optionalAttrs (builtins.pathExists u2fMapping) {
        ".config/Yubico/u2f_keys".source = u2fMapping;
      };
    in
    {
      home.packages = with pkgs; [
        yubikey-manager
        libu2f-host
        pam_u2f
      ];
      # Only the public key is tracked. The FIDO2 private handle is downloaded
      # from the resident key on each machine with `ssh-keygen -K` (see the
      # enrollment notes below) and stays in ~/.ssh, never in git.
      home.file = {
        ".ssh/${yubiKey}.pub".source = yubiPub;
      }
      // u2fKeyFile;
      # Append the resident YubiKey to the default identity list owned by the
      # ssh module (id_ed25519 stays primary).
      modules.ssh.identityFiles = [ "~/.ssh/${yubiKey}" ];
    };
in
{
  nixconf.modules.nixos.yubikey =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
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
          description = "Unlock the disko LUKS volume (crypted) with a FIDO2 YubiKey at boot (touch, optional PIN)";
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
      #             pamu2fcfg -u <user> -o pam://localhost > config/Yubico/u2f_keys
      # SSH:      download the resident key handle on each machine (touch +
      #           FIDO2 PIN). It stays in ~/.ssh and is NOT committed — only
      #           the .pub is tracked. Home-manager points at the file, so run
      #           this once per host before relying on the key:
      #             ssh-keygen -K
      #           (writes ~/.ssh/id_ed25519_sk_rk_alexis-perso{,.pub}; the
      #           public half in config/ssh/ is the authoritative copy)
      config = lib.mkIf config.modules.yubikey.enable {
        environment.systemPackages = with pkgs; [
          yubikey-manager
          libu2f-host
          pam_u2f
        ];
        services.udev.packages = [ pkgs.yubikey-personalization ];

        # --- LUKS unlock with a FIDO2 token via systemd stage-1 -----------------
        # Do not set disko's enrollFido2 here: it also defines the removed
        # boot.initrd.systemd.enable option. The installer overrides
        # enrollFido2 when it runs disko, so enrollment still happens at install
        # time; runtime only needs the crypttab option below.
        boot.initrd.luks.devices.crypted.crypttabExtraOpts = lib.mkIf config.modules.yubikey.luksUnlock [
          "fido2-device=auto"
        ];
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
            IdentityAgent none
          '';
        };
        users.users.${config.modules.users.userName}.openssh.authorizedKeys.keys =
          lib.mkIf config.modules.yubikey.sshKey
            [ (lib.trim (builtins.readFile yubiPub)) ];
        home-manager.users = lib.genAttrs config.modules.users.homeUsers (
          _: lib.mkIf config.modules.yubikey.sshKey yubiCfg
        );
      };
    };

  nixconf.modules.homeManager.yubikey =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.yubikey.enable = lib.mkEnableOption "YubiKey hardware auth";
      config = lib.mkIf config.modules.yubikey.enable (yubiCfg {
        inherit pkgs;
      });
    };
}
