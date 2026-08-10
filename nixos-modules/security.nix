# Security module: kernel/runtime hardening.
# Enable with `modules.security.enable = true`.
{ config, lib, ... }:

{
  options.modules.security = {
    enable = lib.mkEnableOption "kernel/runtime hardening";
  };

  config = lib.mkIf config.modules.security.enable {
    # No new kernel modules can be loaded after boot.
    security.lockKernelModules = true;
    # No core dumps (can leak process memory to disk).
    systemd.coredump.enable = false;

    boot.kernel.sysctl = {
      # Only root can read kernel messages / pointers.
      "kernel.dmesg_restrict" = 1;
      "kernel.kptr_restrict" = 2;
      # Reverse-path filtering: drop packets from unexpected source addresses.
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;
      # Ignore broadcast ping floods.
      "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    };
  };
}
