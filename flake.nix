{
  description = "Flake workspace / repo to stage and track Nixpkgs/NixOS's ability to be compiled completely with LLVM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];
    extra-trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
    in
    (flake-utils.lib.eachSystem systems (
      system:
      let
        pkgs = import nixpkgs {
          localSystem = {
            config = system;
          };
          crossSystem = {
            config = system;
            useLLVM = true;
            linker = "lld";
          };
          overlays = [
            (import ./pkgs/default.nix lib)
          ];
        };
        #pkgs = nixpkgs.legacyPackages.${system}.pkgsLLVM.appendOverlays [ (import ./pkgs/default.nix lib) ];
      in
      {
        legacyPackages = pkgs;

        # Common packages we want to ensure work with LLVM
        packages = {
          inherit (pkgs)
            linux
            mesa
            bash
            stdenv
            systemd
            nix
            ;
        };
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        nixosConfigurations = lib.nixosSystem {
          inherit pkgs system;
          modules = [
            "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
            ./nixos/default.nix
            {
              virtualisation = {
                qemu.guestAgent.enable = false;
                host.pkgs = pkgs;
              };
            }
          ];
        };
        checks = flake-utils.lib.flattenTree (
          lib.recurseIntoAttrs {
            nixos-tests =
              let
                tests = import ./nixos/tests/all-tests.nix {
                  inherit system pkgs;
                  callTest = config: config.test;
                };
              in
              lib.recurseIntoAttrs {
                boot = lib.recurseIntoAttrs {
                  inherit
                    (
                      {
                        biosUsb = { };
                        biosCdrom = { };
                      }
                      // tests.boot
                    )
                    biosUsb
                    biosCdrom
                    uefiUsb
                    uefiCdrom
                    ;
                };
                inherit (tests) boot-stage1;
              };
          }
        );
      }
    ))
    // {
      hydraJobs =
        {
          nixos-toplevel = lib.mapAttrs (
            _: nixos: lib.hydraJob nixos.config.system.build.toplevel
          ) self.nixosConfigurations;
          nixos-vm = lib.mapAttrs (
            _: nixos: lib.hydraJob nixos.config.system.build.vm
          ) self.nixosConfigurations;
        }
        // (
          let
            genJobs =
              attrs:
              lib.listToAttrs (
                lib.map (
                  name:
                  lib.nameValuePair name (
                    lib.mapAttrs (_: drv: lib.hydraJob drv) (
                      lib.filterAttrs (_: v: v != null) (lib.genAttrs systems (system: attrs.${system}.${name} or null))
                    )
                  )
                ) (lib.flatten (lib.attrValues (lib.mapAttrs (_: set: lib.attrNames set) attrs)))
              );
          in
          genJobs self.checks // genJobs self.packages
        );
    };
}
