{ config, ... }:
{
  # Reusable module surface for downstream flakes (e.g. the private
  # nixconf-work repo). Host definitions and tiers remain in this flake.
  flake.nixosModules = config.nixconf.modules.nixos // {
    default = {
      imports = builtins.attrValues config.nixconf.modules.nixos;
    };
  };

  flake.homeManagerModules = config.nixconf.modules.homeManager // {
    default = {
      imports = builtins.attrValues config.nixconf.modules.homeManager;
    };
  };

  flake.lib = {
    mkHostCommon = config.nixconf.mkHostCommon;
    mkHome = config.nixconf.mkHome;
    homeManagerExtras = config.nixconf.homeManagerExtras;
    nixosFeatures = config.nixconf.nixosFeatures;
  };
}
