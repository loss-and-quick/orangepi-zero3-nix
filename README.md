# Orange Pi Zero 3 — NixOS board support

NixOS modules and packages for the **Orange Pi Zero 3** (Allwinner H618) as a
small stateless server:

- Stock nixpkgs Linux 6.18 LTS (substituted from cache.nixos.org), with an
  out-of-tree device-tree overlay for Wi-Fi.
- Out-of-tree Unisoc UWE5622 (AW859A) Wi-Fi/BT driver and its firmware.
- Mainline U-Boot (nixpkgs `ubootOrangePiZero3`, overridable via `hardware.orangepi.zero3.uboot`).
- A stateless SD layout: `/` in tmpfs, everything else on one ext4 partition.
- An SD image builder (`config.system.build.sdImage`).

Hosts, users and secrets are not part of this flake: import the module into
your own configuration.

## Layout

```
modules/
  hardware/orangepi-zero3.nix  stock kernel, Wi-Fi DT overlay, extlinux, console; optional cross-built U-Boot
  hardware/uwe5622.nix         Wi-Fi/BT module + firmware, built for boot.kernelPackages
  profiles/stateless.nix       tmpfs root, /nix + /boot + /persist from the SD partition
  image/default.nix            SD image: U-Boot SPL at 8 KiB, NIXOS_SD ext4
pkgs/                          driver-uwe5622, firmware (+ overlay.nix)
hosts/orangepi-zero3/          minimal reference host (Ethernet DHCP, SSH key only)
```

## Usage

```nix
# flake.nix
inputs.orangepi.url = "github:loss-and-quick/orangepi-zero3-nix";

# host configuration
{
  imports = [ inputs.orangepi.nixosModules.default ];

  hardware.orangepi.zero3.enable = true;
  hardware.orangepi.uwe5622.enable = true;
  profiles.stateless.enable = true;

  # Build only U-Boot on x86_64. The stock kernel remains fetched from the
  # binary cache and the small Wi-Fi module builds natively through binfmt.
  hardware.orangepi.zero3.crossBuildSystem = "x86_64-linux";

  # Optional: use the current kernel instead of the default LTS kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
```

Build the image with `nix build .#nixosConfigurations.<host>.config.system.build.sdImage`.
This repository's reference host builds with `nix build .#sdImage`; on x86_64
it is fully cross-compiled, kernel included, so expect a long first build.

## Stateless layout

| Path             | Backing                                     |
| ---------------- | ------------------------------------------- |
| `/`              | tmpfs (`profiles.stateless.tmpfsSize`)      |
| `/nix-disk`      | the `NIXOS_SD` ext4 partition, `noatime`    |
| `/nix`, `/boot`  | bind mounts of `/nix-disk/{nix,boot}`       |
| `/persist`       | bind mount of `/nix-disk/persist`           |
| `/var/lib/nixos` | bind mount of `/persist/var/lib/nixos`      |

`/nix-disk`, `/nix`, `/persist` and `/var/lib/nixos` are mounted in stage 1,
so activation-time consumers (e.g. a sops-nix key at
`/persist/etc/ssh/ssh_host_ed25519_key`, the default SSH host key path set by
the profile) already see them. Journald is volatile and swap is zram.

On first boot the image registers its store paths and grows the partition to
the whole card. Updates are ordinary `nixos-rebuild switch` runs.

## Notes

- Wi-Fi power: WL_REG_ON (PG18) is modelled as a GPIO regulator feeding
  `mmc1`, not as `reset-gpios` of `mmc-pwrseq-simple`. Since Linux 6.13 a
  single pwrseq reset GPIO goes through the `reset-gpio` driver, which rejects
  Allwinner's 3-cell GPIO specifiers (`reset control not ready`).
- The UWE5622 driver is patched to load its firmware with `request_firmware()`
  instead of opening hardcoded `/lib/firmware` paths.
- The GPU power-domain driver (`sun50i_h6_prcm_ppu`) is loaded in the initrd;
  loaded later, panfrost gives up with `-110`.

## Known issues

A warm reboot can leave Ethernet unavailable with `EMAC reset timeout` because
mainline `dwmac-sun8i` still resets the MAC before the external YT8531 PHY has
been resumed. This is not fixed in Linux 6.18 or 7.3. The board has no PHY
reset GPIO and its PHY supply is shared, so there is no verified device-tree or
module-parameter workaround. The upstream fix is under review:
[netdev patch](https://lore.kernel.org/netdev/20260822045641.19282-1-hartmnn.p@gmail.com/).
Until it lands in a cached nixpkgs kernel, use a cold boot after this failure.

## Flashing

Write the image to the card with any raw writer (`dd`, `caligula`, ...). The
serial console is on the 3-pin debug header (`ttyS0`, 115200 8N1).

Files that must exist before the first boot (an SSH host key used by sops-nix,
for example) go into `persist/` on the `NIXOS_SD` partition after writing.
