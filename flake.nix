{
  description = "Flake workspace / repo to stage and track Nixpkgs/NixOS's ability to be compiled completely with LLVM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    systems.url = "github:nix-systems/default-linux";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];
    extra-trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      flake-parts,
      nixos-hardware,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;

      flake = {
        hydraJobs =
          lib.recursiveUpdate
            self.packages
            {
              aarch64-linux = {
                rpi4 = self.nixosConfigurations.rpi4.config.system.build.sdImage;
              };
            };

        overlays.default = import ./pkgs/default.nix lib;

        nixosConfigurations =
          lib.filterAttrs (_: v: v != null) (
            lib.genAttrs (import systems) (
              system:
              let
                pkgs = inputs.self.legacyPackages.${system};
              in
              if pkgs.hostPlatform.isLinux then
                inputs.nixpkgs.lib.nixosSystem {
                  inherit system pkgs;

                  modules = [
                    "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
                    ./nixos/default.nix
                    {
                      virtualisation = {
                        qemu.guestAgent.enable = false;
                        host.pkgs = pkgs.pkgsBuildBuild;
                      };
                    }
                  ];
                }
              else
                null
            )
          )
          // {
            rpi4 = inputs.nixpkgs.lib.nixosSystem {
              system = "aarch64-linux";
              pkgs = inputs.self.legacyPackages.aarch64-linux;

              modules = [
                inputs.nixos-hardware.nixosModules.raspberry-pi-4
                ./nixos/default.nix
                "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
                (
                  { pkgs, lib, ... }:
                  {
                    hardware = {
                      raspberry-pi."4" = {
                        apply-overlays-dtmerge.enable = true;
                        pwm0.enable = true;
                        fkms-3d.enable = true;
                      };
                      deviceTree.enable = true;
                      enableAllHardware = lib.mkForce false;
                    };

                    environment.systemPackages = with pkgs; [
                      libraspberrypi
                      raspberrypi-eeprom
                    ];

                    services.openssh.enable = true;

                    boot = {
                      supportedFilesystems = lib.mkForce [
                        "btrfs"
                        "f2fs"
                        "ntfs"
                        "vfat"
                        "xfs"
                      ];
                      kernelParams = [ "console=serial0,115200" "cma=256M" ];
                    };
                  }
                )
              ];
            };
          };
      };

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs =
            (import inputs.nixpkgs {
              inherit system;
              overlays = [
                inputs.self.overlays.default
              ];
              config = { };
            }).pkgsLLVM;

          legacyPackages = pkgs;

          packages =
            {
              inherit (pkgs)
                mesa
                bash
                stdenv
                nix
                jemalloc
                firefox
                ;
            }
            // lib.optionalAttrs pkgs.hostPlatform.isLinux {
              inherit (pkgs)
                linux
                systemd
                ;

              nixos-vm = self.nixosConfigurations.${system}.config.system.build.toplevel;
            };
        };
    };
}
