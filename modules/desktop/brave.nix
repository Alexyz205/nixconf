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

  # Deterministic GUID from a bookmark name.
  guid =
    name:
    let
      h = builtins.hashString "sha1" name;
      fmt = a: b: lib.substring a b h;
    in
    "${fmt 0 8}-${fmt 8 4}-${fmt 12 4}-${fmt 16 4}-${fmt 20 12}";

  # Bookmarks.json timestamps are microseconds since 1601-01-01.
  dateAdded = "13326774450786953";

  mkNode = i: b: {
    date_added = dateAdded;
    date_last_used = "0";
    guid = guid b.name;
    id = builtins.toString (i + 3);
    meta_info = {
      power_bookmark_meta = "";
    };
    name = b.name;
    type = "url";
    url = b.url;
  };

  mkBar = {
    children = builtins.genList (i: mkNode i (builtins.elemAt bookmarks i)) (builtins.length bookmarks);
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
    id = id;
    name = name;
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
      config,
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

  flake.modules.homeManager.brave = braveCfg;
}
