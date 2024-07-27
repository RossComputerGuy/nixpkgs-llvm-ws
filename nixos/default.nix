{ config, lib, pkgs, ... }:
{
  config = {
    boot.loader.grub.enable = false;

    users.users.nixos = {
      createHome = true;
      isNormalUser = true;
      description = "NixOS";
      initialPassword = "nixos";
    };

    system = {
      stateVersion = lib.version;
      disableInstallerTools = true;
    };

    documentation.enable = false;

    virtualisation.qemu = {
      package = pkgs.buildPackages.qemu;
      guestAgent.enable = false;
    };

    i18n.glibcLocales = pkgs.glibcLocales.override {
      stdenv = pkgs.gccStdenv;
    };
  };
}
