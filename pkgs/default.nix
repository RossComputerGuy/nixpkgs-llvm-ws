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

  # PR: https://github.com/NixOS/nixpkgs/pull/329961
  boost = (prev.boost.override {
    boost-build = (prev.buildPackages.boost-build.override {
      useBoost = prev.buildPackages.boost;
    }).overrideAttrs (f: p: {
      patches = p.patches or [] ++ [
        (fetchpatch {
          url = "https://github.com/NixOS/nixpkgs/raw/3ca581d85960ff02cdfb039670006ba13096be95/pkgs/development/libraries/boost/fix-clang-target.patch";
          relative = "tools/build";
          hash = "sha256-4+KvKpV7c0D/AcHZeDMYZLS9suYNddwaqEfwxjPcYhk=";
        })
      ];
    });
  }).overrideAttrs (f: p: {
    patches = p.patches or [] ++ [
      (fetchpatch {
        url = "https://github.com/NixOS/nixpkgs/raw/3ca581d85960ff02cdfb039670006ba13096be95/pkgs/development/libraries/boost/fix-clang-target.patch";
        hash = "sha256-xKGjYPMcbgBzWOOYnGpC5PyKvs70P7N+Sg3vjNUxDPg=";
      })
    ];
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/329979
  nix = prev.nix.overrideAttrs (_: _: {
    doInstallCheck = !(stdenv.targetPlatform.useLLVM or false);
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/329993
  sourceHighlight = prev.sourceHighlight.overrideAttrs (f: p: {
    buildInputs = p.buildInputs or [] ++ [
      (llvmPackages.compiler-rt.override {
        doFakeLibgcc = true;
      })
    ];
    NIX_CFLAGS_COMPILE = "-lgcc";
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/329995
  valgrind = prev.valgrind.overrideAttrs (f: p: {
    buildInputs = p.buildInputs or [] ++ [
      (llvmPackages.compiler-rt.override {
        doFakeLibgcc = true;
      })
    ];
    doCheck = !(stdenv.targetPlatform.useLLVM or false && (stdenv.targetPlatform.isAarch64 || stdenv.targetPlatform.isx86_64));
  });

  valgrind-light = prev.valgrind-light.overrideAttrs (f: p: {
    buildInputs = p.buildInputs or [] ++ [
      (llvmPackages.compiler-rt.override {
        doFakeLibgcc = true;
      })
    ];
    doCheck = !(stdenv.targetPlatform.useLLVM or false && (stdenv.targetPlatform.isAarch64 || stdenv.targetPlatform.isx86_64));
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/330003
  libva = prev.libva.overrideAttrs (f: p: {
    NIX_CFLAGS_COMPILE = lib.optionalString (stdenv.targetPlatform.useLLVM or false) "-DHAVE_SECURE_GETENV";
    NIX_LDFLAGS = lib.optionalString (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") "--undefined-version";
  });

  libva-minimal = prev.libva-minimal.overrideAttrs (f: p: {
    NIX_CFLAGS_COMPILE = lib.optionalString (stdenv.targetPlatform.useLLVM or false) "-DHAVE_SECURE_GETENV";
    NIX_LDFLAGS = lib.optionalString (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") "--undefined-version";
  });
}
