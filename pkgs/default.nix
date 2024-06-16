lib: final: prev:
{
  # PR: https://github.com/NixOS/nixpkgs/pull/319976
  libbsd = prev.libbsd.overrideAttrs (f: p: {
    NIX_LDFLAGS = lib.optionalString (final.stdenv.cc.bintools.isLLVM && lib.versionAtLeast final.stdenv.cc.bintools.version "17") "--undefined-version";
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/304753
  inherit (prev.callPackages ./os-specific/linux/apparmor {})
    libapparmor apparmor-utils apparmor-bin-utils apparmor-parser apparmor-pam
    apparmor-profiles apparmor-kernel-patches apparmorRulesFromClosure;

  # PR: https://github.com/NixOS/nixpkgs/pull/317942
  kexec-tools = (prev.kexec-tools.override { inherit (final) stdenv; }).overrideAttrs (f: p: {
    patches = p.patches ++ [
      (prev.fetchpatch {
        name = "fix-purgatory-llvm-libunwind.patch";
        url = "https://raw.githubusercontent.com/NixOS/nixpkgs/de926d60457c7b455f53605d3f38f6dd28333cb0/pkgs/os-specific/linux/kexec-tools/fix-purgatory-llvm-libunwind.patch";
        hash = "sha256-iSVHmHNWDjBRKVOzCpJhZfIqs6E+ERhCVGQqxR/cAKo=";
      })
    ];
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/320187
  db4 = prev.db4.overrideAttrs (f: p: {
    configureFlags = p.configureFlags ++ [ "--with-mutex=POSIX/pthreads" ];
  });

  # PR: https://github.com/NixOS/nixpkgs/pull/320199
  libgcrypt = prev.libgcrypt.overrideAttrs (f: p: {
    configureFlags = p.configureFlags
      ++ lib.optional (final.stdenv.cc.bintools.isLLVM && lib.versionAtLeast final.stdenv.cc.bintools.version "17") "LDFLAGS=-Wl,--undefined-version";
  });
}
