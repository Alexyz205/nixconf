{
  inputs,
  config,
  ...
}:
let
  secretsFile = ../../secrets/secrets.yaml;
  # Both YubiKey stubs, so any host can decrypt the secret that matches the
  # plugged key: personal -> secrets.yaml, work -> corp.yaml.
  ageIdentities = ../../config/sops/age-identities;
  homeSopsModule = config.nixconf.modules.homeManager.sops;
in
{
  flake-file.inputs.sops-nix = {
    url = "github:Mic92/sops-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixconf.modules.nixos.sops =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.sops = {
        enable = lib.mkEnableOption "Sops secrets (NixOS side)";
        secretsFile = lib.mkOption {
          type = lib.types.path;
          default = secretsFile;
          description = ''
            Default sops file for NixOS secrets. Hosts that keep their own
            secrets (e.g. a corporate host with corp.yaml) point this at a
            dedicated file instead of secrets.yaml.
          '';
        };
        homeManagerSecrets = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Wire the home-manager sops module (sec/secc/secx aliases). Disable on
            hosts whose age identity cannot decrypt secrets.yaml.
          '';
        };
        useYubikey = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether the boot-time age identity lives on a YubiKey. When false,
            skips the age-plugin-yubikey package and the /etc/yubi-age-identity
            provisioning (hosts that must decrypt unattended).
          '';
        };
        interactiveYubikey = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Install pcscd and the YubiKey plugin so sops files can be opened and
            edited with the YubiKey (sec/secc/secx), while unattended activation
            keeps using modules.sops.ageKeyFile.
          '';
        };
        yubiIdentityFile = lib.mkOption {
          type = lib.types.path;
          default = ageIdentities;
          description = ''
            YubiKey age identity stub shipped to /etc/yubi-age-identity. Override
            on hosts that use a different physical key (e.g. the work YubiKey).
          '';
        };
        ageKeyFile = lib.mkOption {
          type = lib.types.str;
          default = "/etc/yubi-age-identity";
          description = ''
            Age identity file used to decrypt sops secrets. Defaults to the
            YubiKey identity; point at a software age key on hosts without
            YubiKey access (e.g. the workstation).
          '';
        };
      };
      config = lib.mkIf config.modules.sops.enable {
        sops = {
          defaultSopsFile = config.modules.sops.secretsFile;
          age = {
            keyFile = lib.mkDefault config.modules.sops.ageKeyFile;
            sshKeyPaths = [ ];
            generateKey = false;
            plugins = lib.mkIf config.modules.sops.useYubikey [ pkgs.age-plugin-yubikey ];
          };
          gnupg.sshKeyPaths = [ ];
          # Decrypt from a systemd unit instead of the activation script:
          # nixos-install runs the activation script inside the target, where the
          # age key does not exist yet, so an activation-time install aborts the
          # install. With the unit a missing key only fails the service (boot
          # continues), and `systemctl restart sops-install-secrets` picks it up
          # once the key is in place.
          useSystemdActivation = true;
        };
        environment.etc."yubi-age-identity" = lib.mkIf config.modules.sops.useYubikey {
          source = config.modules.sops.yubiIdentityFile;
        };
        services.pcscd.enable = lib.mkIf (
          config.modules.sops.useYubikey || config.modules.sops.interactiveYubikey
        ) true;
        environment.systemPackages = lib.optional (
          config.modules.sops.useYubikey || config.modules.sops.interactiveYubikey
        ) pkgs.age-plugin-yubikey;
        # Per-user rather than sharedModules: a host can then give each managed
        # account its own age identity (see modules.sops.ageKeyFile), while
        # still enrolling every account in homeUsers.
        home-manager.users = lib.genAttrs config.modules.users.homeUsers (
          _:
          lib.mkIf config.modules.sops.homeManagerSecrets {
            imports = [
              inputs.sops-nix.homeManagerModules.sops
              homeSopsModule
            ];
            modules.sops.enable = true;
          }
        );
      };
    };

  nixconf.modules.homeManager.sops =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Interactive edits use the YubiKey whenever it is available, even on hosts
      # whose unattended activation must use a software key (no touch at boot).
      sopsAliases = {
        sec = "SOPS_AGE_KEY_FILE=${config.modules.sops.interactiveAgeKeyFile} sops $NIXCONF/secrets/secrets.yaml";
        secc = "SOPS_AGE_KEY_FILE=${config.modules.sops.interactiveAgeKeyFile} sops $NIXCONF/secrets/corp.yaml";
        secx = "SOPS_AGE_KEY_FILE=${config.modules.sops.interactiveAgeKeyFile} sops";
      };
    in
    {
      options.modules.sops = {
        enable = lib.mkEnableOption "Sops secrets (secrets.yaml, sec alias)";
        useYubikey = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether the boot-time age identity lives on a YubiKey. When false,
            unattended activation decrypts with a software age key.
          '';
        };
        interactiveYubikey = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Ship the YubiKey age identity to ~/.config/sops/yubi-age-identity and
            install age-plugin-yubikey, so sec/secc/secx open secrets with the
            YubiKey even when boot uses a software key.
          '';
        };
        yubiIdentityFile = lib.mkOption {
          type = lib.types.path;
          default = ageIdentities;
          description = ''
            YubiKey age identity stub shipped to ~/.config/sops/yubi-age-identity.
            Override per user when the host uses a different physical key.
          '';
        };
        ageKeyFile = lib.mkOption {
          type = lib.types.str;
          default = "${
            config.modules.shell.nixconfPath or "${config.home.homeDirectory}/repos/personal/nixconf"
          }/config/sops/yubi-age-identity";
          description = ''
            Age identity file used to decrypt sops secrets. Defaults to the
            YubiKey identity; point at a software age key on hosts without
            YubiKey access (e.g. the workstation).
          '';
        };
        secretsFile = lib.mkOption {
          type = lib.types.path;
          default = secretsFile;
          description = ''
            Default sops file for home-manager secrets. Hosts whose identity
            cannot decrypt secrets.yaml point this at their own file.
          '';
        };
        interactiveAgeKeyFile = lib.mkOption {
          type = lib.types.str;
          default =
            if config.modules.sops.useYubikey || config.modules.sops.interactiveYubikey then
              "${config.home.homeDirectory}/.config/sops/yubi-age-identity"
            else
              config.modules.sops.ageKeyFile;
          defaultText = lib.literalExpression "the YubiKey identity when modules.sops.useYubikey or modules.sops.interactiveYubikey, else modules.sops.ageKeyFile";
          description = ''
            Identity used by the sec/secc/secx aliases. Separate from
            modules.sops.ageKeyFile so an unattended activation can decrypt with
            a software key while interactive edits still require the YubiKey.
          '';
        };
      };
      # The sops-nix base module is imported at the composition level (paired with
      # this feature + enable in home-manager.nix), so hosts without a YubiKey
      # (server, containers) never pull it in.
      config = lib.mkIf config.modules.sops.enable {
        sops = {
          age = {
            keyFile = config.modules.sops.ageKeyFile;
            plugins = lib.optional config.modules.sops.useYubikey pkgs.age-plugin-yubikey;
          };
          defaultSopsFile = config.modules.sops.secretsFile;
        };
        # `age.plugins` only feeds the sops-nix activation unit; the interactive
        # `sops`/`sec` invocation runs with the user's PATH, so the plugin has
        # to be installed too or decryption fails with "yubikey plugin not
        # found".
        home.packages = lib.optional (
          config.modules.sops.useYubikey || config.modules.sops.interactiveYubikey
        ) pkgs.age-plugin-yubikey;
        # The YubiKey identity is a stub that lives in the repo; ship it to the
        # user's home so the aliases work wherever the repo is cloned or absent.
        home.file = lib.mkIf (config.modules.sops.useYubikey || config.modules.sops.interactiveYubikey) {
          ".config/sops/yubi-age-identity".source = config.modules.sops.yubiIdentityFile;
        };
        programs.zsh.shellAliases = sopsAliases;
        programs.zsh.initContent = lib.mkOrder 950 ''
          export SOPS_AGE_KEY_FILE="${config.modules.sops.ageKeyFile}"
        '';
      };
    };
}
