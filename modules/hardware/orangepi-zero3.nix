{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.orangepi.zero3;
in
{
  options.hardware.orangepi.zero3 = {
    enable = lib.mkEnableOption "Orange Pi Zero 3 (Allwinner H618) hardware support";

    crossBuildSystem = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "x86_64-linux";
      description = ''
        Build U-Boot in a cross package set from this system. The kernel and
        out-of-tree Wi-Fi module always use the native aarch64 package set:
        this keeps the stock kernel substitutable from cache.nixos.org and
        lets the small Wi-Fi module follow the selected boot.kernelPackages.
      '';
    };

    uboot = lib.mkOption {
      type = lib.types.package;
      default = cfg.packages.ubootOrangePiZero3;
      defaultText = lib.literalExpression "config.hardware.orangepi.zero3.packages.ubootOrangePiZero3";
      description = ''
        U-Boot written into the SD image (must provide u-boot-sunxi-with-spl.bin).
        Override to change its configuration, e.g. via overrideAttrs on extraConfig.
      '';
    };

    packages = lib.mkOption {
      type = lib.types.raw;
      internal = true;
      readOnly = true;
      description = "Package set the board-specific packages are taken from.";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.orangepi.zero3.packages =
      if cfg.crossBuildSystem == null then
        pkgs
      else
        import pkgs.path {
          localSystem = cfg.crossBuildSystem;
          crossSystem = pkgs.stdenv.hostPlatform.system;
          overlays = [ (import ../../pkgs/overlay.nix) ];
        };

    nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

    # Bootloader: U-Boot reads /boot/extlinux/extlinux.conf from the ext4 partition
    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;
    boot.loader.generic-extlinux-compatible.configurationLimit = lib.mkDefault 5;

    # Kernel & Drivers
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;

    hardware.deviceTree = {
      enable = true;
      name = "allwinner/sun50i-h618-orangepi-zero3.dtb";
      filter = "sun50i-h618-orangepi-zero3.dtb";
      overlays = [
        {
          name = "orangepi-zero3-wifi";
          # UWE5622 on mmc1, modelled on the mainline H618 Transpeed 8K618-T DT.
          #
          # WL_REG_ON (PG18) is driven by a GPIO regulator used as vmmc-supply
          # instead of the usual pwrseq reset-gpios: since 6.13 pwrseq_simple
          # routes a single reset GPIO through the reset-gpio driver, which
          # rejects 3-cell Allwinner GPIO specifiers (-ENOENT, "reset control
          # not ready"), see
          # https://lists.infradead.org/pipermail/linux-riscv/2026-April/090037.html
          # The pwrseq only feeds the 32 kHz clock (PG10 fanout) to the chip.
          dtsText = ''
            /dts-v1/;
            /plugin/;

            / {
              compatible = "xunlong,orangepi-zero3";

              fragment@0 {
                target-path = "/";
                __overlay__ {
                  reg_wl_reg_on: wl-reg-on {
                    compatible = "regulator-fixed";
                    regulator-name = "wl-reg-on";
                    regulator-min-microvolt = <3300000>;
                    regulator-max-microvolt = <3300000>;
                    vin-supply = <&reg_dldo1>;
                    gpio = <&pio 6 18 0>; /* PG18, active high */
                    enable-active-high;
                  };

                  wifi_pwrseq: wifi-pwrseq {
                    compatible = "mmc-pwrseq-simple";
                    clocks = <&rtc 1>; /* CLK_OSC32K_FANOUT */
                    clock-names = "ext_clock";
                    pinctrl-0 = <&x32clk_fanout_pin>;
                    pinctrl-names = "default";
                    post-power-on-delay-ms = <200>;
                  };
                };
              };

              fragment@1 {
                target = <&mmc1>;
                __overlay__ {
                  vmmc-supply = <&reg_wl_reg_on>;
                  vqmmc-supply = <&reg_aldo1>;
                  mmc-pwrseq = <&wifi_pwrseq>;
                  bus-width = <4>;
                  non-removable;
                  status = "okay";
                };
              };
            };
          '';
        }
      ];
    };

    boot.kernelParams = [
      "console=ttyS0,115200n8"
      "console=tty1"
      "earlycon=uart8250,mmio32,0x05000000"
      "panic=10"
    ];

    boot.initrd.availableKernelModules = [
      "sunxi_mmc"
      "mmc_block"
      "motorcomm"
      "dwmac_sun8i"
      "axp20x_i2c"
    ];

    # GPU power domain provider. Loaded by udev in stage 2 it comes after the
    # deferred-probe timeout, and panfrost then fails with -110.
    boot.initrd.kernelModules = [ "sun50i_h6_prcm_ppu" ];

    hardware.enableRedistributableFirmware = lib.mkDefault true;
  };
}
