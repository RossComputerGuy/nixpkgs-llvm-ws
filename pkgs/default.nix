lib: final: prev: with final;
{
  # PR: https://github.com/NixOS/nixpkgs/pull/330037
  wrapRustcWith = { rustc-unwrapped, ... } @ args: callPackage ./build-support/rust/rustc-wrapper args;

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
    outputs = [ "bin" "out" "dev" ];

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
      ln -s $bin/bin/glslang $bin/bin/glslangValidator
    '';
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/330112
  mesa = prev.mesa.overrideAttrs (f: p: {
    nativeBuildInputs = (lib.remove glslang p.nativeBuildInputs)
      ++ [ glslang.bin ];
    buildInputs = (lib.remove glslang p.buildInputs)
      ++ [ spirv-tools ];
  });

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pythonFinal: pythonPrev: {
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

  # PR: https://github.com/NixOS/nixpkgs/pull/334780
  cyrus_sasl = prev.cyrus_sasl.overrideAttrs (f: p: {
    configureFlags = p.configureFlags or []
      ++ lib.optionals (stdenv.targetPlatform.useLLVM or false) [
        "--disable-sample"
        "CFLAGS=-DTIME_WITH_SYS_TIME"
      ];
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/332167
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

  makeBinaryWrapper = prev.makeBinaryWrapper.override {
    inherit (stdenv) cc;
  };
}
