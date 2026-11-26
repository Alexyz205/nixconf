# Static LAN identities, shared by NixOS, nix-darwin and standalone
# home-manager. The workstation address is pinned by a DHCP reservation, so it
# is safe to hardcode for SSH (`Host workstation`) and Wake-on-LAN (`wsw`).
# `mac` is the wired NIC that also receives the magic packet.
{
  workstation = {
    ip = "192.168.1.100";
    mac = "d8:bb:c1:51:4f:f0";
    interface = "enp4s0";
  };
  # DHCP reservation on the router; the NAS itself uses DHCP on en*.
  backup-nas = {
    ip = "192.168.1.113";
  };
  # Corporate desktop (RNSW-APIGEON1, 10.113.64.0/24). Only the wired NIC
  # matters for Wake-on-LAN; the address is not used by the alias.
  rnsw-apigeon1 = {
    mac = "4c:d7:17:a6:60:06";
    interface = "enp0s31f6";
  };
}
