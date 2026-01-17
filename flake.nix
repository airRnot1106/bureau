{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nur-packages = {
      url = "github:airRnot1106/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [ inputs.nur-packages.overlays.default ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
          packages = with pkgs; [
            cspell
            gitleaks
            lychee
            markdownlint-cli2
            nixd
            oxfmt
            textlint
            textlint-filter-rule-comments
            textlint-rule-preset-ai-writing
            textlint-rule-preset-ja-spacing
            textlint-rule-preset-ja-technical-writing
            textlint-rule-terminology
          ];
        };
        formatter = inputs.treefmt-nix.lib.mkWrapper pkgs {
          projectRootFile = "flake.nix";
          programs = {
            nixfmt.enable = true;
            oxfmt.enable = true;
          };
        };
        checks =
          let
            articleFiles = "^articles/.*\\.md$";
          in
          {
            pre-commit-check = inputs.git-hooks.lib.${system}.run {
              src = ./.;
              hooks = {
                cspell = {
                  enable = true;
                  files = articleFiles;
                };
                gitleaks = {
                  enable = true;
                  entry = "${pkgs.lib.getExe' pkgs.gitleaks "gitleaks"} dir --verbose";
                  package = pkgs.gitleaks;
                };
                lychee.enable = true;
                markdownlint = {
                  enable = true;
                  entry = "${pkgs.lib.getExe' pkgs.markdownlint-cli2 "markdownlint-cli2"}";
                  files = articleFiles;
                  package = pkgs.markdownlint-cli2;
                };
                textlint =
                  let
                    textlintWithDeps = pkgs.textlint.withPackages (
                      with pkgs;
                      [
                        textlint-filter-rule-comments
                        textlint-rule-preset-ai-writing
                        textlint-rule-preset-ja-spacing
                        textlint-rule-preset-ja-technical-writing
                        textlint-rule-terminology
                      ]
                    );
                  in
                  {
                    enable = true;
                    entry = "${textlintWithDeps}/bin/textlint";
                    files = articleFiles;
                    package = textlintWithDeps;
                  };
                treefmt = {
                  enable = true;
                  package = self.formatter.${system};
                };
              };
            };
          };
      }
    );
}
