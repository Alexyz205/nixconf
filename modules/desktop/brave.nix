{
  lib,
  ...
}:
let
  extensions = [
    { id = "mnjggcdmjocbbbhaepohbliplgamfdfc"; } # SponsorBlock
    { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # Dark Reader
    { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # Vimium
    { id = "bkkmolkhemgaeaeggcmfbghljjjoofoh"; } # Catppuccin Mocha theme
    { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden (Vaultwarden)
    { id = "kgcjekpmcjjogibpjebkhaanilehneje"; } # Karakeep
  ];
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
      next = kids.next;
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
        next = rest.next;
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

  braveCfg =
    {
      pkgs,
      ...
    }:
    {
      programs.brave = {
        enable = true;
        package = pkgs.brave;
        inherit extensions;
      };
      home.file.".config/BraveSoftware/Brave-Browser/Default/Bookmarks" = {
        text = bookmarksJson;
        force = true;
      };
    };
in
{
  flake.modules.nixos.brave =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.brave.enable = lib.mkEnableOption "Brave browser with Catppuccin Mocha theme";
      config = lib.mkIf config.modules.brave.enable {
        home-manager.users.${config.modules.users.userName} = braveCfg;
      };
    };

  flake.modules.homeManager.brave =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.brave.enable = lib.mkEnableOption "Brave browser with Catppuccin Mocha theme";
      config = lib.mkIf config.modules.brave.enable (braveCfg {
        inherit pkgs config;
      });
    };
}
