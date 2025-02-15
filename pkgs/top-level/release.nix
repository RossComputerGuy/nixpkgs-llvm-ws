let
  nixpkgs = import ./nixpkgs.nix;
  lib = import "${nixpkgs}/lib";
in
args:
import "${nixpkgs}/pkgs/top-level/release.nix" ({
  system = builtins.currentSystem;
} // args // {
  nixpkgsArgs = (args.nixpkgsArgs or {}) // {
    crossSystem = {
      useLLVM = true;
      linker = "lld";
      system = args.system or builtins.currentSystem;
    };
    overlays = [
      (import ../default.nix lib)
    ];
  };
})
