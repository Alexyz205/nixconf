_: {
  flake.modules.nixos.boot = _: {
    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };

      # NetworkManager's internal DHCPv4 client (n-dhcp4) needs an AF_PACKET
      # socket to transmit DHCPDISCOVER. The stock kernel sets CONFIG_PACKET=m
      # (a module), so the packet family is absent until af_packet autoloads;
      # if it isn't loaded, socket(AF_PACKET, ...) fails with EAFNOSUPPORT and
      # every DHCPv4 attempt dies with:
      #
      #   NetworkManager[...]: <error> dhcp4 (enp4s0): error -97 dispatching events
      #
      # leaving the interface with no IPv4 lease (IPv6 SLAAC still works).
      # Previously CONFIG_PACKET was baked in via a kernel patch (which forced a
      # local kernel build for every nixpkgs bump). Loading the module at boot
      # achieves the same guarantee while keeping the stock (cache-substituted)
      # kernel. The NIC itself (Realtek RTL8125 on MSI, r8169) needs no patch.
      kernelModules = [ "af_packet" ];
    };
  };
}
