lib: final: prev: with final;
{
  # PR: https://github.com/NixOS/nixpkgs/pull/320432
  rust_1_79 = callPackage ./development/compilers/rust/1_79.nix {
    inherit (darwin.apple_sdk.frameworks) CoreFoundation Security SystemConfiguration;
    llvm_18 = llvmPackages_18.libllvm;
  };

  xorg = prev.xorg.overrideScope (f: p: {
    # PR: https://github.com/NixOS/nixpkgs/pull/329584
    libX11 = p.libX11.overrideAttrs (attrs: {
       configureFlags = attrs.configureFlags or []
          ++ lib.optional (stdenv.targetPlatform.useLLVM or false) "ac_cv_path_RAWCPP=cpp";
    });
  });
}
