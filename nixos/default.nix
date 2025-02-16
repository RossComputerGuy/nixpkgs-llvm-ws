{ config, lib, pkgs, ... }:
{
  config = {
    boot.loader.grub.enable = false;

    users.users.nixos = {
      createHome = true;
      isNormalUser = true;
      description = "NixOS";
      initialPassword = "nixos";
      extraGroups = [ "wheel" "networkmanager" "video" ];
    };

    programs.command-not-found.enable = false;

    services = {
      speechd.enable = false;
      pipewire.enable = false;
    };

    system = {
      stateVersion = lib.versions.majorMinor lib.version;
      disableInstallerTools = true;
    };

    documentation.enable = false;

    environment.systemPackages = with pkgs; [
      btop
    ];

    programs = {
      labwc.enable = true;
      firefox.enable = true;
    };

    xdg.portal = {
      enable = lib.mkForce false;
      wlr.enable = lib.mkForce false;
    };

    security = {
      polkit.enable = true;
      sudo = {
        enable = true;
        wheelNeedsPassword = false;
      };
    };

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
