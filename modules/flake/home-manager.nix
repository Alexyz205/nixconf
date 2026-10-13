{
  inputs,
  config,
  self,
  ...
}:
let
  # Terminal-only tooling: the default for every host. Nothing GUI, hardware,
  # secret, or platform-specific lives here — those are opt-in extras.
  baseModules = with config.nixconf.modules.homeManager; [
    packages
    nix
    shell
    git
    bitwarden
    ssh
    bat
    eza
    zoxide
    starship
    tmux
    yazi
    swayimg
    lazygit
    lazyvim
    btop
    tv
    devenv
    opencode
  ];
  # Opt-in extras, each gated by its own `enable` option. Every extra follows
  # the same shape: the feature module + the flag that switches it on.
  extras = with config.nixconf.modules.homeManager; {
    sops = [
      inputs.sops-nix.homeManagerModules.sops
      sops
      { modules.sops.enable = true; }
    ];
    yubikey = [
      yubikey
      { modules.yubikey.enable = true; }
    ];
    ghostty = [
      ghostty
      { modules.ghostty.enable = true; }
    ];
    containers = [
      containers
      { modules.containers.enable = true; }
    ];
    gitlab = [
      gitlab
      { modules.gitlab.enable = true; }
    ];
    nextcloud = [
      nextcloud
      { modules.nextcloud.enable = true; }
    ];
    brave = [
      brave
      { modules.brave.enable = true; }
    ];
    claude = [
      claude
      { modules.claude.enable = true; }
    ];
    youtubeMusic = [
      youtubeMusic
      { modules.youtubeMusic.enable = true; }
    ];
    cap = [
      cap
      { modules.cap.enable = true; }
    ];
    thunderbird = [
      thunderbird
      { modules.thunderbird.enable = true; }
    ];
    photocraft = [
      photocraft
      { modules.photocraft.enable = true; }
    ];
    lightcraft = [
      lightcraft
      { modules.lightcraft.enable = true; }
    ];
    pdfcraft = [
      pdfcraft
      { modules.pdfcraft.enable = true; }
    ];
    filmcraft = [
      filmcraft
      { modules.filmcraft.enable = true; }
    ];
    wordcraft = [
      wordcraft
      { modules.wordcraft.enable = true; }
    ];
    gridcraft = [
      gridcraft
      { modules.gridcraft.enable = true; }
    ];
    cadcraft = [
      cadcraft
      { modules.cadcraft.enable = true; }
    ];
    deckcraft = [
      deckcraft
      { modules.deckcraft.enable = true; }
    ];
    soundcraft = [
      soundcraft
      { modules.soundcraft.enable = true; }
    ];
  };
  # Full ArtCraft suite (Linux-only flake packages), part of the default
  # desktop set.
  artcraft =
    extras.photocraft
    ++ extras.lightcraft
    ++ extras.pdfcraft
    ++ extras.filmcraft
    ++ extras.wordcraft
    ++ extras.gridcraft
    ++ extras.cadcraft
    ++ extras.deckcraft
    ++ extras.soundcraft;

  # The default set pulls in unfree brave (and personal adds claude), so allow
  # both here in one predicate rather than letting two modules fight over the
  # single `allowUnfreePredicate` option.
  allowDefaultUnfree = {
    nixpkgs.config.allowUnfreePredicate =
      pkg:
      builtins.elem (inputs.nixpkgs.lib.getName pkg) [
        "brave"
        "claude-desktop"
      ];
  };

  # Tier 1 — the default desktop set every interactive Linux profile starts
  # from: dotfiles support (sops/yubikey/ghostty/containers), the common apps
  # (gitlab, youtube-music, brave, cap, artcraft, vlc) and their unfree hook.
  defaultExtra =
    extras.sops
    ++ extras.yubikey
    ++ extras.ghostty
    ++ extras.containers
    ++ extras.gitlab
    ++ extras.youtubeMusic
    ++ extras.brave
    ++ extras.cap
    ++ artcraft
    ++ [
      { modules.packages.desktop = true; }
      allowDefaultUnfree
    ];

  # Tier 2 — personal machines: the default set plus the personal-only apps.
  personalExtra = defaultExtra ++ extras.claude ++ extras.thunderbird ++ extras.nextcloud;

  # Tier 2 — the two work stations (RNSL/RNSW) share one config so they can
  # never drift. Currently just the default set (no claude/thunderbird/nextcloud);
  # keep the name so work-only additions have an obvious home.
  workExtra = defaultExtra;

  # macOS can't run the Linux-only packages (brave/cap/artcraft/youtube-music,
  # and the `desktop` group's vlc which has no aarch64-darwin build), so it gets
  # a cross-platform subset of the default set.
  macosExtra =
    extras.sops
    ++ extras.yubikey
    ++ extras.ghostty
    ++ extras.containers
    ++ extras.gitlab
    ++ [ { modules.packages.desktop = true; } ];

  # Required for standalone home-manager on non-NixOS Linux: wires nix.sh into
  # the shell config so $HOME/.nix-profile/bin lands on PATH in managed shells.
  # Every non-darwin standalone config targets a non-NixOS host (Ubuntu desktop,
  # server, container, RNSL), so this is auto-derived from the system instead of
  # hand-listed per host — any future Linux profile gets it for free.
  genericLinux = {
    targets.genericLinux.enable = true;
  };

  mkHome =
    {
      system,
      username,
      homeDirectory,
      modules ? baseModules,
      extra ? [ ],
      hmProfile ? null,
    }:
    let
      baseModule =
        {
          pkgs,
          ...
        }:
        {
          home = {
            inherit username homeDirectory;
            stateVersion = "26.05";
          };
          # List of all Modules for home-manager profile
          modules = {
            packages = {
              basic = true;
              security = true;
              devTools = true;
            };
            nix.enable = true;
            shell.enable = true;
            ssh.enable = true;
            git.enable = true;
            bitwarden.enable = true;
            bat.enable = true;
            eza.enable = true;
            zoxide.enable = true;
            starship.enable = true;
            tmux.enable = true;
            yazi.enable = true;
            swayimg.enable = pkgs.stdenv.hostPlatform.isLinux;
            lazygit.enable = true;
            lazyvim.enable = true;
            btop.enable = true;
            tv.enable = true;
            devenv.enable = true;
            opencode.enable = true;
          };
          home.packages = [ pkgs.nixfmt ];
          gtk.gtk4.theme = null;
        };
      # Point the hm aliases at this profile's own flake key so `hm` switches
      # the right configuration on standalone Linux profiles.
      shellTarget = inputs.nixpkgs.lib.mkIf (hmProfile != null) {
        modules.shell.hmProfile = hmProfile;
      };
      # Any non-darwin target is a non-NixOS Linux host, so genericLinux is
      # always part of the module set (see comment above).
      linuxModules = inputs.nixpkgs.lib.optionals (inputs.nixpkgs.lib.hasSuffix "linux" system) [
        genericLinux
      ];
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      # Apply the flake's overlays (e.g. the fetchgit CA wrapper) so standalone
      # profiles get the same patched fetchers as NixOS hosts.
      pkgs = inputs.nixpkgs.legacyPackages.${system}.extend (
        inputs.nixpkgs.lib.composeManyExtensions config.nixconf.modules.overlays
      );
      extraSpecialArgs = {
        inherit (inputs) lazyvim;
        inherit self;
      };
      modules = [ baseModule ] ++ modules ++ extra ++ linuxModules ++ [ shellTarget ];
    };
  # Container profiles: terminal-only, no extras. Plain images run as root;
  # devcontainer base images run as their non-root `vscode` user, so both get a
  # profile. install.sh picks `${user}@container` at runtime via `id -un`, so a
  # new container user is one more `username = homeDir;` entry here.
  containerUsers = {
    root = "/root";
    vscode = "/home/vscode";
  };
  containerConfigs = inputs.nixpkgs.lib.mapAttrs' (username: homeDirectory: {
    name = "${username}@container";
    value = mkHome {
      system = "x86_64-linux";
      inherit username homeDirectory;
      hmProfile = "${username}@container";
      extra = [ ];
    };
  }) containerUsers;
in
{
  flake-file.inputs.home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.homeConfigurations = {
    "alexis@macos" = mkHome {
      system = "aarch64-darwin";
      username = "alexis";
      homeDirectory = "/Users/alexis";
      hmProfile = "alexis@macos";
      extra = macosExtra;
    };
    "alexis@linux" = mkHome {
      system = "x86_64-linux";
      username = "alexis";
      homeDirectory = "/home/alexis";
      hmProfile = "alexis@linux";
      extra = personalExtra;
    };
    # The two work stations share one config (see workExtra). RNSL is the
    # original machine, RNSW the newer Ubuntu/GNOME one; only the profile key
    # differs.
    "alexis.pigeon@RNSL-APIGEON5" = mkHome {
      system = "x86_64-linux";
      username = "alexis.pigeon";
      homeDirectory = "/home/alexis.pigeon";
      hmProfile = "alexis.pigeon@RNSL-APIGEON5";
      extra = workExtra;
    };
    "alexis.pigeon@RNSW-APIGEON1" = mkHome {
      system = "x86_64-linux";
      username = "alexis.pigeon";
      homeDirectory = "/home/alexis.pigeon";
      hmProfile = "alexis.pigeon@RNSW-APIGEON1";
      extra = workExtra;
    };
    # Headless Ubuntu server: terminal-only, no GUI extras.
    "alexis@server" = mkHome {
      system = "x86_64-linux";
      username = "alexis";
      homeDirectory = "/home/alexis";
      hmProfile = "alexis@server";
      extra = extras.sops;
    };
  }
  // containerConfigs;
}
