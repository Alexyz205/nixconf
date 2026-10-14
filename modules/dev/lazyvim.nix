{
  inputs,
  lib,
  ...
}:
let
  lazyvimAliases = {
    v = "nvim";
  };

  lazyvimOptions = {
    enable = lib.mkEnableOption "LazyVim";
  };

  homeCfg = {
    programs.zsh.shellAliases = lazyvimAliases;
    programs.lazyvim = {
      enable = true;
      ignoreBuildNotifications = true;
      pluginSource = "nixpkgs";
      # Core CLI deps (git, ripgrep, fd, lazygit, fzf, curl) are provided by the
      # packages, tmux, git and lazygit modules; skip LazyVim's own copies.
      installCoreDependencies = false;
      extras = {
        util.octo.enable = true;
        editor.snacks-picker.enable = true;
        lang = {
          ansible.enable = true;
          clangd.enable = true;
          cmake.enable = true;
          docker.enable = true;
          git.enable = true;
          helm.enable = true;
          json.enable = true;
          markdown = {
            enable = true;
            # LazyVim's default markdown formatter is `prettier`, but only
            # `prettierd` is installed, so point conform at it.
            config = ''
              return {
                {
                  "stevearc/conform.nvim",
                  optional = true,
                  opts = {
                    formatters_by_ft = {
                      markdown = { "prettierd", "markdownlint-cli2" },
                      ["markdown.mdx"] = { "prettierd", "markdownlint-cli2" },
                    },
                  },
                },
              }
            '';
          };
          nix.enable = true;
          python.enable = true;
          terraform.enable = true;
          toml.enable = true;
          yaml.enable = true;
        };
        ui = {
          indent-blankline.enable = true;
          treesitter-context.enable = true;
        };
      };
      configFiles = toString ../../config/lazyvim;
    };
  };
in
{
  flake-file.inputs.lazyvim = {
    url = "github:pfassina/lazyvim-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  nixconf.modules.nixos.lazyvim =
    {
      config,
      ...
    }:
    {
      options.modules.lazyvim = lazyvimOptions;
      config = lib.mkIf config.modules.lazyvim.enable {
        # Unlike the other NixOS->home-manager bridges (which call their cfg
        # function directly), lazyvim also has to pull in the upstream
        # home-manager module, so the module value is `imports` merged with the
        # cfg attrset.
        home-manager.users.${config.modules.users.userName} = {
          imports = [ inputs.lazyvim.homeManagerModules.default ];
        }
        // homeCfg;
      };
    };

  nixconf.modules.homeManager.lazyvim =
    {
      config,
      lazyvim,
      ...
    }:
    {
      imports = [ lazyvim.homeManagerModules.default ];
      options.modules.lazyvim = lazyvimOptions;
      config = lib.mkIf config.modules.lazyvim.enable homeCfg;
    };
}
