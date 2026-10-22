# Stateless operation on a single SD card partition.
#
#   /          tmpfs, wiped on every boot
#   /nix-disk  the NIXOS_SD ext4 partition (rw, noatime)
#   /nix       bind of /nix-disk/nix
#   /boot      bind of /nix-disk/boot (U-Boot reads extlinux.conf from here)
#   /persist   bind of /nix-disk/persist: the only state that survives a reboot
#
# /nix-disk, /nix and /persist are mounted in stage 1, so activation-time
# consumers (sops-nix host key, users' uid/gid maps) already see them.
{
  config,
  lib,
  ...
}:
let
  cfg = config.profiles.stateless;
  disk = "/nix-disk";

  bind = device: {
    inherit device;
    fsType = "none";
    options = [ "bind" ];
  };
in
{
  options.profiles.stateless = {
    enable = lib.mkEnableOption "stateless operation: root in tmpfs, Nix store and /persist on the SD card";

    tmpfsSize = lib.mkOption {
      type = lib.types.str;
      default = "2G";
      description = "Maximum size of the root tmpfs.";
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/disk/by-label/NIXOS_SD";
      description = "Partition holding /nix, /boot and /persist.";
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems = {
      "/" = lib.mkForce {
        device = "none";
        fsType = "tmpfs";
        options = [
          "defaults"
          "size=${cfg.tmpfsSize}"
          "mode=755"
        ];
      };

      ${disk} = {
        device = cfg.device;
        fsType = "ext4";
        options = [
          "noatime"
          "errors=remount-ro"
        ];
        neededForBoot = true;
      };

      "/nix" = bind "${disk}/nix" // {
        neededForBoot = true;
      };

      "/persist" = bind "${disk}/persist" // {
        neededForBoot = true;
      };

      # uid/gid allocation maps: keep them stable across reboots
      "/var/lib/nixos" = bind "/persist/var/lib/nixos" // {
        neededForBoot = true;
      };

      "/boot" = lib.mkForce (bind "${disk}/boot");
    };

    services.openssh.hostKeys = lib.mkDefault [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];

    systemd.tmpfiles.rules = [
      "d /persist/etc/ssh 0755 root root -"
      "d /persist/var/lib 0755 root root -"
    ];

    # Logs in RAM only: no SD wear, lost on reboot
    services.journald.settings.Journal = {
      Storage = "volatile";
      RuntimeMaxUse = "64M";
    };

    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 50;
    };

    boot.tmp.useTmpfs = true;
    boot.tmp.tmpfsSize = "1G";
  };
}
