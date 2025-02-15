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
      linker = "ldd";
      system = args.system or builtins.currentSystem;
    };
  };
})
