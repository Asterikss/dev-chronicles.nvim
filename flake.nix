{
  description = "Dev shell for running plugin tests";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
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
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            neovim-unwrapped
            luajitPackages.nlua
            luajitPackages.busted
          ];
          shellHook = ''
            [[ -f .env ]] && set -a && source .env && set +a
            echo "Ready. Run: busted tests"
            [[ $DEVSHELL_SHELL ]] && exec "$DEVSHELL_SHELL"
          '';
        };
      }
    );
}
