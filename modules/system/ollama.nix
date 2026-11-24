_: {
  nixconf.modules.nixos.ollama =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.modules.ollama;
    in
    {
      options.modules.ollama = {
        enable = lib.mkEnableOption "Ollama local LLM server with CUDA";

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Listen address; loopback keeps the API off the corporate LAN.";
        };

        loadModels = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "qwen3:32b" ];
          description = "Models pulled at activation (they land in modelsDir).";
        };
      };

      config = lib.mkIf cfg.enable {
        # A static account, not the module's DynamicUser: model weights live on
        # /persistent (host override), and a dynamic uid would chown tens of GB
        # on every boot.
        users.groups.ollama = { };
        users.users.ollama = {
          isSystemUser = true;
          group = "ollama";
          home = config.services.ollama.home;
        };

        services.ollama = {
          enable = true;
          # CUDA build: the RTX 4090 does the inference, the i9 only tokenises.
          package = pkgs.ollama-cuda;
          inherit (cfg) host loadModels;
          environmentVariables = {
            OLLAMA_FLASH_ATTENTION = "1";
            OLLAMA_KV_CACHE_TYPE = "q8_0";
            # Ollama defaults to 4096 tokens, and the OpenAI-compatible API has
            # no field to raise it; 64K is what a 27B dense model plus q8_0 KV
            # cache leaves free on a 24 GiB card.
            OLLAMA_CONTEXT_LENGTH = "65536";
            # One resident model: 17.7 GB of weights would otherwise thrash a
            # second load out of VRAM.
            OLLAMA_MAX_LOADED_MODELS = "1";
            OLLAMA_NUM_PARALLEL = "1";
            # Keep the model warm across agent turns without pinning all VRAM
            # forever.
            OLLAMA_KEEP_ALIVE = "30m";
          };
        };

        systemd.services.ollama.serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = lib.mkForce "ollama";
          Group = lib.mkForce "ollama";
        };

        # The host points home/modelsDir at the persistent volume; create them
        # with the right owner before the service starts.
        systemd.tmpfiles.rules = [
          "d ${config.services.ollama.home} 0750 ollama ollama -"
          "d ${config.services.ollama.modelsDir} 0750 ollama ollama -"
        ];
      };
    };
}
