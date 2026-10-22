final: prev:
let
  customPkgs = import ./default.nix { pkgs = prev; };
in
{
  orangepi = customPkgs;
  inherit (customPkgs) firmwareOrangePiZero3;
}
