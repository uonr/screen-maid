{
  description = "Toggle display output on USB connect/disconnect";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        pythonWithDeps = pkgs.python3.withPackages (ps: [ ps.pyudev ]);
        screen-maid = pkgs.writeShellApplication {
          name = "screen-maid";
          runtimeInputs = [ pythonWithDeps ];
          text = ''
            exec ${pythonWithDeps}/bin/python ${./screen-maid.py}
          '';
        };

        toggle-mirror = pkgs.stdenv.mkDerivation {
          name = "toggle-mirror";
          src = ./.;
          nativeBuildInputs = [ pkgs.swift ];
          buildPhase = ''
            swiftc toggle-mirror.swift -o toggle-mirror
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp toggle-mirror $out/bin/
          '';
        };

        screen-maid-swift = pkgs.stdenv.mkDerivation {
          name = "screen-maid-swift";
          src = ./.;
          nativeBuildInputs = [ pkgs.swift ];
          buildPhase = ''
            swiftc screen-maid.swift -o screen-maid-swift
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp screen-maid-swift $out/bin/
          '';
        };
      in
      {
        packages = {
          default = screen-maid;
          inherit screen-maid toggle-mirror screen-maid-swift;
        };

        apps.default = {
          type = "app";
          program = "${screen-maid}/bin/screen-maid";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pythonWithDeps
            pkgs.swift
          ];
        };
      }
    );
}
