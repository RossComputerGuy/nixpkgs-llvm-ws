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
}
