{
  description = "fnctl/infra";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/22.05";
  inputs.fnctl = {
    url = "github:fnctl/fnctl.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = {
    self,
    fnctl,
    nixpkgs,
  }:
    with fnctl.lib; {
      inherit (fnctl.outputs) formatter;
      devShells = eachSystemMap (system:
        with (pkgsForSystem' system); {
          default = mkShell {
            shellHook = ''
              test -e .envrc || cp .envrc.example .envrc; source .envrc
              test -e terraform.tfvars || cp terraform.tfvars.example terraform.tfvars
              export TF_AUTO_APPLY=1
              export TF_INPUT=0
              export TF_CLI_ARGS_apply="-refresh=false -input=false -auto-approve"
              export TF_CLI_ARGS_plan="-refresh=false"
            '';
            buildInputs = [
              jq
              bat
              (writeShellScriptBin "tf" "exec terraform \"$@\"")
              (writeShellScriptBin "show" "exec terraform show -no-color \"$@\" | bat --file-name='terraform show' -nl=hcl")
              (writeShellScriptBin "list-providers" "echo ${lib.concatStringsSep " " (builtins.attrNames terraform-providers)}")
              (terraform.withPlugins (p:
                with p; let
                  officialPlugins = [archive template external http random dns null local time tls cloudinit];
                  vendorPlugins = [
                    digitalocean
                    cloudflare
                    # github
                    # vault
                  ];
                in
                  officialPlugins ++ vendorPlugins))
            ];
          };
        });
    };
}
