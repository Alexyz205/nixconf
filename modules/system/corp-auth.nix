_:
let
  corpSecrets = ../../secrets/corp.yaml;
in
{
  nixconf.modules.nixos.corpAuth =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.modules.corpAuth;
      inherit (cfg) realm domain;
      bindPasswordSecret = "corp/ldap_bind_password";

      # T2 Palo Alto inspection root CA, pulled from the asset mirror instead of
      # being vendored in this repo. The hash pins the current certificate
      # (valid 2025-04-02 .. 2035-03-31); on rotation, bump the URL and hash via
      # `nix-prefetch-url <url>`.
      t2RootCa = pkgs.fetchurl {
        url = "https://packages.gametools.dev/artifactory/dxz-assets/t2certs/T2-Palo-root-2025.crt";
        hash = "sha256-SUWhMd0Hmj5LiOF3U6wved7VtJtvnYA2hNEnwEewwqI=";
      };
    in
    {
      options.modules.corpAuth = {
        enable = lib.mkEnableOption "Take-Two LDAP/Kerberos login (SSSD) + T2 root CA";

        realm = lib.mkOption {
          type = lib.types.str;
          default = "TAKE2.T2.CORP";
          description = "Kerberos realm of the corporate AD.";
        };

        domain = lib.mkOption {
          type = lib.types.str;
          default = "take2.t2.corp";
          description = "Lowercase DNS domain handed to SSSD.";
        };

        ldapUri = lib.mkOption {
          type = lib.types.str;
          default = "ldaps://ldap-gc.core.t010.net:3269";
          description = "Global catalog URI used for LDAP lookups.";
        };

        bindDn = lib.mkOption {
          type = lib.types.str;
          default = "CN=svctk2rnsldap,OU=Users,OU=TK2 Universal Objects,DC=take2,DC=t2,DC=corp";
          description = "Service account used to bind to LDAP.";
        };

        accessGroups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "S_TK2_IT_Systems"
            "S_TK2RNS_AllEmployees"
            "s_tk2_linux_automation_ssh"
            "svctk2snowlinux"
          ];
          description = "AD groups allowed to log in (ldap_access_filter).";
        };

        sudoGroups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "S_TK2RNS_d_CompMgr"
            "S_TK2_IT_Systems"
            "s_tk2_linux_automation_ssh"
            "svctk2snowlinux"
          ];
          description = "AD groups granted passwordless-prompt sudo on this host.";
        };

        defaultShell = lib.mkOption {
          type = lib.types.str;
          default = "/run/current-system/sw/bin/zsh";
          description = "Login shell assigned to corporate accounts.";
        };

        accounts = lib.mkOption {
          type = lib.types.attrsOf lib.types.int;
          default = { };
          example = {
            "alexis.pigeon" = 1755687199;
          };
          description = ''
            Corporate accounts that also get a local /etc/passwd entry, mapping
            the user name to its AD-mapped uid. home-manager needs
            users.users.<name> to exist, and the entry must carry the same ids
            SSSD derives from the user's SID or home ownership and group lookups
            diverge. No password is set, so PAM falls through to pam_sss.
          '';
        };

        domainUsersGid = lib.mkOption {
          type = lib.types.int;
          default = 1755600513;
          description = "AD-mapped gid of the 'domain users' group.";
        };

        installCa = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Trust the Take-Two Palo Alto inspection root CA system-wide.";
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets.${bindPasswordSecret} = {
          sopsFile = corpSecrets;
          owner = "root";
          group = "root";
          mode = "0400";
        };

        # sssd.conf is substituted with envsubst from this file, so the bind
        # password never lands in the world-readable Nix store.
        sops.templates."sssd-env".content = ''
          SSSD_LDAP_PASSWORD=${config.sops.placeholder.${bindPasswordSecret}}
        '';

        security.krb5.enable = true;
        security.krb5.settings = {
          libdefaults = {
            default_realm = realm;
            rdns = false;
            dns_lookup_kdc = true;
            dns_lookup_realm = true;
            ticket_lifetime = "24h";
            renew_lifetime = "7d";
            forwardable = false;
            fcc-mit-ticketflags = true;
          };
          realms.${realm} = {
            kdc = [ domain ];
            admin_server = domain;
          };
          realms."TAKE2GAMES.COM" = {
            kdc = [ domain ];
            admin_server = domain;
          };
          domain_realm = {
            ".${domain}" = realm;
            "${domain}" = realm;
            ".take2games.com" = "TAKE2GAMES.COM";
            "take2games.com" = "TAKE2GAMES.COM";
          };
        };

        security.pki.certificates = lib.mkIf cfg.installCa [ (builtins.readFile t2RootCa) ];

        services.sssd = {
          enable = true;
          environmentFile = config.sops.templates."sssd-env".path;
          settings = {
            sssd = {
              domains = domain;
              config_file_version = 2;
              services = "nss, pam";
            };
            nss = { };
            pam = {
              offline_credentials_expiration = 90;
            };
            "domain/${domain}" = {
              debug_level = 2;
              id_provider = "ldap";
              auth_provider = "krb5";
              chpass_provider = "krb5";
              access_provider = "ldap";
              dns_discovery_domain = domain;
              use_fully_qualified_names = false;
              case_sensitive = false;
              ldap_schema = "ad";
              ldap_uri = cfg.ldapUri;
              # ldaps:// already negotiates TLS; StartTLS on 3269 breaks the
              # handshake ("TLS handshake was interrupted") and flaps the backend.
              ldap_id_use_start_tls = false;
              ldap_default_bind_dn = cfg.bindDn;
              ldap_default_authtok_type = "password";
              # Expanded from $SSSD_LDAP_PASSWORD through environmentFile.
              ldap_default_authtok = "$SSSD_LDAP_PASSWORD";
              ldap_user_search_base = "dc=take2,dc=t2,dc=corp";
              ldap_user_object_class = "user";
              ldap_user_principal = "userPrincipalName";
              ldap_group_search_base = "dc=take2,dc=t2,dc=corp";
              ldap_group_object_class = "group";
              ldap_access_order = "expire";
              ldap_account_expire_policy = "ad";
              ldap_user_name = "sAMAccountName";
              ldap_group_name = "cn";
              ldap_force_upper_case_realm = true;
              ldap_referrals = true;
              ldap_id_mapping = true;
              ldap_user_gecos = "displayName";
              ldap_access_filter =
                "(&(|(objectclass=user)(objectclass=group))(|"
                + lib.concatMapStrings (g: "(cn=${g})") cfg.accessGroups
                + "))";
              enumerate = false;
              krb5_realm = realm;
              krb5_server = domain;
              krb5_canonicalize = false;
              krb5_use_enterprise_principal = true;
              fallback_homedir = "/home/%u";
              cache_credentials = true;
              account_cache_expiration = 90;
              default_shell = cfg.defaultShell;
            };
          };
        };

        # pam_mkhomedir has to be on the services a corporate user reaches us
        # through: the greeter, a TTY login and su.
        security.pam.services = {
          login.makeHomeDir = true;
          greetd.makeHomeDir = true;
          su.makeHomeDir = true;
        };
        users.defaultUserShell = pkgs.zsh;

        # The nix daemon only allows @wheel here; domain accounts are not local
        # wheel members, so their home-manager activation would be refused
        # ("user 'x' is not allowed to connect to the Nix daemon").
        nix.settings.allowed-users = lib.mkAfter (lib.attrNames cfg.accounts);

        users.groups."domain users" = {
          gid = cfg.domainUsersGid;
        };
        users.users = lib.mapAttrs (name: uid: {
          isNormalUser = true;
          inherit uid;
          group = "domain users";
          home = "/home/${name}";
          createHome = true;
          shell = cfg.defaultShell;
          extraGroups = [
            "networkmanager"
            "video"
            "audio"
            "dialout"
            "podman"
          ];
        }) cfg.accounts;

        # Sudo rights come from AD group membership, as in the Ubuntu script.
        environment.etc."sudoers.d/90-corp-groups" = {
          mode = "0440";
          text = lib.concatMapStrings (group: "%${group}@${domain} ALL=(ALL) ALL\n") cfg.sudoGroups;
        };
      };
    };
}
