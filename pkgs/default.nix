lib: final: prev: with final;
let
  ubootPkgs = callPackage "${final.path}/pkgs/misc/uboot/default.nix" {
    stdenv = gccStdenv.override {
      cc = gccStdenv.cc.override {
        bintools = binutils;
      };
    };
  };
in
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
            hash = "sha256-yparoV/1aGf8U7xzou48s6y6mZKbj0YFhn6QOrPOHFg=";
          });

      hardeningDisable = p.hardeningDisable or []
        ++ lib.optional (stdenv.cc.isClang && stdenv.targetPlatform.parsed.cpu.family == "arm") "zerocallusedregs";
    });
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

  ubootRaspberryPi3_64bit = ubootPkgs.ubootRaspberryPi3_64bit.overrideAttrs (f: p: {
    depsBuildBuild = [
      (buildPackages.gccStdenv.cc.override {
        bintools = buildPackages.binutils;
        inherit (buildPackages.binutils) libc;
      })
    ];
  });

  ubootRaspberryPi4_64bit = ubootPkgs.ubootRaspberryPi4_64bit.overrideAttrs (f: p: {
    depsBuildBuild = [
      (buildPackages.gccStdenv.cc.override {
        bintools = buildPackages.binutils;
        inherit (buildPackages.binutils) libc;
      })
    ];
  });

  gperftools = prev.gperftools.override {
    stdenv = gccStdenv;
  };

  ffmpeg = (prev.ffmpeg.override {
    # Disable due to gfortran not building
    withSdl2 = false;
    withSpeex = false;
    withPulse = false;
    withOpenmpt = false;
  }).overrideAttrs (f: p: {
    configureFlags = p.configureFlags
      ++ lib.optionals (stdenv.cc.isClang) [
        "--cc=${stdenv.cc.targetPrefix}clang"
        "--cxx=${stdenv.cc.targetPrefix}clang++"
      ];

    doCheck = p.doCheck && !stdenv.hostPlatform.useLLVM;
  });

  libgudev = prev.libgudev.overrideAttrs (f: p: {
    # umockdev fails to build
    doCheck = !stdenv.hostPlatform.useLLVM;

    # Same as https://gitlab.gnome.org/GNOME/libgudev/-/merge_requests/30 but MR has conflict.
    postPatch = lib.optionalString stdenv.hostPlatform.useLLVM ''
      substituteInPlace gudev/meson.build \
        --replace-fail "-export-dynamic" "-Wl,--export-dynamic"
    '';
  });

  bind = prev.bind.override {
    jemalloc = null;
  };

  xdg-utils = runCommand prev.xdg-utils.name {} "mkdir -p $out";
}
