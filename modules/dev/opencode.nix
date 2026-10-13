_:
let
  # Upstream is a single, dependency-free ESM module published to npm and loaded
  # by OpenCode itself as a plugin. We package the tarball and symlink the JS
  # into the global plugins dir; the plugin writes per-process state
  # (~/.local/state/opencode/agent-status/<pid>.json) keyed by the inherited
  # TMUX_PANE, which the tmux-agent-status classify patch reads for real
  # working/blocked/idle badges (it also works when opencode runs on a nested
  # pty, since TMUX_PANE is inherited).
  opencodeSessionStatus =
    pkgs:
    pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
      pname = "opencode-session-status";
      version = "0.3.0";
      src = pkgs.fetchurl {
        url = "https://registry.npmjs.org/opencode-session-status/-/opencode-session-status-${finalAttrs.version}.tgz";
        hash = "sha256-NXuHf/BnKFVjI5+PwPjTYrIFVbhiKfrf4DS6y7SIKF0=";
      };
      sourceRoot = "package";
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out/lib/opencode-session-status
        cp opencode-session-status.js package.json LICENSE $out/lib/opencode-session-status/
        runHook postInstall
      '';
      meta = {
        description = "OpenCode event plugin reporting per-session status for tmux";
        homepage = "https://github.com/j0ta29/opencode-session-status";
        license = pkgs.lib.licenses.mit;
      };
    });
  opencodeHome =
    { pkgs }:
    let
      sessionStatus = opencodeSessionStatus pkgs;
    in
    {
      home.packages = [ pkgs.opencode ];
      home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
      # Auto-loaded from the global plugin directory (no runtime npm fetch).
      home.file.".config/opencode/plugins/opencode-session-status.js".source =
        "${sessionStatus}/lib/opencode-session-status/opencode-session-status.js";
    };
in
{
  nixconf.modules.nixos.opencode =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.opencode.enable = lib.mkEnableOption "OpenCode CLI";
      config = lib.mkIf config.modules.opencode.enable {
        environment.systemPackages = [ pkgs.opencode ];
        home-manager.users.${config.modules.users.userName} = opencodeHome { inherit pkgs; };
      };
    };

  nixconf.modules.homeManager.opencode =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.opencode.enable = lib.mkEnableOption "OpenCode CLI";
      config = lib.mkIf config.modules.opencode.enable (opencodeHome {
        inherit pkgs;
      });
    };
}
