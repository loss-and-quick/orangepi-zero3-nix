# Flashable SD card image (config.system.build.sdImage).
#
# Layout: U-Boot SPL raw at 8 KiB, a small unused FIRMWARE vfat (required by
# the generic sd-image builder), and the bootable NIXOS_SD ext4 that carries
# /nix, /boot/extlinux and /persist (see profiles/stateless.nix).
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  zero3 = config.hardware.orangepi.zero3;
  stateless = config.profiles.stateless.enable;
in
{
  imports = [ "${modulesPath}/installer/sd-card/sd-image.nix" ];

  config = lib.mkIf zero3.enable (
    lib.mkMerge [
      {
        sdImage = {
          compressImage = false;
          firmwareSize = 16;
          populateFirmwareCommands = "";
          populateRootCommands = ''
            mkdir -p ./files/boot
            ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
          ''
          + lib.optionalString stateless ''
            # Bind sources must exist before the first boot mounts them
            mkdir -p ./files/persist/etc/ssh ./files/persist/var/lib/nixos
          '';
          postBuildCommands = ''
            dd if=${zero3.uboot}/u-boot-sunxi-with-spl.bin of=$img bs=8 seek=1024 conv=notrunc
          '';
        };
      }

      (lib.mkIf stateless {
        # With / in tmpfs the registration file is only visible on the SD partition
        sdImage.nixPathRegistrationFile = "/nix-disk/nix-path-registration";

        # Upstream grows the partition mounted at /, which is tmpfs here
        systemd.services.expand-root-partition = {
          path = with pkgs; [
            util-linux
            e2fsprogs
          ];
          script = lib.mkForce ''
            rootPart=$(findmnt -n -o SOURCE /nix-disk)
            bootDevice=$(lsblk -npo PKNAME "$rootPart")
            partNum=$(cat /sys/class/block/"$(basename "$rootPart")"/partition)

            echo ",+," | sfdisk -N"$partNum" --no-reread "$bootDevice"
            partx -u -n "$partNum" "$bootDevice"
            resize2fs "$rootPart"
          '';
        };
      })
    ]
  );
}
