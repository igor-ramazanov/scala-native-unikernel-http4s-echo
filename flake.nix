{
  inputs = {
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:NixOS/nixpkgs";

    sbt-derivation = {
      url = "github:zaninime/sbt-derivation";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = {
    devshell,
    flake-utils,
    nixpkgs,
    sbt-derivation,
    self,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;

        overlays = [
          devshell.overlays.default
          sbt-derivation.overlays.default

          # Reusing the same JDK for all tools
          (final: prev: let
            jre = prev.graalvm-ce;
          in {
            bloop = prev.bloop.override {inherit jre;};
            coursier = prev.coursier.override {inherit jre;};
            metals = prev.metals.override {inherit jre;};
            sbt = prev.sbt.override {inherit jre;};
            scala-cli = prev.scala-cli.override {inherit jre;};
            scalafix = prev.scalafix.override {inherit jre;};
            scalafmt = prev.scalafmt.override {inherit jre;};
          })
        ];
      };

      # Utility imports
      inherit
        (pkgs.lib)
        attrsToList
        concatStringsSep
        getDev
        getLib
        map
        readFile
        ;

      pname = "unikernel-scala";

      # Reading from file to synchronize with sbt to avoid double-hardcoding
      # TODO: Use https://github.com/sbt/sbt-git
      version = readFile ./version;

      llvm = pkgs.llvmPackages_19;

      scalaTools = [
        pkgs.bloop
        pkgs.coursier
        pkgs.metals
        pkgs.sbt
        pkgs.scala-cli
        pkgs.scalafix
        pkgs.scalafmt
      ];

      unikernelDevTools = [
        # For packaging as unikernel
        pkgs.ops
        # For running a unikernel image
        pkgs.qemu
      ];

      # Native libraries for linking with the Scala Native app
      nativeLibraries = [
        pkgs.liburing
        pkgs.openssl
        pkgs.zlib
      ];

      # Environment variables expected and parsed by Scala Native sbt plugin:
      # https://github.com/scala-native/scala-native/blob/691cf35751de7edf9dc7d183dd87a83b23558360/tools/src/main/scala/scala/scalanative/build/Discover.scala#L14
      scalaNativeEnvVars = {
        # A path to the `/bin` dir of `clang` installation
        LLVM_BIN = "${llvm.clang}/bin";

        # NanoVM didn't work with `immix`
        SCALANATIVE_GC = "commix";

        # `:`-joined `/include/` dirs for each native library
        SCALANATIVE_INCLUDE_DIRS = concatStringsSep ":" (
          map (dep: "${getDev dep}/include") nativeLibraries
        );

        # `:`-joined `/lib/` dirs for each native library
        SCALANATIVE_LIB_DIRS = concatStringsSep ":" (
          map (dep: "${getLib dep}/lib") nativeLibraries
        );

        # NanoVM didn't work with `thin`
        SCALANATIVE_LTO = "full";

        # The most convenient mode, `release-full` is slow, but doesn't give much advantage
        SCALANATIVE_MODE = "release-fast";

        # No idea what is this, but sounds nice to have
        SCALANATIVE_OPTIMIZE = "true";
      };

      server =
        sbt-derivation.mkSbtDerivation.${system}.withOverrides {
          # Using `clang` instead of default `gcc`
          inherit (llvm) stdenv;
        } (
          scalaNativeEnvVars
          // {
            inherit pname version;
            # Needed by Scala Native sbt plugin:
            # https://github.com/scala-native/scala-native/blob/691cf35751de7edf9dc7d183dd87a83b23558360/tools/src/main/scala/scala/scalanative/build/Discover.scala#L204
            nativeBuildInputs = [pkgs.which];
            src = self;
            depsSha256 = "sha256-zkW+XX/uWGlnMh4swDy7FQlntQ14PL51C6P0IfCGjXY=";
            buildPhase = ''
              sbt nativeLink
            '';
            installPhase = ''
              mkdir -p $out/bin
              # Synchronize with sbt
              SCALA_VERSION="$(sbt --color=never --supershell=never scalaVersion | tail -n 1 | cut -d' ' -f2)"
              cp "./target/scala-$SCALA_VERSION/${pname}-out" $out/bin/${pname}
            '';
          }
        );

      # TODO: Broken at the moment, see: https://github.com/nanovms/ops/issues/1687
      qemu = pkgs.callPackage (pkgs.stdenv.mkDerivation {
        inherit version;
        pname = "${pname}-qemu";
        dontUnpack = true;
        dontPatch = true;
        dontConfigure = true;
        dontFixup = true;
        nativeBuildInputs = unikernelDevTools;
        buildPhase = ''
          ops build ${server}/bin/${pname}
        '';
        installPhase = ''
          mkdir -p $out/share
          cp $HOME/.ops/images/${pname}.img $out/share/
        '';
      }) {};
    in {
      formatter = pkgs.alejandra;

      devShell = pkgs.devshell.mkShell {
        name = pname;
        packages = scalaTools ++ unikernelDevTools ++ nativeLibraries;
        env = attrsToList scalaNativeEnvVars;
      };

      packages = {
        inherit server qemu;
        default = server;
      };
    });
}
