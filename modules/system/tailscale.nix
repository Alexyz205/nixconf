_: {
  nixconf.modules.nixos.tailscale =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.modules.tailscale;
      routes = lib.concatStringsSep "," cfg.advertiseRoutes;
    in
    {
      options.modules.tailscale = {
        enable = lib.mkEnableOption "Tailscale mesh VPN (tailscaled)";

        advertiseRoutes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "192.168.1.0/24" ];
          description = ''
            Subnet routes to advertise to the tailnet. A non-empty list turns
            the host into a subnet router (IP forwarding on, no exit node).
            Routes still have to be approved in the Tailscale admin console, or
            matched by a route `autoApprovers` rule in the tailnet policy.
          '';
        };

        acceptRoutes = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Accept subnet routes advertised by other tailnet nodes.";
        };

        acceptDns = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Let tailscaled rewrite this host's DNS. Off by default so a host
            that is itself a resolver (PiHole) or relies on its LAN resolver
            keeps working; MagicDNS names then only resolve on other devices.
          '';
        };

        ssh = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Tailscale SSH (identity-based SSH gated by the tailnet ACL).";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Open the tailscaled UDP port so peers can connect directly. Peers
            still connect through DERP relays when this is closed, just slower.
          '';
        };

        trustInterface = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Trust the tailscale0 interface in the NixOS firewall. Tailscale's
            own ACLs authenticate peers, and LAN-facing services (SSH, NFS)
            otherwise reject tailnet clients at the firewall.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.tailscale = {
          enable = true;
          inherit (cfg) openFirewall;
          # A router needs IP forwarding; a client that accepts routes needs
          # reverse-path filtering relaxed for the tunnel.
          useRoutingFeatures =
            if cfg.advertiseRoutes != [ ] then
              "server"
            else if cfg.acceptRoutes then
              "client"
            else
              "none";
          # No debug logging upstream. Metadata is already visible to the
          # coordination server; this is the only knob the daemon exposes.
          disableUpstreamLogging = true;
          extraSetFlags =
            lib.optional (cfg.advertiseRoutes != [ ]) "--advertise-routes=${routes}"
            ++ lib.optional cfg.acceptRoutes "--accept-routes"
            ++ lib.optional (!cfg.acceptDns) "--accept-dns=false"
            ++ lib.optional cfg.ssh "--ssh";
        };

        # modules.security keeps a strict rp_filter. Forwarded tunnel traffic
        # carries an fwmark and is dropped by strict filtering unless
        # src_valid_mark is set. SNAT stays enabled (the default), so replies
        # from LAN hosts come back symmetrically and strict filtering holds.
        boot.kernel.sysctl = lib.mkIf (cfg.advertiseRoutes != [ ]) {
          "net.ipv4.conf.all.src_valid_mark" = 1;
        };

        networking.firewall.trustedInterfaces = lib.mkIf cfg.trustInterface [
          config.services.tailscale.interfaceName
        ];
      };
    };
}
