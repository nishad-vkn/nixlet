{
  modulesPath,
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  packages = with pkgs; {
    admin-only = [
      bpftools
      dmidecode
      dnsutils
      hddtemp
      ipmitool
      lsof
      lynis
      mtr
      pciutils
      sysstat
      usbutils
      whois
      wireguard-tools
    ];
    global = [
      actionlint
      alejandra
      bat
      delta
      dogdns
      gh
      jq
      killall
      lsb-release
      lsd
      navi
      nerdctl
      pinentry
      pstree
      psutils
      ripgrep
      shellcheck
      skim
      skopeo
      tree
      vim
      zoxide
    ];
  };
in {
  imports = ["${modulesPath}/profiles/qemu-guest.nix"];
  boot.kernelModules = ["nvme"];
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
  environment.shellAliases.ga = "git add";
  environment.shellAliases.gb = "git branch";
  environment.shellAliases.gci = "git commit";
  environment.shellAliases.gco = "git checkout";
  environment.shellAliases.gd = "git diff";
  environment.shellAliases.gf = "git fetch";
  environment.shellAliases.gl = "git log";
  environment.shellAliases.grb = "git rebase";
  environment.shellAliases.grm = "git rm";
  environment.shellAliases.gs = "git status -sb";
  environment.shellAliases.gsw = "git switch";
  environment.shellAliases.ls = "lsd";
  environment.shellAliases.nixos-repl = "nix repl '<nixpkgs/nixos>'";
  environment.systemPackages = packages.global;
  environment.variables.EDITOR = "vim";
  environment.variables.PAGER = "bat";
  networking.interfaces.eth0.useDHCP = true;
  networking.interfaces.eth1.useDHCP = true;
  networking.nameservers = ["8.8.8.8" "8.8.4.4"];
  users.users.root.packages = packages.admin-only;
  networking.usePredictableInterfaceNames = lib.mkForce false;
  nix.settings.enforce-determinism = true;
  nix.settings.experimental-features = ["flakes" "nix-command"];
  services.do-agent.enable = true;
  services.openssh.enable = true;
}
