terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.2"
    }
  }
}

variable "nixos_version" {
  default = "22.05"
  type    = string
}

variable "node_name" {
  default = "nixlet"
  type    = string
}

variable "domain" {
  default = "polis.dev"
  type    = string
}

variable "region" {
  default = "nyc3"
  type    = string
}


variable "node_image" {
  default = "debian-11-x64"
  type    = string
}

variable "node_size" {
  default = "s-1vcpu-1gb-intel"
  type    = string
}

data "digitalocean_ssh_keys" "all" {
  sort {
    key       = "name"
    direction = "asc"
  }
}

data "digitalocean_vpc" "default" {
  name = "default-${var.region}"
}

data "cloudinit_config" "user_data" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "bootstrap.yml"
    content_type = "text/cloud-config"
    content = yamlencode({

      # Create nix install group
      groups = ["nixbld"]

      # Create nix install users
      users = [
        for id in range(0, 9) : {
          name          = "nixbld${id}"
          no_user_group = true
          system        = true
          gecos         = "Nix build user ${id}"
          primary_group = "nixbld"
          groups        = ["nixbld"]
        }
      ]

      # Write nixos files
      write_files = [{

        # System-wide nixos configuration
        path        = "/etc/nixos/system.nix"
        permissions = "0644"
        content     = file("system.nix")
        }, {

        # System-wide nix configuration
        path        = "/etc/nix/nix.conf"
        permissions = "0644"
        content     = <<-NIX_CONF
          experimental-features = nix-command flakes
          build-users-group = nixbld
          auto-optimise-store = true
          download-attempts = 3
          enforce-determinism = true
          eval-cache = true
          http-connections = 50
          log-lines = 30
          warn-dirty = false
          allowed-users = root
          trusted-users = root
        NIX_CONF
        }, {
        # NixOS Metadata Regeneration
        path        = "/root/bin/generate"
        permissions = "0700"
        content     = <<-NIXOS_METADATA_REGEN_SCRIPT
          #!/usr/bin/env bash
          IFS=$'\n'
          rootfsdev="$(df "/" --output=source | sed 1d)"
          rootfstype="$(df $rootfsdev --output=fstype | sed 1d)"
          esp=$(df "/boot/efi" --output=source | sed 1d)
          espfstype="$(df $esp --output=fstype | sed 1d)"
          eth0_mac=$(ifconfig eth0 | awk '/ether/{print $2}')
          eth1_mac=$(ifconfig eth1 | awk '/ether/{print $2}')
          test ! -r /etc/nixos/generated.toml || mv /etc/nixos/generated.toml /etc/nixos/generated.bkp.toml
          cat <<-__TOML_FILE_CONTENTS | tee /etc/nixos/generated.toml
          networking.hostName = "${var.node_name}"
          fileSystems."/".device = "$rootfsdev"
          fileSystems."/".fsType = "$rootfstype" 
          systemd.network.links."10-eth0".matchConfig.PermanentMACAddress = "$eth0_mac"
          systemd.network.links."10-eth0".linkConfig.Name = "eth0"
          systemd.network.links."10-eth1".matchConfig.PermanentMACAddress = "$eth1_mac"
          systemd.network.links."10-eth1".linkConfig.Name = "eth1"
          __TOML_FILE_CONTENTS
          NIXOS_METADATA_REGEN_SCRIPT
      }]

      # Final bootstrapping
      runcmd = [
        "/root/bin/generate",
        "curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | PROVIDER=digitalocean NIXOS_IMPORT=./system.nix NIX_CHANNEL=nixos-unstable bash 2>&1 | tee /tmp/infect.log",
      ]
    })
  }
}

resource "digitalocean_droplet" "main" {
  image             = var.node_image
  name              = var.node_name
  region            = var.region
  vpc_uuid          = data.digitalocean_vpc.default.id
  size              = var.node_size
  ipv6              = true
  monitoring        = false
  backups           = false
  droplet_agent     = false
  graceful_shutdown = false
  user_data         = data.cloudinit_config.user_data.rendered
  ssh_keys          = data.digitalocean_ssh_keys.all.ssh_keys.*.id
  lifecycle {
    ignore_changes = [ssh_keys, tags]
  }
}

output "droplet" {
  value = digitalocean_droplet.main
}

output "ssh_commands" {
  value = {
    cloudinit_v4 = try(format("ssh root@%s tail -fn500 /var/log/cloud-init-output.log", digitalocean_droplet.main.ipv4_address), "N/A")
    cloudinit_v6 = try(format("ssh root@%s tail -fn500 /var/log/cloud-init-output.log", digitalocean_droplet.main.ipv6_address), "N/A")
    ssh_v4       = try(format("ssh root@%s", digitalocean_droplet.main.ipv4_address), "N/A")
    ssh_v6       = try(format("ssh root@%s", digitalocean_droplet.main.ipv6_address), "N/A")
  }
}
