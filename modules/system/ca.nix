_: {
  flake.modules.nixos.ca =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      # Homelab cert-manager root CA. Export it from the cluster with the
      # homelab repo's fetch-ca.sh script.
      certFile = ../../config/ca/homelab-ca.pem;
    in
    {
      options.modules.ca.enable = lib.mkEnableOption "Homelab root CA in the system trust store";
      config = lib.mkIf config.modules.ca.enable (
        {
          # Adds the CA to /etc/ssl/certs so curl, git and other CLI clients can
          # verify the Traefik-issued *.alexyz.hl certificate.
          security.pki.certificateFiles = [ certFile ];
          assertions = [
            {
              assertion = builtins.pathExists certFile;
              message = ''
                Missing config/ca/homelab-ca.pem. Export the homelab root CA from
                the cluster first: ./scripts/fetch-ca.sh (homelab repo).
              '';
            }
          ];
        }
        // lib.optionalAttrs (options ? home-manager) {
          # Chromium-based browsers (Brave/Chrome) use the Chrome Root Store, not
          # the OS trust store, so the CA must be imported into the user's NSS
          # database for *.alexyz.hl to be trusted there.
          home-manager.users.${config.modules.users.userName} =
            {
              lib,
              pkgs,
              ...
            }:
            {
              home.activation.importHomelabCa = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                mkdir -p "$HOME/.pki/nssdb"
                ${pkgs.nssTools}/bin/certutil -d "sql:$HOME/.pki/nssdb" -D -n "homelab-ca" 2>/dev/null || true
                ${pkgs.nssTools}/bin/certutil -d "sql:$HOME/.pki/nssdb" -A -t "C,," -n "homelab-ca" -i "${certFile}"
              '';
            };
        }
      );
    };
}
