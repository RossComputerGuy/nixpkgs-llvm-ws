{
  lib,
  runCommand,
  rustc-unwrapped,
  sysroot ? null,
}:

runCommand "${rustc-unwrapped.pname}-wrapper-${rustc-unwrapped.version}"
  {
    preferLocalBuild = true;
    strictDeps = true;
    inherit (rustc-unwrapped) outputs;

    env = {
      sysroot = lib.optionalString (sysroot != null) "--sysroot ${sysroot}";

      # Upstream rustc still assumes that musl = static[1].  The fix for
      # this is to disable crt-static by default for non-static musl
      # targets.
      #
      # Even though Cargo will build build.rs files for the build platform,
      # cross-compiling _from_ musl appears to work fine, so we only need
      # to do this when rustc's target platform is dynamically linked musl.
      #
      # [1]: https://github.com/rust-lang/compiler-team/issues/422
      #
      # WARNING: using defaultArgs is dangerous, as it will apply to all
      # targets used by this compiler (host and target).  This means
      # that it can't be used to set arguments that should only be
      # applied to the target.  It's fine to do this for -crt-static,
      # because rustc does not support +crt-static host platforms
      # anyway.
      defaultArgs = lib.optionalString (
        with rustc-unwrapped.stdenv.targetPlatform; isMusl && !isStatic
      ) "-C target-feature=-crt-static";

      ldflags =
        lib.optionalString (rustc-unwrapped.stdenv.targetPlatform.useLLVM or false)
          "-rpath ${rustc-unwrapped.llvmPackages.libunwind}/lib -L ${
            runCommand "libunwind-libgcc" { } ''
              mkdir -p $out/lib
              ln -s ${rustc-unwrapped.llvmPackages.libunwind}/lib/libunwind.so $out/lib/libgcc_s.so
              ln -s ${rustc-unwrapped.llvmPackages.libunwind}/lib/libunwind.so $out/lib/libgcc_s.so.1
            ''
          }/lib";
    };

    passthru = {
      inherit (rustc-unwrapped)
        pname
        version
        src
        llvm
        llvmPackages
        tier1TargetPlatforms
        targetPlatforms
        badTargetPlatforms
        ;
      unwrapped = rustc-unwrapped;
    };

    meta = rustc-unwrapped.meta // {
      description = "${rustc-unwrapped.meta.description} (wrapper script)";
      priority = 10;
    };
  }
  ''
    mkdir -p $out/bin
    ln -s ${rustc-unwrapped}/bin/* $out/bin
    rm $out/bin/{rustc,rustdoc}
    prog=${rustc-unwrapped}/bin/rustc extraFlagsVar=NIX_RUSTFLAGS \
        substituteAll ${./rustc-wrapper.sh} $out/bin/rustc \
          --subst-var ldflags
    prog=${rustc-unwrapped}/bin/rustdoc extraFlagsVar=NIX_RUSTDOCFLAGS \
        substituteAll ${./rustc-wrapper.sh} $out/bin/rustdoc \
          --subst-var ldflags
    chmod +x $out/bin/{rustc,rustdoc}
    ${lib.concatMapStrings (output: "ln -s ${rustc-unwrapped.${output}} \$${output}\n") (
      lib.remove "out" rustc-unwrapped.outputs
    )}
  ''
