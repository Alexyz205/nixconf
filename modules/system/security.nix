_: {
  nixconf.modules.nixos.security =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.security.enable = lib.mkEnableOption "Kernel hardening (sysctl, dmesg, coredumps)";
      config = lib.mkIf config.modules.security.enable {
        security.lockKernelModules = true;
        boot.kernelModules = [
          "uas"
          "usb_storage"
          "exfat"
        ];
        systemd.coredump.enable = false;
        # Disabling systemd-coredump alone makes the kernel fall back to
        # writing "core" / "core.<pid>" in the crashing process's cwd (this is
        # how the huge files ended up in /home). Pipe every dump to false so
        # the kernel discards it without creating a file.
        boot.kernel.sysctl."kernel.core_pattern" = "|/run/current-system/sw/bin/false";
        boot.kernel.sysctl."fs.suid_dumpable" = 0;
        security.pam.loginLimits = [
          {
            domain = "*";
            item = "core";
            type = "soft";
            value = "0";
          }
          {
            domain = "*";
            item = "core";
            type = "hard";
            value = "0";
          }
        ];
        boot.kernel.sysctl = {
          "kernel.dmesg_restrict" = 1;
          "kernel.kptr_restrict" = 2;
          "net.ipv4.conf.all.rp_filter" = 1;
          "net.ipv4.conf.default.rp_filter" = 1;
          "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
        };
      };
    };
}
