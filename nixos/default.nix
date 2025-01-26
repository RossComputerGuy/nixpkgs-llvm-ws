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

    programs.command-not-found.enable = false;

    system = {
      stateVersion = lib.version;
      disableInstallerTools = true;
    };

    documentation.enable = false;

    boot.kernelPatches = lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 [
      {
        name = "aarch64-vdso";
        patch = null;
        extraStructuredConfig = with lib.kernel; {
          COMPAT = no;
        };
      }
    ];
  };
}
