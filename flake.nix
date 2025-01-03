{
  description = "Flake workspace / repo to stage and track Nixpkgs/NixOS's ability to be compiled completely with LLVM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
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
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;

      flake = {
        overlays.default = import ./pkgs/default.nix lib;

        nixosConfigurations = lib.filterAttrs (_: v: v != null) (
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
                      host.pkgs = pkgs;
                    };
                  }
                ];
              }
            else
              null
          )
        );
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
