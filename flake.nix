{
  description = "Flake to build zen browser from source";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      perSystem =
        let
          version = "1.17.4b";
          firefoxVersion = "144.0.2";
        in
        {
          pkgs,
          ...
        }:
        {
          packages = rec {
            zen-browser-unwrapped = pkgs.callPackage ./zen-browser-unwrapped.nix {
              inherit version firefoxVersion;
            };
            zen-browser = builtins.warn ''
              This flake is deprecated, please use https://github.com/youwen5/zen-browser-flake.
            '' (pkgs.callPackage ./zen-browser.nix { inherit zen-browser-unwrapped; });
            default = zen-browser;
          };
        };
    };
}
