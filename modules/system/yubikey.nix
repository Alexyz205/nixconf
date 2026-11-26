{
  lib,
  ...
}:
let
  # Resident FIDO2 SSH keys. Only the .pub halves are tracked; the private
  # handles are downloaded per machine with `ssh-keygen -K`.
  personalYubiKey = "id_ed25519_sk_rk_alexis-perso";
  yubiKeys = [
    personalYubiKey
    "id_ed25519_sk_rk_alexis-work"
  ];
  keyPub = key: ../../config/ssh + "/${key}.pub";
  # The work .pub appears only after it has been generated and committed.
  presentYubiKeys = builtins.filter (key: builtins.pathExists (keyPub key)) yubiKeys;
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
      # Only the public keys are tracked. The FIDO2 private handles are
      # downloaded from the resident keys on each machine with `ssh-keygen -K`
      # (see the enrollment notes below) and stay in ~/.ssh, never in git.
      home.file =
        builtins.listToAttrs (
          map (key: {
            name = ".ssh/${key}.pub";
            value.source = keyPub key;
          }) presentYubiKeys
        )
        // u2fKeyFile;
      # Append the resident YubiKeys to the default identity list owned by the
      # ssh module (id_ed25519 stays primary).
      modules.ssh.identityFiles = map (key: "~/.ssh/${key}") presentYubiKeys;
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
          description = "Use the resident FIDO2 YubiKey SSH keys (personal and work) for git/ssh";
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
      # Sudo/PAM: pre-register ONCE per key and user, bound to this origin, and
      # commit the mapping. Multiple credentials for one user are joined with
      # ':' on the same line:
      #             pamu2fcfg -u <user> -o pam://localhost
      #           The personal key and the work key can both authenticate the
      #           same user, or one key per user (alexis vs alexis.pigeon).
      # SSH:      download the resident key handles on each machine (touch +
      #           FIDO2 PIN). They stay in ~/.ssh and are NOT committed — only
      #           the .pub halves are tracked. Home-manager points at the files,
      #           so run this once per host before relying on the keys:
      #             ssh-keygen -K
      #           (writes ~/.ssh/id_ed25519_sk_rk_alexis-{perso,work}; the
      #           public halves in config/ssh/ are the authoritative copies)
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
            ${lib.concatMapStringsSep "\n" (key: "IdentityFile ~/.ssh/${key}") presentYubiKeys}
            IdentitiesOnly yes
            SecurityKeyProvider internal
            IdentityAgent none
          '';
        };
        # Personal hosts authorize only the personal key. The work public key
        # is installed on the work fleet by Ansible (and can be added to GitHub).
        users.users.${config.modules.users.userName}.openssh.authorizedKeys.keys =
          lib.mkIf config.modules.yubikey.sshKey (
            lib.optional (builtins.pathExists (keyPub personalYubiKey)) (
              lib.trim (builtins.readFile (keyPub personalYubiKey))
            )
          );
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
