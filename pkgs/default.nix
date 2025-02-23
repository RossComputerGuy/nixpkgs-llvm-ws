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
    doInstallCheck = !(stdenv.hostPlatform.useLLVM or false);
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
        ++ lib.optional (stdenv.cc.isClang && stdenv.hostPlatform.parsed.cpu.family == "arm") "zerocallusedregs";
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

      # PR: https://github.com/NixOS/nixpkgs/pull/384147
      eventlet = pythonPrev.eventlet.overrideAttrs (attrs: {
        disabledTests = attrs.disabledTests ++ [
          "test_send_timeout"
        ];
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

  keyutils = prev.keyutils.overrideAttrs (f: p: {
    NIX_LDFLAGS = lib.optionalString (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") "--undefined-version";
  });

  tcp_wrappers = prev.tcp_wrappers.overrideAttrs (f: p: {
    patches = p.patches ++ lib.optional (stdenv.cc.isClang) ./by-name/tc/tcp_wrappers/clang.diff;
  });

  tdb = prev.tdb.overrideAttrs {
    NIX_LDFLAGS = lib.optionalString (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") "--undefined-version";
  };

  talloc = prev.talloc.overrideAttrs {
    NIX_LDFLAGS = lib.optionalString (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") "--undefined-version";
  };

  screen = prev.screen.overrideAttrs {
    doCheck = !stdenv.hostPlatform.useLLVM;
  };

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

  ffmpeg = prev.ffmpeg.overrideAttrs (f: p: {
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

  cryptsetup = prev.cryptsetup.overrideAttrs {
    doCheck = false;
  };

  soundtouch = prev.soundtouch.overrideAttrs (f: p: {
    patches = p.patches or []
      ++ lib.optional (stdenv.hostPlatform.useLLVM) ./soundtouch.patch;
  });

  libpulseaudio = prev.libpulseaudio.overrideAttrs (f: p: {
    NIX_LDFLAGS = lib.optionalString (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") "--undefined-version";
  });

  roc-toolkit = prev.roc-toolkit.override {
    libunwindSupport = !stdenv.hostPlatform.useLLVM;
  };

  directfb = prev.directfb.override {
    # TODO: do better
    stdenv = gccStdenv;
  };

  libdc1394 = prev.libdc1394.override {
    # TODO: do better
    stdenv = gccStdenv;
  };

  flite = prev.flite.override {
    stdenv = gccStdenv;
  };

  libopenmpt = prev.libopenmpt.overrideAttrs {
    doCheck = !stdenv.hostPlatform.useLLVM;
  };

  tinysparql = prev.tinysparql.overrideAttrs {
    doCheck = !stdenv.hostPlatform.useLLVM;
  };

  librsvg = prev.librsvg.overrideAttrs {
    doCheck = !stdenv.hostPlatform.useLLVM;
  };

  slang = prev.slang.overrideAttrs (f: p: {
    NIX_LDFLAGS = lib.optionalString (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") "--undefined-version";
  });

  util-linux = prev.util-linux.overrideAttrs (f: p: {
    configureFlags = p.configureFlags
      ++ lib.optional (stdenv.hostPlatform.useLLVM) "LDFLAGS=-Wl,--undefined-version";
  });
}
