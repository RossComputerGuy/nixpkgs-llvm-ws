{
  description = "Flake workspace / repo to stage and track Nixpkgs/NixOS's ability to be compiled completely with LLVM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.pkgsLLVM.appendOverlays [
          (import ./pkgs/default.nix nixpkgs.lib)
        ];
        inherit (pkgs) lib;
      in {
        legacyPackages = pkgs;

        nixosConfigurations = lib.nixosSystem {
          inherit pkgs system;
          modules = [ ./nixos/default.nix ];
        };

        # Common packages we want to ensure work with LLVM
        packages = {
          inherit (pkgs) linux mesa bash stdenv;
        };
      });
}
