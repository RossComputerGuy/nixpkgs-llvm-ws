let
  nixpkgs = import ./nixpkgs.nix;
  lib = import "${nixpkgs}/lib";
in
{
  officialRelease ? false,
  nixpkgs-llvm-ws ? { },
}@args:
import "${nixpkgs}/pkgs/top-level/release.nix" (
  {
    system = builtins.currentSystem;
  }
  // (lib.removeAttrs args [ "nixpkgs-llvm-ws" ])
  // {
    nixpkgsArgs = (args.nixpkgsArgs or { }) // {
      crossSystem = {
        useLLVM = true;
        linker = "lld";
        system = args.system or builtins.currentSystem;
      };
      overlays = [
        (import ../default.nix lib)
      ];
    };
  }
)
