# Minimal reference host for the Orange Pi Zero 3: boots the stateless layout
# over Ethernet (DHCP) and accepts SSH keys only. Real deployments define
# their own host (users, secrets, services) and import nixosModules.default.
{ lib, ... }:
{
  networking.hostName = "orangepi-zero3";

  hardware.orangepi.zero3.enable = true;
  hardware.orangepi.uwe5622.enable = true;
  profiles.stateless.enable = true;

  networking.useDHCP = lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.mutableUsers = false;
  # Add your public key here to log in to the reference image; until then the
  # image boots but nobody can log in.
  users.users.root.openssh.authorizedKeys.keys = [ ];
  users.allowNoPasswordLogin = true;

  documentation.enable = false;

  system.stateVersion = "26.11";
}
