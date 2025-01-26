{
  description = "Flake workspace / repo to stage and track Nixpkgs/NixOS's ability to be compiled completely with LLVM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    systems.url = "github:nix-systems/default";
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
                (
                  { pkgs, ... }:
                  {
                    hardware = {
                      raspberry-pi."4".apply-overlays-dtmerge.enable = true;
                      deviceTree = {
                        enable = true;
                        filter = "*rpi-4-*.dtb";
                      };
                    };

                    environment.systemPackages = with pkgs; [
                      libraspberrypi
                      raspberrypi-eeprom
                    ];

                    fileSystems = {
                      "/" = {
                        device = "/dev/mmcblk0p2";
                        fsType = "ext4";
                      };
                      "/boot" = {
                        device = "/dev/mmcblk0p1";
                        fsType = "vfat";
                      };
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
                ;
            }
            // lib.optionalAttrs pkgs.hostPlatform.isLinux {
              inherit (pkgs)
                linux
                systemd
                ;
            };
        };
    };
}
