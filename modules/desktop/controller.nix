{
  nixconf.modules.nixos.controller =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.controller.enable = lib.mkEnableOption "Xbox controller (xpadneo)";
      config = lib.mkIf config.modules.controller.enable {
        # Xbox Wireless controllers over Bluetooth have no in-kernel driver, so
        # without xpadneo they connect at the Bluetooth level but never show up
        # as a joystick. xpadneo provides the HID driver.
        hardware.xpadneo.enable = true;

        # The nixpkgs `hardware.xpadneo` module installs the kernel module but
        # NOT xpadneo's udev rules (upstream ships them in
        # hid-xpadneo/etc-udev-rules.d/). Since systemd 258, uaccess ACLs are
        # applied by systemd-udevd and must be tagged on every action except
        # `remove`; without these rules the controller connects but no app
        # (Steam, Big Picture, SDL2 games) ever receives input. Copied verbatim
        # from upstream so a future rebuild keeps tracking their fixes.
        services.udev.packages = [
          (pkgs.writeTextFile {
            name = "60-xpadneo";
            destination = "/etc/udev/rules.d/60-xpadneo.rules";
            text = ''
              # Mark devices supported by xpadneo
              ACTION=="bind", SUBSYSTEM=="hid", KERNEL=="0005:045E:*", KERNEL=="*:02FD.*|*:02E0.*|*:0B05.*|*:0B13.*|*:0B20.*|*:0B22.*", ENV{ID_XPADNEO_SUPPORTED}="1"
              ACTION=="bind", SUBSYSTEM=="hid", KERNEL=="0005:0B05:1ABD.*", ENV{ID_XPADNEO_SUPPORTED}="1"

              # Rebind driver to xpadneo
              ACTION=="bind", SUBSYSTEM=="hid", DRIVER!="xpadneo", ENV{ID_XPADNEO_SUPPORTED}=="1", ATTR{driver/unbind}="%k", ATTR{[drivers/hid:xpadneo]bind}="%k"

              # Tag xpadneo devices for access in the user session
              ACTION!="remove", DRIVERS=="xpadneo", SUBSYSTEM=="input", ENV{ID_INPUT_JOYSTICK}=="1", TAG+="uaccess", MODE="0664", ENV{LIBINPUT_IGNORE_DEVICE}="1"
            '';
          })
          (pkgs.writeTextFile {
            name = "70-xpadneo-disable-hidraw";
            destination = "/etc/udev/rules.d/70-xpadneo-disable-hidraw.rules";
            text = ''
              # Work around Steam Link not detecting mappings and QMK overriding
              # the hidraw rules: hide xpadneo's raw hidraw node so clients use
              # the evdev input node instead of double-opening the device.
              ACTION!="remove", SUBSYSTEM=="hidraw", IMPORT{parent}="ID_XPADNEO_SUPPORTED"
              ACTION!="remove", SUBSYSTEM=="hidraw", ENV{ID_XPADNEO_SUPPORTED}=="1", MODE:="0000", TAG-="uaccess"

              ACTION!="remove", DRIVERS=="xpadneo", SUBSYSTEM=="hidraw", MODE:="0000", TAG-="uaccess"
            '';
          })
        ];

        # /dev/input/event* are root:input 660; the uaccess tag covers seat
        # sessions, but this keeps Heroic/Proton/Wine working even outside one.
        users.users.${config.modules.users.userName}.extraGroups = [ "input" ];
      };
    };
}
