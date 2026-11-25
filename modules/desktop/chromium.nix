{
  lib,
  ...
}:
let
  # Extensions every machine installs. Kept as `{ id }` attrsets so the
  # home-manager module can consume them directly; the NixOS module flattens
  # the IDs into the ExtensionInstallForcelist policy instead.
  baseExtensions = [
    { id = "mnjggcdmjocbbbhaepohbliplgamfdfc"; } # SponsorBlock
    { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # Vimium
    { id = "bkkmolkhemgaeaeggcmfbghljjjoofoh"; } # Catppuccin Mocha theme
  ];
  # Okta Browser Plugin
  oktaExtension = {
    id = "glnpjglilkicbckjpbgcfkogebgllemb";
  };
  extensionId = ext: ext.id;
  bookmarks = [
    {
      name = "GitHub";
      url = "https://github.com";
    }
    {
      name = "Nixconf";
      url = "https://github.com/alexyz205/nixconf";
    }
    {
      name = "YouTube";
      url = "https://youtube.com";
    }
    {
      name = "Gmail";
      url = "https://mail.google.com";
    }
  ];

  # Dashy is the single entry point to every homelab service (see ../homelab),
  # so the folder only carries the two dashboards.
  homelab = {
    name = "Homelab";
    children = [
      {
        name = "Dashy";
        url = "https://dashy.alexyz.org";
      }
      {
        name = "Dev Dashy";
        url = "https://dev-dashy.alexyz.org";
      }
      {
        name = "Proxmox";
        url = "https://proxmox.alexyz.org:8006";
      }
    ];
  };

  # Deterministic GUID from a bookmark/folder name.
  guid =
    name:
    let
      h = builtins.hashString "sha1" name;
      fmt = a: b: lib.substring a b h;
    in
    "${fmt 0 8}-${fmt 8 4}-${fmt 12 4}-${fmt 16 4}-${fmt 20 12}";

  # Bookmarks.json timestamps are microseconds since 1601-01-01.
  dateAdded = "13326774450786953";

  # Convert {name, url?, children?} trees into numbered bookmarks.json nodes,
  # threading a unique `id` through the whole tree.
  numberNode =
    startId: node:
    let
      isUrl = node ? url;
      kids =
        if isUrl then
          {
            nodes = [ ];
            next = startId + 1;
          }
        else
          numberList (startId + 1) node.children;
      base = {
        date_added = dateAdded;
        date_last_used = "0";
        guid = guid node.name;
        id = builtins.toString startId;
        inherit (node) name;
      };
    in
    {
      node =
        if isUrl then
          base
          // {
            meta_info = {
              power_bookmark_meta = "";
            };
            inherit (node) url;
            type = "url";
          }
        else
          base
          // {
            children = kids.nodes;
            date_modified = dateAdded;
            type = "folder";
          };
      inherit (kids) next;
    };

  numberList =
    startId: nodes:
    if nodes == [ ] then
      {
        nodes = [ ];
        next = startId;
      }
    else
      let
        head = builtins.head nodes;
        tail = builtins.tail nodes;
        first = numberNode startId head;
        rest = numberList first.next tail;
      in
      {
        nodes = [ first.node ] ++ rest.nodes;
        inherit (rest) next;
      };

  mkBar = {
    children = (numberList 4 (bookmarks ++ [ homelab ])).nodes;
    date_added = dateAdded;
    date_last_used = "0";
    date_modified = dateAdded;
    guid = "0bc5d13f-2cba-5d74-951f-3f233fe6c908";
    id = "1";
    name = "Bookmarks bar";
    type = "folder";
  };

  mkEmpty = name: guid': id: {
    children = [ ];
    date_added = dateAdded;
    date_last_used = "0";
    date_modified = "0";
    guid = guid';
    inherit id name;
    type = "folder";
  };

  bookmarksJson = builtins.toJSON {
    checksum = "";
    roots = {
      bookmark_bar = mkBar;
      other = mkEmpty "Other bookmarks" "82b081ec-3dd3-529c-8475-ab6c344590dd" "2";
      synced = mkEmpty "Mobile bookmarks" "4cf2e351-0e85-532b-bb37-df045d8f8d0f" "3";
    };
    version = 1;
  };

  mkChromiumCfg =
    {
      okta,
      withExtensions,
    }:
    {
      pkgs,
      config,
      ...
    }:
    let
      # Chromium needs either a setuid chrome-sandbox (NixOS wrapper) or
      # unprivileged user namespaces. Standalone home-manager on a non-NixOS
      # host has neither, so don't install the nix package there; rely on the
      # distro's chromium (if present) and keep the shared config below.
      isGenericLinux = config.targets.genericLinux.enable or false;
    in
    {
      programs.chromium = {
        enable = true;
        package = if isGenericLinux then null else pkgs.chromium;
        # NixOS installs extensions through the ExtensionInstallForcelist
        # system policy instead, so every account gets them, not just this
        # home-manager user.
        extensions = lib.optionals withExtensions (baseExtensions ++ lib.optionals okta [ oktaExtension ]);
      };
      # Chromium's default download directory is ~/Downloads; declare the XDG
      # download dir and create the folder so fresh/impermanent homes have it.
      xdg.userDirs = {
        enable = true;
        download = "${config.home.homeDirectory}/Downloads";
        createDirectories = false;
      };
      home.file = {
        ".config/chromium/Default/Bookmarks" = {
          text = bookmarksJson;
          force = true;
        };
        "Downloads/.keep".text = "";
      };
      # Default browser: text/html and the http(s) scheme handlers. The nix
      # chromium package ships chromium-browser.desktop.
      xdg.mimeApps.defaultApplications = {
        "application/xhtml+xml" = [ "chromium-browser.desktop" ];
        "text/html" = [ "chromium-browser.desktop" ];
        "x-scheme-handler/about" = [ "chromium-browser.desktop" ];
        "x-scheme-handler/http" = [ "chromium-browser.desktop" ];
        "x-scheme-handler/https" = [ "chromium-browser.desktop" ];
        "x-scheme-handler/unknown" = [ "chromium-browser.desktop" ];
      };
    };
in
{
  nixconf.modules.nixos.chromium =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.chromium = {
        enable = lib.mkEnableOption "Chromium browser with Catppuccin Mocha theme";
        okta = lib.mkEnableOption "Okta Browser Plugin extension";
        startupUrls = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Pages opened on Chromium startup ("On startup: Open a specific page
            or set of pages"). Enforced through system policy on NixOS, so every
            account gets them and a manual "open last session" cannot override
            the list. Left empty, the profile's own startup preference wins.
          '';
        };
        extraExtensions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "nngceckbapebfimnlniiiahkandclblb" ];
          description = ''
            Extra extension IDs force-installed on top of the shared set,
            through the ExtensionInstallForcelist system policy. Pass the 32
            character ID from chrome://extensions, optionally followed by
            ";<update manifest url>" for extensions outside the Chrome Web
            Store.
          '';
        };
      };
      config = lib.mkIf config.modules.chromium.enable {
        # Extensions are mandatory: installed silently for every account and
        # profile, and not removable from the UI. Home-manager only keeps the
        # per-user files (bookmarks, Downloads, MIME handlers).
        programs.chromium = {
          enable = true;
          extensions =
            map extensionId baseExtensions
            ++ lib.optional config.modules.chromium.okta (extensionId oktaExtension)
            ++ config.modules.chromium.extraExtensions;
          extraOpts = lib.optionalAttrs (config.modules.chromium.startupUrls != [ ]) {
            RestoreOnStartup = 4; # Open a list of URLs
            RestoreOnStartupURLs = config.modules.chromium.startupUrls;
          };
        }
        # Download directory stays recommended, and its absolute per-user path
        # is only safe on single-account hosts; multi-account hosts rely on
        # Chromium's ~/Downloads default plus the XDG folder.
        // lib.optionalAttrs (builtins.length (builtins.attrNames config.home-manager.users) == 1) {
          extraOptsRecommended.DefaultDownloadDirectory = "${
            config.users.users.${config.modules.users.userName}.home
          }/Downloads";
        };
        home-manager.users = lib.genAttrs config.modules.users.homeUsers (
          _:
          mkChromiumCfg {
            okta = config.modules.chromium.okta;
            withExtensions = false;
          }
        );
      };
    };

  nixconf.modules.homeManager.chromium =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.chromium = {
        enable = lib.mkEnableOption "Chromium browser with Catppuccin Mocha theme";
        okta = lib.mkEnableOption "Okta Browser Plugin extension";
      };
      config = lib.mkIf config.modules.chromium.enable (
        mkChromiumCfg
          {
            okta = config.modules.chromium.okta;
            withExtensions = true;
          }
          {
            inherit pkgs config;
          }
      );
    };
}
