_:
let
  # Work fleet hosts live in the corporate Ansible inventory, which must not
  # be committed to this public repository. The generator reads the local
  # checkout and writes a private fragment under ~/.ssh/config.d instead.
  mkWorkSsh =
    pkgs:
    let
      python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
    in
    pkgs.writeShellScriptBin "sync-work-ssh" ''
      exec ${python}/bin/python3 ${../../scripts/sync-work-ssh.py} "$@"
    '';

  # Shared SSH client config. The default identity is the plain `id_ed25519`
  # key; feature modules append their own keys (e.g. the resident YubiKey) via
  # `modules.ssh.identityFiles`. `SecurityKeyProvider internal` is the OpenSSH
  # default for FIDO2/`-sk` keys and is inert when none are present.
  sshClient =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.ssh = {
        enable = lib.mkEnableOption "SSH client config";
        identityFiles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra identity files appended after the default ~/.ssh/id_ed25519";
        };
        workHosts = lib.mkEnableOption ''
          Generate ~/.ssh/config.d/work from the local infra_management
          inventory (corporate hosts stay out of this public repository)'';
      };
      config = lib.mkIf config.modules.ssh.enable (
        let
          syncWorkSsh = mkWorkSsh pkgs;
        in
        {
          # Local agent for key handles. Agent forwarding is only meaningful
          # with an agent running; the FIDO2 resident keys stay on the YubiKey
          # and every signature still needs a touch (or the software key's
          # passphrase) on the client. sshAuthSock exports SSH_AUTH_SOCK and
          # preserves a forwarded socket on hosts reached over SSH.
          services.ssh-agent.enable = true;
          programs.ssh = {
            enable = true;
            enableDefaultConfig = false;
            # devpod keeps its Host *.devpod entries in its own writable file
            # (SSH_CONFIG_PATH) because this config is a read-only store symlink.
            # The work fragment is generated at activation time (see below);
            # an unmatched glob is silently ignored by OpenSSH.
            includes = [
              "~/.config/devpod/ssh_config"
            ]
            ++ lib.optional config.modules.ssh.workHosts "~/.ssh/config.d/*";
            # PiHole serves workstation.alexyz.org (added with the other static
            # LAN names); use the name so the config survives address changes.
            # Trusted hosts opt in to agent forwarding here: onward ssh/git from
            # them uses the local agent (touch on the YubiKey at this end).
            settings.workstation = {
              HostName = "workstation.alexyz.org";
              ForwardAgent = "yes";
            };
            # Short aliases for the NAS (PiHole static records).
            settings.nas = {
              HostName = "nas.alexyz.org";
              ForwardAgent = "yes";
            };
            settings.backup-nas = {
              HostName = "nas.alexyz.org";
              ForwardAgent = "yes";
            };
            # Proxmox node (web UI on 8006, SSH on 22).
            settings.proxmox = {
              HostName = "proxmox.alexyz.org";
              ForwardAgent = "yes";
            };
            settings.pve = {
              HostName = "proxmox.alexyz.org";
              ForwardAgent = "yes";
            };
            settings."*" = {
              IdentityFile = [ "~/.ssh/id_ed25519" ] ++ config.modules.ssh.identityFiles;
              IdentitiesOnly = "yes";
              SecurityKeyProvider = "internal";
              # Connection multiplexing: the first SSH to a host pays the
              # handshake (and the YubiKey touch); later tabs, `ws` reattaches and
              # scp/git over SSH reuse the master socket for 10 minutes.
              # `ssh -O exit <host>` clears a stale master.
              ControlMaster = "auto";
              ControlPath = "~/.ssh/cm/%C";
              ControlPersist = "10m";
              ServerAliveInterval = 30;
              ServerAliveCountMax = 3;
              # Explicit, conservative client defaults (nothing here overrides a
              # per-host block): no forwarding unless a trusted host opts in,
              # no compression on LAN/VPN, a bounded connect timeout, and
              # hashed host names on disk. AddKeysToAgent loads a key into the
              # local agent on first use so it can be forwarded.
              AddKeysToAgent = "yes";
              ForwardAgent = "no";
              ForwardX11 = "no";
              ForwardX11Trusted = "no";
              Compression = "no";
              HashKnownHosts = "yes";
              StrictHostKeyChecking = "ask";
              UpdateHostKeys = "yes";
              TCPKeepAlive = "yes";
              IPQoS = "lowdelay throughput";
              ConnectTimeout = 10;
              ConnectionAttempts = 1;
              LogLevel = "INFO";
            };
          };
          home.file.".ssh/cm/.keep".text = "";
          home.packages = lib.optional config.modules.ssh.workHosts syncWorkSsh;
          # Refresh the private work fragment on every home-manager switch.
          # A missing inventory (personal machines, fresh checkout) is a no-op
          # in the generator, and a failure must never block activation.
          home.activation.workSsh = lib.mkIf config.modules.ssh.workHosts (
            lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              $DRY_RUN_CMD ${syncWorkSsh}/bin/sync-work-ssh --quiet || true
            ''
          );
        }
      );
    };
in
{
  nixconf.modules.nixos.ssh =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.ssh.enable = lib.mkEnableOption "SSH server (openssh + fail2ban)";
      config = lib.mkIf config.modules.ssh.enable {
        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            PermitRootLogin = "no";
          };
        };
        services.fail2ban.enable = true;
        networking.firewall.allowedTCPPorts = lib.mkDefault [ 22 ];
      };
    };

  nixconf.modules.homeManager.ssh = sshClient;
}
