{ pkgs, inputs, ... }:

{
  env.GREET = "devenv";

  packages = with pkgs; [
    zsh
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
  ];

  languages.python.enable = true;
  languages.python.version = "3.11.3";
}
