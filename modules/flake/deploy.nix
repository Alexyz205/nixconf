{
  self,
  inputs,
  ...
}:
{
  flake-file.inputs.deploy-rs = {
    url = "github:serokell/deploy-rs";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Push the locally built closure to the server instead of rebuilding on it:
  #   deploy .#headless-worker          (build locally, copy, activate)
  #   deploy --remote-build ...         (build on the server)
  flake.deploy.nodes.headless-worker = {
    hostname = "headless-worker";
    profiles.system = {
      user = "root";
      path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.headless-worker;
    };
  };
}
