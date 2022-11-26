
## Nix Workflow

<details><summary><b>NOTE</b> Assumes you're using "nix flakes"</summary>

You can add `nix-command flakes` to `experimental-features` in either `~/.config/nix/nix.conf` or `/etc/nix/nix.conf` (user-specific vs system-wide).

</details>

### :star2: Want an interactive shell? 

```sh
nix develop 
```

### :unamused: Want to just run single command (_plan_)? 
Simply run `nix develop -c <command>`. 

For instance:

```sh
nix develop -c terraform plan
```

### :smirk: Too lazy to type out `nix develop -c terraform plan`? 

We alias `tf` to `terraform`, so you can run `nix develop -c tf ...`. 

For example:

```sh
nix develop -c tf plan
```

### :astonished: Too lazy to type out `nix develop -c` when you're developing?

Try using an alias, like this one _(change $PWD as needed)_.

```sh
alias tf="nix develop $PWD -c tf"
```

:magic_wand: Now you can just type `tf plan` (from _other_ directories too!) 

### :construction: Need SSH?

```sh
# Adjust this command to find the node you need.
target_ip=$(tf output -json cluster | jq -Ser '.nodes[].ipv4_address' | head -n1)

# The root user should be pre-installed with developer SSH keys, so try something like:
ssh "root@${target_ip}"
```

