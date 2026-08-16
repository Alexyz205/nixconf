{
  lib,
  inputs,
  ...
}: let
  firefoxOverlay = inputs.firefox-addons.overlays.default;

  firefoxCfg = {pkgs, ...}: {
    enable = true;
    configPath = ".mozilla/firefox";

    profiles.alexis = {
      isDefault = true;

      extensions.packages = with pkgs.firefox-addons; [
        ublock-origin
        sponsorblock
        darkreader
        vimium
        catppuccin-mocha-mauve
      ];
      extensions.force = true;

      settings = {
        "extensions.autoDisableScopes" = 0;

        "extensions.activeThemeID" = "{76aabc99-c1a8-4c1e-832b-d4f2941d5a7a}";

        "browser.startup.page" = 3;
        "browser.zoom.siteSpecific" = true;

        "browser.disableResetPrompt" = true;
        "browser.download.panel.shown" = true;
        "browser.messaging-system.whatsNewPanel.enabled" = false;
        "browser.rights.3.shown" = true;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.startup.homepage_override.mstone" = "ignore";
        "browser.uitour.enabled" = false;
        "trailhead.firstrun.didSeeAboutWelcome" = true;
        "browser.bookmarks.restore_default_bookmarks" = false;

        "browser.download.useDownloadDir" = false;

        "privacy.trackingprotection.enabled" = true;
        "dom.security.https_only_mode" = true;

        "identity.fxaccounts.enabled" = false;

        "network.cookie.lifetimePolicy" = 0;
        "privacy.clearOnShutdown.cookies" = false;
        "privacy.clearOnShutdown.siteSettings" = false;
        "privacy.sanitize.sanitizeOnShutdown" = false;

        "privacy.resistFingerprinting" = false;

        "browser.urlbar.autoFill" = true;
        "browser.urlbar.dnsFirstForSingleWords" = true;
        "browser.urlbar.suggest.history" = true;
        "browser.urlbar.suggest.bookmark" = true;
        "browser.urlbar.suggest.openpage" = true;
        "browser.urlbar.suggest.searches" = false;
        "browser.search.suggest.enabled" = true;

        "signon.rememberSignons" = false;
        "extensions.formautofill.address.enabled" = false;
        "extensions.formautofill.creditCards.enabled" = false;

        "browser.tabs.firefox-view" = false;
        "extensions.pocket.enabled" = false;

        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "browser.newtabpage.activity-stream.feeds.system.topstories" = false;

        "app.shield.optoutstudies.enabled" = false;
        "browser.discovery.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        "datareporting.healthreport.service.enabled" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "toolkit.telemetry.bhrPing.enabled" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.firstShutdownPing.enabled" = false;
        "toolkit.telemetry.hybridContent.enabled" = false;
        "toolkit.telemetry.newProfilePing.enabled" = false;
        "toolkit.telemetry.prompted" = 2;
        "toolkit.telemetry.rejected" = true;
        "toolkit.telemetry.reportingpolicy.firstRun" = false;
        "toolkit.telemetry.server" = "";
        "toolkit.telemetry.shutdownPingSender.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.unifiedIsOptIn" = false;
        "toolkit.telemetry.updatePing.enabled" = false;

        "font.name.sans-serif" = "JetBrainsMono Nerd Font";
        "font.name.serif" = "JetBrainsMono Nerd Font";
        "font.name.monospace" = "JetBrainsMono Nerd Font";
      };

      bookmarks = {
        force = true;
        settings = [
          {
            name = "Quick Access";
            toolbar = true;
            bookmarks = [
              {
                name = "alexyz205";
                url = "https://github.com/alexyz205";
                keyword = "gh";
              }
              {
                name = "YouTube";
                url = "https://youtube.com";
                keyword = "yt";
              }
            ];
          }
        ];
      };

      search = {
        force = true;
        default = "ddg";
        order = [
          "searxng"
          "nix-packages"
          "nixos-wiki"
          "ddg"
        ];

        engines = {
          searxng = {
            urls = [{template = "https://searx.org/search?q={searchTerms}";}];
            icon = "https://searx.org/favicon.ico";
            updateInterval = 86400000;
            definedAliases = ["@searx"];
          };

          "nix-packages" = {
            urls = [{
              template = "https://search.nixos.org/packages";
              params = [
                {name = "type"; value = "packages";}
                {name = "query"; value = "{searchTerms}";}
              ];
            }];
            icon = "https://nixos.wiki/favicon.png";
            definedAliases = ["@np"];
          };

          "nixos-wiki" = {
            urls = [{template = "https://nixos.wiki/index.php?search={searchTerms}";}];
            icon = "https://nixos.wiki/favicon.png";
            updateInterval = 86400000;
            definedAliases = ["@nw"];
          };

          ddg = {
            urls = [{template = "https://duckduckgo.com/?q={searchTerms}";}];
            icon = "https://duckduckgo.com/favicon.ico";
            definedAliases = ["@ddg"];
          };

          bing.metaData.hidden = true;
          google.metaData.alias = "@g";
        };
      };
    };
  };
in {
  flake.modules.nixos.firefox = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.firefox.enable = lib.mkEnableOption "Firefox with Catppuccin theme";
    config = lib.mkIf config.modules.firefox.enable {
      nixpkgs.overlays = [firefoxOverlay];
      programs.firefox.enable = true;
      home-manager.users.${config.modules.users.userName} = {
        programs.firefox = firefoxCfg {inherit pkgs;};
      } // lib.optionalAttrs (config ? stylix) {
        stylix.targets.firefox = {
          profileNames = [config.modules.users.userName];
          colorTheme.enable = true;
        };
      };
    };
  };

  flake.modules.homeManager.firefox = {
    config,
    lib,
    pkgs,
    ...
  }: {
    nixpkgs.overlays = [firefoxOverlay];
    programs.firefox = firefoxCfg {inherit pkgs;};
    stylix.targets.firefox = {
      profileNames = [config.modules.users.userName];
      colorTheme.enable = true;
    };
  };
}
