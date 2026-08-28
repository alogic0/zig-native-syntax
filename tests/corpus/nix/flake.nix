{
  description = "Viewer package";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      dynamicName = "viewer";
    in {
      packages.${system}.default = pkgs.callPackage ./package.nix { };
      nixosModules."${dynamicName}" = { config, lib, ... }: {
        options.services.${dynamicName}.enable = lib.mkEnableOption "viewer";
        config = lib.mkIf config.services.${dynamicName}.enable {
          environment.systemPackages = [ pkgs.viewer ];
        };
      };
      inherit (inputs) nixpkgs;
      source = <nixpkgs>;
      homepage = https://example.org/viewer;
      escaped = ''literal ''${notInterpolation} ${system}'';
    };
}
