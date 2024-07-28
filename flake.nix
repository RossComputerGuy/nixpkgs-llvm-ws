{
  description = "Flake workspace / repo to stage and track Nixpkgs/NixOS's ability to be compiled completely with LLVM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];
    extra-trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        inherit (nixpkgs) lib;

        pkgsHost = nixpkgs.legacyPackages.${system};
        pkgs = pkgsHost.pkgsLLVM.appendOverlays [
          (import ./pkgs/default.nix lib)
        ];
      in {
        legacyPackages = pkgs;

        # Common packages we want to ensure work with LLVM
        packages = {
          inherit (pkgs) linux mesa bash stdenv systemd nix qemu_kvm;
        };
      } // lib.optionalAttrs pkgs.stdenv.isLinux {
        nixosConfigurations = lib.nixosSystem {
          inherit pkgs system;
          modules = [
            "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
            ./nixos/default.nix
            {
              virtualisation = {
                qemu = {
                  package = pkgsHost.qemu;
                  guestAgent.enable = false;
                };
                host.pkgs = pkgsHost;
              };
            }
          ];
        };
      });
}
