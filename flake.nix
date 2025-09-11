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

  outputs =
    {
      devshell,
      flake-utils,
      nixpkgs,
      sbt-derivation,
      self,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;

          overlays = [
            devshell.overlays.default
            sbt-derivation.overlays.default

            # Reusing the same JDK for all tools
            (
              final: prev:
              let
                jre = prev.graalvm-ce;
              in
              {
                bloop = prev.bloop.override { inherit jre; };
                coursier = prev.coursier.override { inherit jre; };
                metals = prev.metals.override { inherit jre; };
                sbt = prev.sbt.override { inherit jre; };
                scala-cli = prev.scala-cli.override { inherit jre; };
                scalafix = prev.scalafix.override { inherit jre; };
                scalafmt = prev.scalafmt.override { inherit jre; };
              }
            )
          ];
        };

        # Utility imports
        inherit (pkgs.lib)
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

        # Using `musl` variant, so `clang` supports linking against `musl`.
        #
        # TODO: Not sure if necessary.
        # I think it should be possible to use `clang-unwrapped` and provide necessary libraries manually.
        # Compiling `clang` takes a lot of time.
        llvm = pkgs.pkgsMusl.llvmPackages_20;

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
          # `musl`/`clang` variant of C++ standard library.
          llvm.libcxx

          # Required by Scala Native
          pkgs.pkgsStatic.zlib

          # Uncomment if needed for fs2 / http4s
          pkgs.pkgsStatic.liburing
          pkgs.pkgsStatic.openssl
          pkgs.pkgsStatic.s2n-tls
        ];

        scalaNativeEnvVars = {
          # A path to the `/bin` dir of `clang` installation
          LLVM_BIN = "${llvm.clang}/bin";

          # `:`-joined `/include/` dirs for each native library
          C_INCLUDE_PATH = concatStringsSep ":" (map (dep: "${getDev dep}/include") nativeLibraries);

          # `:`-joined `/lib/` dirs for each native library
          LIBRARY_PATH = concatStringsSep ":" (map (dep: "${getLib dep}/lib") nativeLibraries);
        };

        server =
          sbt-derivation.mkSbtDerivation.${system}.withOverrides
            {
              # Using `clang` instead of default `gcc`
              inherit (llvm) stdenv;
            }
            (
              scalaNativeEnvVars
              // {
                inherit pname version;
                # Needed by Scala Native sbt plugin:
                # https://github.com/scala-native/scala-native/blob/691cf35751de7edf9dc7d183dd87a83b23558360/tools/src/main/scala/scala/scalanative/build/Discover.scala#L204
                nativeBuildInputs = [ pkgs.which ];
                src = self;
                depsSha256 = "sha256-2zn9YZbfZLTqtoSsf0gI+VLoPwBBZabP98LXscOemyk=";
                buildPhase = ''
                  sbt nativeLink
                '';
                installPhase = ''
                  mkdir -p $out/bin
                  # Synchronize with sbt
                  SCALA_VERSION="$(sbt --color=never --supershell=never scalaVersion | tail -n 1 | cut -d' ' -f2)"
                  cp "./target/scala-$SCALA_VERSION/${pname}" $out/bin/${pname}
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
        }) { };
      in
      {
        formatter = pkgs.nixfmt-rfc-style;

        devShell = pkgs.devshell.mkShell {
          name = pname;
          packages = scalaTools ++ unikernelDevTools ++ nativeLibraries;
          env = (attrsToList scalaNativeEnvVars);
        };

        packages = {
          inherit server qemu;
          default = server;
          docker = pkgs.dockerTools.buildImage {
            name = "unikernel-scala";
            config = {
              Cmd = [ "${server}/bin/${pname}" ];
            };
          };
        };
      }
    );
}
