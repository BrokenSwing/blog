{
  description = "Hugo blog development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            hugo
          ];

          shellHook = ''
            echo "Hugo blog development environment"
            echo "Hugo version: $(hugo version)"
            echo ""
            echo "Commands:"
            echo "  hugo server -D    # Start dev server (includes drafts)"
            echo "  hugo              # Build the site"
          '';
        };
      }
    );
}
