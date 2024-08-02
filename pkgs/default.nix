lib: final: prev: with final;
{
  # PR: https://github.com/NixOS/nixpkgs/pull/330037
  wrapRustcWith = { rustc-unwrapped, ... } @ args: callPackage ./build-support/rust/rustc-wrapper args;

  # PR: https://github.com/NixOS/nixpkgs/pull/320432
  rust_1_79 = callPackage ./development/compilers/rust/1_79.nix {
    inherit (darwin.apple_sdk.frameworks) CoreFoundation Security SystemConfiguration;
    llvm_18 = llvmPackages_18.libllvm;
  };

  rust = rust_1_79;

  rustPackages_1_79 = rust_1_79.packages.stable;
  rustPackages = rustPackages_1_79;

  inherit (rustPackages) cargo cargo-auditable cargo-auditable-cargo-wrapper clippy rustc rustPlatform;

  xorg = prev.xorg.overrideScope (f: p: {
    # PR: https://github.com/NixOS/nixpkgs/pull/329584
    libX11 = p.libX11.overrideAttrs (attrs: {
       configureFlags = attrs.configureFlags or []
          ++ lib.optional (stdenv.targetPlatform.useLLVM or false) "ac_cv_path_RAWCPP=cpp";
    });
    # PR: https://github.com/NixOS/nixpkgs/pull/330289
    libXt = (p.libXt.override {
      stdenv = overrideCC stdenv (stdenv.cc.override {
        extraBuildCommands = ''
          substituteAll ${fetchurl {
            url = "https://github.com/ExpidusOS/nixpkgs/raw/54f2c3cd0d5ea3c8cde91ee78fb15dcabac6924d/pkgs/build-support/cc-wrapper/add-clang-cc-cflags-before.sh";
            hash = "sha256-rQoUWv2Sdh5/+G6d/Mb39i7cmDEukPKfMRJ73zczUoM=";
          }} $out/nix-support/add-local-cc-cflags-before.sh

          rsrc="$out/resource-root"
          mkdir "$rsrc"
          ln -s "${stdenv.cc.cc.lib}/lib/clang/${lib.versions.major stdenv.cc.cc.version}/include" "$rsrc"
          echo "-resource-dir=$rsrc" >> $out/nix-support/cc-cflags

          ln -s "${llvmPackages.compiler-rt.out}/lib" "$rsrc/lib"
          ln -s "${llvmPackages.compiler-rt.out}/share" "$rsrc/share"
        '';
      });
    }).overrideAttrs (attrs: {
      configureFlags = attrs.configureFlags or []
        ++ lib.optional (stdenv.targetPlatform.useLLVM or false) "ac_cv_path_RAWCPP=cpp";
    });
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/329817
  busybox = prev.busybox.override {
    stdenv = overrideCC stdenv buildPackages.llvmPackages.clangNoLibcxx;
  };

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
      ((llvmPackages.compiler-rt.override {
        doFakeLibgcc = true;
        stdenv = llvmPackages.compiler-rt-no-libc.stdenv.override {
          hostPlatform = llvmPackages.compiler-rt-no-libc.stdenv.hostPlatform // {
            parsed = {
              kernel.name = "none";
              inherit (llvmPackages.compiler-rt-no-libc.stdenv.hostPlatform.parsed) cpu;
            };
            useLLVM = false;
          };
        };
      }).overrideAttrs (f: p: {
        hardeningDisable = p.hardeningDisable or []
          ++ [ "pie" "stackprotector" ];
      }))
    ];
    doCheck = !(stdenv.targetPlatform.useLLVM or false && (stdenv.targetPlatform.isAarch64 || stdenv.targetPlatform.isx86_64));
  });

  valgrind-light = prev.valgrind-light.overrideAttrs (f: p: {
    buildInputs = p.buildInputs or [] ++ [
      ((llvmPackages.compiler-rt-no-libc.override {
        doFakeLibgcc = true;
        stdenv = llvmPackages.compiler-rt-no-libc.stdenv.override {
          hostPlatform = llvmPackages.compiler-rt-no-libc.stdenv.hostPlatform // {
            parsed = {
              kernel.name = "none";
              inherit (llvmPackages.compiler-rt-no-libc.stdenv.hostPlatform.parsed) cpu;
            };
            useLLVM = false;
          };
        };
      }).overrideAttrs (f: p: {
        hardeningDisable = p.hardeningDisable or []
          ++ [ "pie" "stackprotector" ];
      }))
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

  # PR: https://github.com/NixOS/nixpkgs/pull/330008
  systemd = prev.systemd.overrideAttrs (f: p: {
    buildInputs = p.buildInputs or [] ++ [
      (llvmPackages.compiler-rt.override {
        doFakeLibgcc = true;
      })
    ];
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/330014
  libunwind = prev.libunwind.overrideAttrs (f: p: {
    patches = p.patches or [] ++ [
      (fetchpatch {
        url = "https://github.com/libunwind/libunwind/pull/770/commits/a69d0f14c9e6c46e82ba6e02fcdedb2eb63b7f7f.patch";
        hash = "sha256-9oBZimCXonNN++jJs3emp9w+q1aj3eNzvSKPgh92itA=";
      })
    ];
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/330048
  linuxPackages = prev.linuxPackages.extend (self: super: {
    kernel = super.kernel.overrideAttrs (f: p: {
      patches = p.patches or []
        ++ lib.optional (lib.versionAtLeast f.version "6.6" &&
                       stdenv.cc.bintools.isLLVM &&
                       stdenv.targetPlatform.isx86_64)
          (fetchurl {
            url = "https://lore.kernel.org/all/20240208012057.2754421-2-yshuiv7@gmail.com/t.mbox.gz";
            hash = "sha256-DVC9hZ5n+vyS0jroygN2tCAHPPiL+oGbezxdm2yM6s8=";
          });

      hardeningDisable = p.hardeningDisable or []
        ++ lib.optional (stdenv.cc.isClang && stdenv.targetPlatform.parsed.cpu.family == "arm") "zerocallusedregs";
    });
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/330065
  glslang = prev.glslang.overrideAttrs (f: p: {
    outputs = [ "out" "dev" "lib" ];

    postInstall = ''
      mkdir -p $dev/include/External
      moveToOutput lib/pkgconfig "''${!outputDev}"
      moveToOutput lib/cmake "''${!outputDev}"
    '';

    postFixup = ''
      substituteInPlace $out/lib/pkgconfig/*.pc \
        --replace '=''${prefix}//' '=/'
      substituteInPlace $dev/lib/pkgconfig/*.pc \
        --replace-fail '=''${prefix}//' '=/' \
        --replace-fail "includedir=$dev/$dev" "includedir=$dev"
      # add a symlink for backwards compatibility
      ln -s $out/bin/glslang $out/bin/glslangValidator
    '';
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/330112
  mesa = prev.mesa.overrideAttrs (f: p: {
    buildInputs = lib.remove glslang p.buildInputs;

    depsBuildBuild = p.depsBuildBuild or []
      ++ [ spirv-tools ];
  } // lib.optionalAttrs (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") {
    NIX_LDFLAGS = "--undefined-version";
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/330201
  tremor = prev.tremor.overrideAttrs (f: p: {
    configureFlags = lib.optional (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") "LDFLAGS=-Wl,--undefined-version";
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/330239
  libselinux = prev.libselinux.overrideAttrs (f: p: lib.optionalAttrs (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") {
    NIX_LDFLAGS = "--undefined-version";
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/330266
  graphite2 = prev.graphite2.overrideAttrs (f: p: {
    buildInputs = p.buildInputs or [] ++ [
      (llvmPackages.compiler-rt.override {
        doFakeLibgcc = true;
      })
    ];
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/330305
  makeBinaryWrapper = prev.makeBinaryWrapper.override {
    inherit (stdenv) cc;
  };

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pythonFinal: pythonPrev: {
      # PR: https://github.com/NixOS/nixpkgs/pull/330310
      mako = pythonPrev.mako.overrideAttrs (attrs: {
        disabledTests = attrs.disabledTests or []
          ++ lib.optional (stdenv.targetPlatform.useLLVM or false) "test_future_import";
      });

      # PR: https://github.com/NixOS/nixpkgs/pull/331869
      jedi = pythonPrev.jedi.overrideAttrs (attrs: {
        disabledTests = attrs.disabledTests or []
          ++ lib.optionals (stdenv.targetPlatform.useLLVM or false) [
            "test_create_environment_executable"
            "test_dict_keys_completions"
            "test_dict_completion"
          ];
      });
    })
  ];

  # PR: https://github.com/NixOS/nixpkgs/pull/330316
  libjack2 = prev.libjack2.overrideAttrs (f: p: {
    buildInputs = p.buildInputs or []
      ++ lib.optional (stdenv.targetPlatform.useLLVM or false)
        (runCommand "llvm-libstdcxx" {} ''
          mkdir -p $out/lib
          ln -s ${llvmPackages.libcxx}/lib/libc++.so $out/lib/libstdc++.so
          ln -s ${llvmPackages.libcxx}/lib/libc++.so.1 $out/lib/libstdc++.so.1
          ln -s ${llvmPackages.libcxx}/lib/libc++.so.1.0 $out/lib/libstdc++.so.1.0
        '');
  });

  cyrus_sasl = prev.cyrus_sasl.overrideAttrs (f: p: {
    configureFlags = p.configureFlags or []
      ++ lib.optional stdenv.cc.isClang "CFLAGS=-Wno-implicit-function-declaration";
  });

  glibcLocales = (prev.glibcLocales.override {
    stdenv = gccStdenv;
  }).overrideAttrs (f: p: {
    configureFlags = p.configureFlags or []
      ++ lib.optionals stdenv.cc.isClang [
        "--enable-kernel=3.10.0"
        "--with-headers=${linuxHeaders}/include"
      ];
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/331192
  elfutils = prev.elfutils.overrideAttrs (f: p: {
    patches = p.patches or []
      ++ [
        (fetchpatch {
          url = "https://github.com/NixOS/nixpkgs/raw/489a754dfeba20fab46ab075efa653ad464018b9/pkgs/development/tools/misc/elfutils/cxx-header-collision.patch";
          hash = "sha256-2RPFEj7ugkh5FURTunUHO+OaHAT7SR0QIEiCCLy4q/c=";
        })
      ];

    nativeBuildInputs = p.nativeBuildInputs or []
      ++ [ autoreconfHook ];
  });
}
