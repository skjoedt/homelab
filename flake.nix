{
  description = "Homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
        inherit system;
        config = {
            allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
            "terraform"
            ];
        };
        };
      in
      with pkgs;
      {
        devShells.default = mkShell {
          packages = [
            terraform
            git
            jq
            k9s
            kubectl
            kubernetes-helm
            kustomize
            pre-commit
            yamllint
            awscli
            shellcheck

            (python3.withPackages (p: with p; [
              kubernetes
            ]))
          ];
        };
      }
    );
}
