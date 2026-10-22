{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.orangepi.uwe5622;
in
{
  options.hardware.orangepi.uwe5622 = {
    enable = lib.mkEnableOption "Unisoc UWE5622 (AW859A) Wi-Fi and Bluetooth driver and firmware";
  };

  config = lib.mkIf cfg.enable {
    # Board wireless firmware (architecture independent, no need to cross-build)
    hardware.firmware = [ pkgs.firmwareOrangePiZero3 ];

    # Build against the selected running kernel, including a user override to
    # boot.kernelPackages such as pkgs.linuxPackages_latest.
    boot.extraModulePackages = [
      (config.boot.kernelPackages.callPackage ../../pkgs/driver-uwe5622 { })
    ];

    boot.kernelModules = [
      "uwe5622_bsp_sdio"
      "sprdwl_ng"
      "sprdbt_tty"
    ];
  };
}
