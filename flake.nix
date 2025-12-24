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
      in
      {
        packages.default = screen-maid;

        apps.default = {
          type = "app";
          program = "${screen-maid}/bin/screen-maid";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pythonWithDeps
          ];
        };
      }
    );
}
