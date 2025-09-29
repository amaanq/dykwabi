{
  description = "BuckMaterialShell Command Line Interface";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zig2nix = {
      url = "github:Cloudef/zig2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      zig-overlay,
      zig2nix,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f:
        builtins.listToAttrs (
          map (system: {
            name = system;
            value = f system;
          }) supportedSystems
        );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          env = zig2nix.outputs.zig-env.${system} { };
        in
        {
          dykwabi = env.package {
            pname = "dykwabi";
            version = "0.1.0";
            src = ./.;

            zigBuildFlags = [
              "-Doptimize=ReleaseSmall"
            ];

            meta = {
              description = "BuckMaterialShell Command Line Interface";
              homepage = "https://github.com/amaanq/dykwabi";
              mainProgram = "dykwabi";
              license = pkgs.lib.licenses.mit;
              platforms = pkgs.lib.platforms.unix;
            };
          };

          default = self.packages.${system}.dykwabi;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          zig-version = "0.15.1";
          zig = zig-overlay.packages.${system}.${zig-version};
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = [
              zig
              pkgs.zls
            ];
          };
        }
      );
    };
}
