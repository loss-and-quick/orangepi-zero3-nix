{ lib, ... }:
let
  libx = import ../../lib { inherit lib; };
in
{
  imports = libx.autoImport ./.;
}
