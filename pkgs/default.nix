lib: final: prev: with final;
{
  # PR: https://github.com/NixOS/nixpkgs/pull/330037
  wrapRustcWith = { rustc-unwrapped, ... } @ args: callPackage ./build-support/rust/rustc-wrapper args;

  switch-to-configuration-ng = prev.switch-to-configuration-ng.overrideAttrs (_: _: {
    doCheck = !(stdenv.hostPlatform.useLLVM or false);
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/329979
  nix = prev.nix.overrideAttrs (_: _: {
    doInstallCheck = !(stdenv.targetPlatform.useLLVM or false);
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

  alsa-lib = prev.alsa-lib.overrideAttrs (
    f: p: {
      patches = p.patches or [] ++ [
        (fetchurl {
          url = "https://github.com/alsa-project/alsa-lib/commit/76edab4e595bd5f3f4c636cccc8d7976d3c519d6.patch";
          hash = "sha256-WCOXfe0/PPZRMXdNa29Jn28S2r0PQ7iTsabsxZVSwnk=";
        })
      ];
    }
  );

  makeBinaryWrapper = prev.makeBinaryWrapper.override {
    inherit (stdenv) cc;
  };

  cjson = prev.cjson.overrideAttrs (
    _: _: {
      cmakeFlags = [
        "-DENABLE_CUSTOM_COMPILER_FLAGS=OFF"
      ];
    }
  );

  libtirpc = prev.libtirpc.overrideAttrs (_: _: {
    NIX_LDFLAGS = lib.optionalString (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") "--undefined-version";
  });

  libaom = prev.libaom.overrideAttrs (f: p: {
    cmakeFlags = p.cmakeFlags ++ lib.optional (stdenv.hostPlatform.useLLVM or false) "-DCMAKE_ASM_COMPILER=${lib.getBin stdenv.cc}/bin/${stdenv.cc.targetPrefix}cc";
  });

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pythonFinal: pythonPrev: {
      pyyaml = pythonPrev.pyyaml.overrideAttrs (attrs: {
        doInstallCheck = attrs.doInstallCheck && !(stdenv.hostPlatform.useLLVM or false);
      });

      pybind11 = pythonPrev.pybind11.overrideAttrs (attrs: {
        doInstallCheck = attrs.doInstallCheck && !(stdenv.hostPlatform.useLLVM or false);
      });

      pycparser = pythonPrev.pycparser.overrideAttrs (attrs: {
        preCheck = ''
          substituteInPlace examples/using_gcc_E_libc.py \
            --replace-fail "'gcc'" "'${stdenv.cc.targetPrefix}cc'"
        '';
      });

      cffi = pythonPrev.cffi.overrideAttrs (attrs: {
        doInstallCheck = !(stdenv.hostPlatform.isMusl || stdenv.hostPlatform.useLLVM or false);
      });
    })
  ];

  libjack2 = prev.libjack2.overrideAttrs (f: p: {
    postPatch = p.postPatch + lib.optionalString (stdenv.hostPlatform.useLLVM or false) ''
      sed -i 's/STDC++/C++/g' dbus/wscript
    '';
  });

  xwayland = prev.xwayland.override {
    withLibunwind = !(stdenv.hostPlatform.useLLVM or false);
  };

  flashrom = prev.flashrom.overrideAttrs (f: p: {
    NIX_CFLAGS_COMPILE = "-Wno-gnu-folding-constant";
  });

  rutabaga_gfx = prev.rutabaga_gfx.overrideAttrs (f: p: {
    postPatch = lib.optionalString stdenv.hostPlatform.useLLVM ''
      substituteInPlace rutabaga_gfx/build.rs \
        --replace-fail "cargo:rustc-link-lib=dylib=stdc++" "cargo:rustc-link-lib=dylib=c++"
    '';
  });

  polkit = prev.polkit.overrideAttrs (f: p: {
    env = p.env // {
      NIX_CFLAGS_COMPILE = "-Wno-error=implicit-function-declaration";
    };
  });

  keyutils = prev.keyutils.overrideAttrs (f: p: {
    NIX_LDFLAGS = lib.optionalString (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") "--undefined-version";
  });

  tcp_wrappers = prev.tcp_wrappers.overrideAttrs (f: p: {
    patches = p.patches ++ lib.optional (stdenv.cc.isClang) ./by-name/tc/tcp_wrappers/clang.diff;
  });

  tdb = prev.tdb.overrideAttrs (f: p: {
    NIX_LDFLAGS = lib.optionalString (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") "--undefined-version";
  });

  talloc = prev.talloc.overrideAttrs (f: p: {
    NIX_LDFLAGS = lib.optionalString (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") "--undefined-version";
  });

  screen = prev.screen.overrideAttrs (f: p: {
    doCheck = !stdenv.hostPlatform.useLLVM;
  });
}
