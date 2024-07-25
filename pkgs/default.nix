lib: final: prev:
{
  # PR: https://github.com/NixOS/nixpkgs/pull/320432
  rustc = prev.rustc.override {
    rustc-unwrapped = prev.rustc.unwrapped.overrideAttrs (f: p: {
      configureFlags = p.configureFlags
        ++ [ "--llvm-libunwind=system" ];

      NIX_LDFLAGS = [ "--push-state --as-needed -L${final.llvmPackages.libcxx}/lib -lc++ --pop-state" ];

      buildInputs = p.buildInputs
        ++ [ (final.runCommandLocal "libunwind-libgcc" {} ''
          mkdir -p $out/lib
          ln -s ${final.llvmPackages.libunwind}/lib/libunwind.so $out/lib/libgcc_s.so
          ln -s ${final.llvmPackages.libunwind}/lib/libunwind.so $out/lib/libgcc_s.so.1
        '') ];
    });
  };
}
