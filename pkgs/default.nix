lib: final: prev:
{
  # PR: https://github.com/NixOS/nixpkgs/pull/319976
  libbsd = prev.libbsd.overrideAttrs (f: p: {
    NIX_LDFLAGS = lib.optionalString (final.stdenv.cc.bintools.isLLVM && lib.versionAtLeast final.stdenv.cc.bintools.version "17") "--undefined-version";
  });
}
