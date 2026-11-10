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
}
