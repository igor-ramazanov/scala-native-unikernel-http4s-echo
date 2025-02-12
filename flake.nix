{
  inputs = {
    devshell = {
      url = "github:numtide/devshell";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };

    nixpkgs = {
      url = "github:NixOS/nixpkgs";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    systems.url = "github:nix-systems/default";

    typelevel-nix = {
      url = "github:typelevel/typelevel-nix";
      inputs = {
        devshell.follows = "devshell";
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = {
    devshell,
    flake-utils,
    nixpkgs,
    typelevel-nix,
    ...
  }:
    flake-utils.lib.eachSystem ["x86_64-linux"] (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [devshell.overlays.default];
      };
    in {
      formatter = pkgs.alejandra;

      devShell = pkgs.devshell.mkShell rec {
        name = "unikernel-scala";
        imports = [typelevel-nix.typelevelShell];

        packages = let
          static = pkgs.pkgsStatic;
        in [
          (pkgs.scalafix.override {jre = typelevelShell.jdk.package;})

          # I didn't succeed dynamically linking Scala Native with these packages,
          # hence using static variants.
          static.liburing.dev
          static.liburing.out
          static.openssl.dev
          static.openssl.out

          # For packaging as unikernel
          pkgs.ops

          # For running a unikernel image
          pkgs.qemu
        ];

        typelevelShell = {
          jdk.package = pkgs.graalvm-ce;

          native = {
            enable = true;
            libraries = [
              pkgs.zlib
            ];
          };

          nodejs.enable = false;
          sbtMicrosites.enable = false;
        };
      };
    });
}
