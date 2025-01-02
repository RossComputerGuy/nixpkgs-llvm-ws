lib: final: prev: with final;
{
  elfutils = prev.elfutils.overrideAttrs (f: p: {
    patches = lib.filter (e: !(lib.hasSuffix "cxx-header-collision.patch" e)) p.patches
      ++ lib.optional (stdenv.hostPlatform.useLLVM or false) (fetchurl {
        url = "https://github.com/NixOS/nixpkgs/raw/d2717272348966a6ec8344f04780a80622ce9bda/pkgs/by-name/el/elfutils/cxx-header-collision.patch";
        hash = "sha256-mldDyxjbhOsWfRZmeYKfCv5QlsmGuGYD7gJx30v9f0I=";
      });
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/330037
  wrapRustcWith = { rustc-unwrapped, ... } @ args: callPackage ./build-support/rust/rustc-wrapper args;

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

  makeBinaryWrapper = prev.makeBinaryWrapper.override {
    inherit (stdenv) cc;
  };
}
