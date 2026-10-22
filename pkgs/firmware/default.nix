{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "uwe5622-firmware";
  version = "6.1.31-sun50iw9";

  src = fetchFromGitHub {
    owner = "orangepi-xunlong";
    repo = "firmware";
    rev = "b2809d6c7a79ab874a91b84b9b0d9169cb41a749";
    hash = "sha256-cLSkfm25st6lyV/PJtUMM+Wu2r0IfLmVDGAYzafcC2Q=";
  };

  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    # Requested by file name through the kernel firmware loader
    install -Dm644 -t $out/lib/firmware wcnmodem.bin wifi_2355b001_1ant.ini bt_configure_*.ini
    runHook postInstall
  '';

  meta = with lib; {
    description = "Firmware for Unisoc UWE5622 (AW859A) on Orange Pi Zero 3";
    homepage = "https://github.com/orangepi-xunlong/firmware";
    license = licenses.unfreeRedistributableFirmware;
    platforms = [ "aarch64-linux" ];
  };
}
