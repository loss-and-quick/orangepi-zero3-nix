{ lib, ... }:
let
  libx = import ../lib { inherit lib; };
in
{
  # Automatically imports all category subdirectories (hardware, profiles, services)
  imports = libx.allDirs ./.;

  nixpkgs.overlays = [
    (import ../pkgs/overlay.nix)
  ];
}
