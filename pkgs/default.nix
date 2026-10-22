{ pkgs }:
{
  # Unisoc UWE5622 / AW859A WiFi & BT firmware
  firmwareOrangePiZero3 = pkgs.callPackage ./firmware { };
}
