{ lib, ... }: {
  flake.modules.nixos.security = { ... }: {
    security.lockKernelModules = true;
    systemd.coredump.enable = false;
    boot.kernel.sysctl = {
      "kernel.dmesg_restrict" = 1;
      "kernel.kptr_restrict" = 2;
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;
      "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    };
  };
}
