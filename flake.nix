{
  description = "NixOS board support for the Orange Pi Zero 3 (Allwinner H618): kernel, Wi-Fi, U-Boot, stateless SD layout";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    let
      # Reference host built from this flake alone (no secrets, Ethernet + SSH key)
      mkSystem =
        buildPlatform:
        nixpkgs.lib.nixosSystem {
          modules = [
            self.nixosModules.default
            ./hosts/orangepi-zero3
            {
              nixpkgs.hostPlatform = "aarch64-linux";
              nixpkgs.buildPlatform = buildPlatform;
            }
          ];
        };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      flake = {
        overlays.default = import ./pkgs/overlay.nix;

        # Hardware, stateless profile and SD image in one bundle (also applies
        # the overlay); each part is inert until its enable option is set.
        nixosModules.default = import ./modules;

        nixosConfigurations = {
          orangepi-zero3 = mkSystem "aarch64-linux";
          # Same host, fully cross-compiled on an x86_64 machine without QEMU
          orangepi-zero3-cross = mkSystem "x86_64-linux";
        };
      };

      perSystem =
        { pkgs, system, ... }:
        let
          host =
            if system == "x86_64-linux" then
              self.nixosConfigurations.orangepi-zero3-cross
            else
              self.nixosConfigurations.orangepi-zero3;
          boardPkgs = import ./pkgs { inherit pkgs; };
        in
        {
          packages = {
            sdImage = host.config.system.build.sdImage;
            firmware = boardPkgs.firmwareOrangePiZero3;
          };

          formatter = pkgs.nixfmt-tree;
        };
    };
}
