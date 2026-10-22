{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
}:

stdenv.mkDerivation {
  pname = "uwe5622";
  version = "1.0-unstable-2026-10-13";

  src = fetchFromGitHub {
    owner = "armbian";
    repo = "uwe5622";
    rev = "fa9d1a6703a93a85bcf68e865ebc2726474076ad";
    hash = "sha256-kbv1O0qPKnUGSrv4B+nq1YZcYZPOziWAeLw2aOkFhPA=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  # Upstream filp_open()s /lib/firmware/... directly; go through the kernel
  # firmware loader instead (works with hardware.firmware and compression).
  patches = [ ./0001-load-firmware-with-request_firmware.patch ];

  buildPhase = ''
    runHook preBuild
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      ${lib.escapeShellArgs kernelModuleMakeFlags} \
      M="$PWD" \
      KERNELRELEASE=${kernel.modDirVersion} \
      UNISOC_BSP_INCLUDE="$PWD/unisocwcn/include" \
      CONFIG_AW_WIFI_DEVICE_UWE5622=y \
      CONFIG_WLAN_UWE5622=m \
      CONFIG_TTY_OVERY_SDIO=m \
      modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      ${lib.escapeShellArgs kernelModuleMakeFlags} \
      M="$PWD" \
      KERNELRELEASE=${kernel.modDirVersion} \
      INSTALL_MOD_PATH="$out" \
      INSTALL_MOD_DIR=kernel/drivers/net/wireless/uwe5622 \
      modules_install
    runHook postInstall
  '';

  meta = with lib; {
    description = "Linux kernel module for Unisoc UWE5622 / AW859A (WiFi + BT)";
    homepage = "https://github.com/armbian/uwe5622";
    license = licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
  };
}
