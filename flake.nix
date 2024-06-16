{
  description = "Flake workspace / repo to stage and track Nixpkgs/NixOS's ability to be compiled completely with LLVM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        inherit (nixpkgs) lib;

        pkgs = nixpkgs.legacyPackages.${system}.pkgsLLVM.appendOverlays [
          (import ./pkgs/default.nix lib)
        ];
      in {
        legacyPackages = pkgs;

        # Common packages we want to ensure work with LLVM
        packages = {
          inherit (pkgs) linux mesa bash stdenv systemd;
        };
      } // lib.optionalAttrs pkgs.stdenv.isLinux {
        nixosConfigurations = lib.nixosSystem {
          inherit pkgs system;
          modules = [
            "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
            ./nixos/default.nix
          ];
        };
      });
}
