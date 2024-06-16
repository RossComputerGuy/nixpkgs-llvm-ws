# nixpkgs-llvm-ws

Flake workspace / repo to stage and track Nixpkgs/NixOS's ability to be compiled completely with LLVM

## Contributing

As Nixpkgs is a large repo, there are many packages. To not burden the load on just me (@RossComputerGuy)
or other contributors and maintainers, additional help is appreciated.

### 1. Finding build failures

The best way to find build failures is to use `nix build github:NixOS/nixpkgs#pkgsLLVM.*pkgname*` and
report a build failure to [Nixpkgs](https://github.com/NixOS/nixpkgs). Create an issue in this repository
with a link to the Nixpkgs issue and work will be done to reproduce and fix here and then upstreaming it.

### 2. Fixing build failures

The best way to fix is to create a PR to this repository for me (@RossComputerGuy) and other people to
look into and fix. Either one of the people involved with this project can upstream it or you can upstream it
yourself.

## Common Build Failures

### Version script causing `error: version script assignment of 'xxx' to symbol 'xx' failed: symbol not defined`

This usually happens when a library is linked with a version script, the usual solution is to implement something
like this:

```nix
# Fix undefined reference errors with version script under LLVM.
NIX_LDFLAGS = lib.optionalString (stdenv.cc.bintools.isLLVM && lib.versionAtLeast stdenv.cc.bintools.version "17") "--undefined-version";
```
