{
  inputs,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      packages = [
        inputs.disko.packages.${system}.disko
        pkgs.shellcheck
      ];
    };
  };
}
