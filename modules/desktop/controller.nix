{
  flake.modules.nixos.controller =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.controller.enable = lib.mkEnableOption "Xbox controller (xpadneo)";
      config = lib.mkIf config.modules.controller.enable {
        # Xbox Wireless controllers over Bluetooth have no in-kernel driver, so
        # without xpadneo they connect at the Bluetooth level but never show up
        # as a joystick. xpadneo provides the HID driver + udev rules.
        hardware.xpadneo.enable = true;
        # /dev/input/event* are root:input 660; without membership, games run
        # outside Steam's own rules (Heroic/Proton/Wine) can't open them.
        users.users.${config.modules.users.userName}.extraGroups = [ "input" ];
      };
    };
}
