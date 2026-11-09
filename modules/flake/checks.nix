{
  config,
  self,
  inputs,
  ...
}:
let
  lib = inputs.nixpkgs.lib;
  features = config.nixconf.modules.nixos;
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = {
        # CI gate for the same linters the git hooks run, over the whole tree.
        format =
          pkgs.runCommand "nixconf-format-check"
            {
              nativeBuildInputs = with pkgs; [
                nixfmt
                shfmt
                shellcheck
                statix
                deadnix
              ];
              src = self;
            }
            ''
              cp -r "$src" work
              cd work
              chmod -R u+w .

              mapfile -t nix_files < <(find . -name '*.nix' -not -path './.devenv/*')
              nixfmt --check "''${nix_files[@]}"

              mapfile -t sh_files < <(find scripts -name '*.sh')
              shfmt -d -i 2 -s "''${sh_files[@]}"
              shellcheck -S warning "''${sh_files[@]}"

              statix check
              deadnix --fail

              mkdir -p "$out"
            '';
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        # Boot the server feature set in QEMU and assert the services that make
        # it reachable actually come up. Catches module wiring, not disk layout.
        server-boot = pkgs.testers.nixosTest {
          name = "nixconf-server-boot";
          nodes.machine = {
            imports = [
              features.users
              features.security
              features.ssh
              features.nix
              features.packages
            ];
            modules = {
              users = {
                enable = true;
                userName = "alexis";
                extraGroups = [ "wheel" ];
              };
              security.enable = true;
              ssh.enable = true;
              nix.enable = true;
              packages = {
                enable = true;
                basic = true;
                nixTools = false;
                lsp = false;
              };
            };
            system.stateVersion = "26.05";
            networking.hostName = "server-test";
            users.users.root.password = "test";
          };
          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("sshd.service")
            machine.succeed("systemctl is-enabled fail2ban.service")
            machine.succeed("nix --version")
          '';
        };
      };
    };
}
