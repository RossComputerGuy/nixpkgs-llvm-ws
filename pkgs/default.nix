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

  # PR: https://github.com/NixOS/nixpkgs/pull/329817
  busybox = prev.busybox.override {
    stdenv = overrideCC stdenv buildPackages.llvmPackages.clangNoLibcxx;
  };

  # PR: https://github.com/NixOS/nixpkgs/pull/329823
  elfutils = prev.elfutils.overrideAttrs (f: p: {
    configureFlags = p.configureFlags ++ lib.optional (stdenv.targetPlatform.useLLVM or false) "--disable-demangler";
    NIX_CFLAGS_COMPILE = lib.optionalString (stdenv.targetPlatform.useLLVM or false) "-Wno-unused-private-field";
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/329827
  libseccomp = prev.libseccomp.overrideAttrs (_: _: {
    doCheck = !(stdenv.targetPlatform.useLLVM or false);
  });
}
