{ config, lib, pkgs, ... }:
{
  config = {
    boot.loader.grub.enable = false;

    users = {
      users = {
        nixos = {
          createHome = true;
          isNormalUser = true;
          description = "NixOS";
          initialPassword = "nixos";
          extraGroups = [ "wheel" "networkmanager" "video" ];
        };
        cosmic-greeter = {
          description = "COSMIC login greeter user";
          isSystemUser = true;
          home = "/var/lib/cosmic-greeter";
          createHome = true;
          group = "cosmic-greeter";
        };
      };
      groups.cosmic-greeter = {};
    };

    programs.command-not-found.enable = false;

    services = {
      accounts-daemon.enable = true;
      dbus.packages = with pkgs; [ cosmic-greeter ];
      speechd.enable = false;
      pipewire.enable = true;
      udev.packages = [ pkgs.libinput.out ];
      greetd = {
        enable = true;
        settings.default_session.command = ''${lib.getExe' pkgs.coreutils "env"} XCURSOR_THEME="''${XCURSOR_THEME:-Pop}" systemd-cat -t cosmic-greeter ${lib.getExe pkgs.cosmic-comp} ${lib.getExe pkgs.cosmic-greeter}'';
      };
    };

    system = {
      stateVersion = lib.versions.majorMinor lib.version;
      disableInstallerTools = true;
    };

    documentation.enable = false;

    environment.systemPackages = with pkgs; [
      btop
    ];

    systemd.services.cosmic-greeter-daemon = {
      wantedBy = [ "multi-user.target" ];
      before = [ "greetd.service" ];
      serviceConfig = {
        Type = "dbus";
        BusName = "com.system76.CosmicGreeter";
        ExecStart = lib.getExe' pkgs.cosmic-greeter "cosmic-greeter-daemon";
        Restart = "on-failure";
      };
    };

    programs = {
      sway = {
        enable = true;
        package = pkgs.swayfx;
        extraPackages = lib.mkForce (with pkgs; [ brightnessctl foot grim swayidle swaylock wmenu ]);
        extraOptions = [
          "-c"
          "${pkgs.swayfx}/etc/sway/config"
        ];
      };
      #firefox = {
      #  enable = true;
      #  package = pkgs.pkgsBuildBuild.firefox;
      #};
    };

    xdg.portal = {
      enable = lib.mkForce false;
      wlr.enable = lib.mkForce false;
      extraPortals = lib.mkForce [];
    };

    security = {
      pam.services.cosmic-greeter = {};
      polkit.enable = true;
      sudo = {
        enable = true;
        wheelNeedsPassword = false;
      };
    };

    hardware.graphics.enable = true;

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
