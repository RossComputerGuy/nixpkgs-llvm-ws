{ lib, buildPackages, callPackage, callPackages, cargo-auditable, stdenv, runCommand, pkgs }@prev:

{ rustc
, cargo
, cargo-auditable ? prev.cargo-auditable
, stdenv ? prev.stdenv
, ...
}:

rec {
  rust = {
    rustc = lib.warn "rustPlatform.rust.rustc is deprecated. Use rustc instead." rustc;
    cargo = lib.warn "rustPlatform.rust.cargo is deprecated. Use cargo instead." cargo;
  };

  fetchCargoTarball = buildPackages.callPackage "${pkgs.path}/pkgs/build-support/rust/fetch-cargo-tarball" {
    git = buildPackages.gitMinimal;
    inherit cargo;
  };

  buildRustPackage = callPackage "${pkgs.path}/pkgs/build-support/rust/build-rust-package" {
    inherit stdenv cargoBuildHook cargoCheckHook cargoInstallHook cargoNextestHook cargoSetupHook
      fetchCargoTarball importCargoLock rustc cargo cargo-auditable;
  };

  importCargoLock = buildPackages.callPackage "${pkgs.path}/pkgs/build-support/rust/import-cargo-lock.nix" { inherit cargo; };

  rustcSrc = callPackage ./rust-src.nix {
    inherit runCommand rustc;
  };

  rustLibSrc = callPackage ./rust-lib-src.nix {
    inherit runCommand rustc;
  };

  # Hooks
  inherit (callPackages "${pkgs.path}/pkgs/build-support/rust/hooks" {
    inherit stdenv cargo rustc;
  }) cargoBuildHook cargoCheckHook cargoInstallHook cargoNextestHook cargoSetupHook maturinBuildHook bindgenHook;
}
