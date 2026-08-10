{
  inputs,
  ...
}: {
  imports = [
    inputs.wrapper-modules.flakeModules.wrappers
  ];

  options.flake.modules = {
    nixos = inputs.nixpkgs.lib.mkOption {
      type = inputs.nixpkgs.lib.types.lazyAttrsOf inputs.nixpkgs.lib.types.raw;
      default = { };
    };
    homeManager = inputs.nixpkgs.lib.mkOption {
      type = inputs.nixpkgs.lib.types.lazyAttrsOf inputs.nixpkgs.lib.types.raw;
      default = { };
    };
  };

  config.systems = [ "x86_64-linux" ];
}