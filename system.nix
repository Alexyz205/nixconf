# The secure target system installed from our ISO.
#
# Focus: maximum security with a sane, understandable baseline.
# Filesystems + LUKS come from disko-config.nix (imported in flake.nix).
#
# Tool strategy (hybrid):
#   - System tools installed declaratively below (reproducible, updated
#     with nixos-rebuild).
#   - Shared CLI tools below mirror config/mise/config.toml (copy manually
#     when that list changes), EXCLUDING runtimes (node, go, dotnet), which
#     are installed per-user with mise so versions can switch per project.
#     The `mise` binary itself is declared here.
#   - opencode and fabric are included (needed on this machine).
#   - Dotfiles (configs, nvim, tmux, starship, ...) come from the
#     dotfiles repo, cloned on the machine and linked by its installer.
{ config, lib, pkgs, ... }:

{
  # Minimum state version accepted. Keep it <= your nixpkgs version.
  system.stateVersion = "24.11";

  # --- Boot ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Load modules needed by rootless podman at boot, because
  # lockKernelModules forbids loading them later.
  boot.kernelModules = [ "overlay" "fuse" ];

  # --- Network ---
  networking.hostName = "nixos"; # CHANGE ME
  networking.networkmanager.enable = true;

  # --- Firewall: deny by default, open only SSH ---
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # --- SSH: key-based auth only ---
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Brute-force protection for sshd.
  services.fail2ban.enable = true;

  # --- Kernel / runtime hardening ---
  # No new kernel modules can be loaded after boot.
  security.lockKernelModules = true;
  # No core dumps (can leak process memory to disk).
  systemd.coredump.enable = false;

  boot.kernel.sysctl = {
    # Only root can read kernel messages / pointers.
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    # Reverse-path filtering: drop packets from unexpected source addresses.
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    # Ignore broadcast ping floods.
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
  };

  # --- Containers (devcontainers / devpod) ---
  # Rootless podman by default. The user socket runs per-login;
  # enable it to survive reboots with: loginctl enable-linger alexis
  virtualisation.podman = {
    enable = true;
    # `docker` CLI maps to podman.
    dockerCompat = true;
    # /run/docker.sock -> podman socket, so docker tools & devpod work.
    # Access is granted to the `podman` group.
    dockerSocket.enable = true;
    # Reclaim disk from old images/volumes weekly.
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # --- User account ---
  users.users.alexis = { # CHANGE ME
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "podman" ];
    # Account is LOCKED at install time (no password set).
    # After first boot: `sudo passwd alexis`
    # Or add your public key below for SSH access.
    initialHashedPassword = "!";
    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAA... you@example.com"
    ];
    # The dotfiles installer sets up zsh configs; make it the login shell.
    shell = pkgs.zsh;
  };

  security.sudo.wheelNeedsPassword = true;

  # --- Nix: only wheel users may run nix commands ---
  nix.settings.allowed-users = [ "@wheel" ];

  # --- Shell ---
  programs.zsh.enable = true;

  # --- Git ---
  programs.git.enable = true;

  # --- Packages (Nix-managed system tools) ---
  environment.systemPackages = with pkgs; [
    # editors / languages
    neovim
    vim
    tree-sitter
    mise # language runtimes (node, go, dotnet, ...) per-user
    gcc
    gnumake
    pkg-config

    # shell & prompt
    starship
    zoxide
    fzf
    tmux

    # file & text utilities
    eza
    bat
    fd
    ripgrep
    television # fuzzy finder (binary: tv)
    yazi
    dust
    duf
    fastfetch
    jq
    yq
    dasel
    htop
    file
    unzip

    # git tooling
    git
    lazygit
    delta
    glab
    gh

    # kubernetes
    kubectl
    helm
    helmfile
    k9s

    # containers
    devpod
    docker-compose
    podman-compose
    lazydocker

    # ai & development assistants (from config/mise/config.toml)
    opencode  # AI coding agent (anomalyco/opencode)
    fabric-ai # AI pattern framework (danielmiessler/fabric)

    # security / secrets
    pass
    age
    sops
    gnupg

    # basics
    curl
    wget
    openssl
  ];
}
