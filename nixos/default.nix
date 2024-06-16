{ config, lib, pkgs, ... }:
{
  config = {
    users.users.nixos = {
      createHome = true;
      isNormalUser = true;
      description = "NixOS";
      initialPassword = "nixos";
    };

    system.stateVersion = lib.version;
  };
}
