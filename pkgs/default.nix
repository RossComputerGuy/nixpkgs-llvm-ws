lib: final: prev: with final;
{
  # PR: https://github.com/NixOS/nixpkgs/pull/320432
  rust_1_79 = callPackage ./development/compilers/rust/1_79.nix {
    inherit (darwin.apple_sdk.frameworks) CoreFoundation Security SystemConfiguration;
    llvm_18 = llvmPackages_18.libllvm;
  };
}
