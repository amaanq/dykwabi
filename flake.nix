{
  description = "Dykwabi - Do you know what a buck is";

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
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      inherit (inputs) self;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      eachSystem = lib.genAttrs systems;
      pkgsFor = inputs.nixpkgs.legacyPackages;
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = pkgsFor.${system};
          env = inputs.zig2nix.outputs.zig-env.${system} { };
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
              description = "Dykwabi - Do you know what a buck is";
              homepage = "https://github.com/amaanq/dykwabi";
              mainProgram = "dykwabi";
              license = pkgs.lib.licenses.mit;
              platforms = pkgs.lib.platforms.unix;
            };
          };

          default = self.packages.${system}.dykwabi;
        }
      );

      devShells = eachSystem (
        system:
        let
          pkgs = pkgsFor.${system};
          zig-version = "0.15.1";
          zig = inputs.zig-overlay.packages.${system}.${zig-version};
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
