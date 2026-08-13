{lib, ...}: let
  starshipCfg = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      follow_symlinks = false;
      scan_timeout = 200;
      command_timeout = 1000;
      format = "[](surface0)$os$username$sudo[](bg:color_peach fg:surface0)$directory[](fg:color_peach bg:color_green)$git_branch$git_status[](fg:color_green bg:color_sapphire)$c$rust$golang$nodejs$python$package$nix_shell[](fg:color_sapphire bg:color_blue)$docker_context$kubernetes$container$terraform$helm[](fg:color_blue bg:color_pink)$shell[ ](fg:color_pink)$line_break$character";
      right_format = "[](surface0)$status[](bg:color_peach fg:surface0)$cmd_duration[](fg:color_peach bg:color_green)$shlvl$jobs[](fg:color_green bg:color_sapphire)$localip[](fg:color_sapphire bg:color_blue)$memory_usage[](fg:color_blue bg:color_pink)$time[ ](fg:color_pink)";
      palette = "catppuccin_mocha";
      palettes.catppuccin_mocha = {
        color_fg0 = "#cdd6f4";
        color_fg1 = "#1e1e2e";
        color_pink = "#f5c2e7";
        color_blue = "#89b4fa";
        color_sapphire = "#74c7ec";
        color_green = "#a6e3a1";
        color_teal = "#94e2d5";
        surface0 = "#313244";
        color_purple = "#cba6f7";
        color_red = "#cc241d";
        color_peach = "#fab387";
        color_grey = "#6c7086";
      };
      os.disabled = false;
      os.style = "bg:surface0 fg:color_fg0";
      os.symbols = {
        Windows = "󰍲";
        Ubuntu = "󰕈";
        Macos = "󰀵";
        Linux = "󰌽";
        Fedora = "󰣛";
        Alpine = "";
        Amazon = "";
        Android = "";
        Arch = "󰣇";
        CentOS = "";
        Debian = "󰣚";
        Redhat = "󱄛";
        RedHatEnterprise = "󱄛";
      };
      username = {
        show_always = true;
        style_user = "bg:surface0 fg:color_fg0";
        style_root = "fg:color_fg0 bg:surface0";
        format = "[ $user ]($style)";
      };
      directory = {
        style = "fg:color_fg1 bg:color_peach";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
      };
      sudo = {
        disabled = false;
        style = "fg:color_fg0 bg:surface0";
        symbol = "sudo";
      };
      git_branch = {
        symbol = "";
        style = "bg:color_green";
        format = "[[ $symbol $branch ](fg:color_fg1 bg:color_green)]($style)";
      };
      git_status = {
        style = "bg:color_green";
        format = "[[($all_status$ahead_behind )](fg:color_fg1 bg:color_green)]($style)";
        ignore_submodules = true;
      };
      nodejs = {
        symbol = "";
        style = "bg:color_sapphire fg:color_fg1";
        format = "[ $symbol( $version) ]($style)";
      };
      c = {
        symbol = " ";
        style = "bg:color_sapphire fg:color_fg1";
        format = "[ $symbol( $version) ]($style)";
      };
      lua = {
        symbol = "";
        style = "bg:color_sapphire fg:color_fg1";
        format = "[ $symbol( $version) ]($style)";
      };
      cpp = {
        symbol = "";
        style = "bg:color_sapphire fg:color_fg1";
        format = "[ $symbol( $version) ]($style)";
      };
      rust = {
        symbol = "";
        style = "bg:color_sapphire fg:color_fg1";
        format = "[ $symbol( $version) ]($style)";
      };
      golang = {
        symbol = "";
        style = "bg:color_sapphire fg:color_fg1";
        format = "[ $symbol( $version) ]($style)";
      };
      python = {
        symbol = "";
        style = "bg:color_sapphire fg:color_fg1";
        format = "[ $symbol ($version)(\($virtualenv\))]($style)";
      };
      package = {
        symbol = "󰏗";
        style = "bg:color_sapphire fg:color_fg1";
        format = "[ $symbol( $version) ]($style)";
      };
      nix_shell = {
        heuristic = true;
        symbol = "";
        style = "bg:color_sapphire fg:color_fg1";
        format = "[ $symbol$state( \($name\)) ]($style)";
        impure_msg = "[impure](bold red)";
        pure_msg = "[pure](bold green)";
        unknown_msg = "";
      };
      docker_context = {
        symbol = "";
        style = "bg:color_blue";
        format = "[[ $symbol( $context) ](fg:color_fg1 bg:color_blue)]($style)";
      };
      kubernetes = {
        symbol = "󱃾";
        style = "bg:color_blue fg:color_fg1";
        format = "[ $symbol( $context) ]($style)";
      };
      terraform = {
        symbol = "󱁻";
        style = "bg:color_blue fg:color_fg1";
        format = "[ $symbol( $workspace) ]($style)";
      };
      helm = {
        symbol = "⎈";
        style = "bg:color_blue fg:color_fg1";
        format = "[ $symbol( $version) ]($style)";
      };
      status = {
        format = "[$symbol$status]($style)";
        symbol = "❌";
        success_symbol = "";
        not_executable_symbol = "🚫";
        not_found_symbol = "🔍";
        sigint_symbol = "🧱";
        signal_symbol = "⚡";
        style = "bg:surface0";
        success_style = "bg:surface0";
        failure_style = "bg:surface0";
        recognize_signal_code = true;
        map_symbol = true;
        pipestatus = true;
        pipestatus_separator = "|";
        pipestatus_format = "\\[$pipestatus\\] => [$symbol$common_meaning$signal_name$maybe_int]($style)";
        pipestatus_segment_format = "";
        disabled = false;
      };
      shell = {
        fish_indicator = "󰈺";
        powershell_indicator = "_";
        unknown_indicator = "mystery shell";
        style = "bg:color_pink fg:color_fg1";
        format = "[ $indicator $shell]($style)";
        disabled = false;
      };
      cmd_duration = {
        min_time = 500;
        format = "[ 󱎫 $duration ](fg:color_fg1 bg:color_peach)";
      };
      shlvl = {
        symbol = "↕";
        style = "bg:color_green fg:color_fg1";
        format = "[ $symbol$shlvl ]($style)";
        threshold = 1;
        disabled = false;
      };
      jobs = {
        symbol = "✦";
        style = "bg:color_green fg:color_fg1";
        format = "[ $symbol$number ]($style)";
        symbol_threshold = 1;
        number_threshold = 2;
        disabled = false;
      };
      container = {
        symbol = "";
        format = "[ $symbol $name ]($style)";
        style = "bg:color_blue fg:color_fg1";
      };
      localip = {
        ssh_only = false;
        format = "[ 󰩟 $localipv4 ]($style)";
        disabled = false;
        style = "bg:color_sapphire fg:color_fg1";
      };
      memory_usage = {
        disabled = false;
        threshold = -1;
        symbol = "󰍛";
        style = "bg:color_blue fg:color_fg1";
        format = "[ $symbol $ram ]($style)";
      };
      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:color_pink fg:color_fg1";
        format = "[  $time ]($style)";
      };
      line_break.disabled = false;
      character = {
        disabled = false;
        success_symbol = "[](bold fg:color_teal)";
        error_symbol = "[](bold fg:color_red)";
        vimcmd_symbol = "[](bold fg:color_teal)";
        vimcmd_replace_one_symbol = "[](bold fg:color_purple)";
        vimcmd_replace_symbol = "[](bold fg:color_purple)";
        vimcmd_visual_symbol = "[](bold fg:color_peach)";
      };
    };
  };
in {
  flake.modules.nixos.starship = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.starship.enable = lib.mkEnableOption "Starship prompt";
    config = lib.mkIf config.modules.starship.enable {
      home-manager.users."alexis" = {
        programs.starship = starshipCfg;
        stylix.targets.starship.enable = false;
      };
    };
  };

  flake.modules.homeManager.starship = {...}: {
    programs.starship = starshipCfg;
  };
}
