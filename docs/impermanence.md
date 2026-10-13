# Impermanence (ephemeral root)

`modules.impermanence.enable = true` wires `environment.persistence."<persistPath>"`.
It does **not** make `/` ephemeral by itself — that comes from the host's
filesystem layout (disko) plus a persistent volume.

The feature module is `modules/system/impermanence.nix`; it adds:

| option                          | default                            | meaning                                           |
| ------------------------------- | ---------------------------------- | ------------------------------------------------- |
| `modules.impermanence.enable`   | `false`                            | wire `environment.persistence`                    |
| `persistPath`                   | `"/persistent"`                    | mount point of the surviving volume               |
| `directories` / `files`         | small safe set                     | system paths bind-mounted/linked into persistence |
| `userDirectories` / `userFiles` | `.ssh`, `.gnupg`, keyrings, direnv | per-user paths                                    |

A host opts in and extends the lists.

## Layout for this repo (btrfs + LUKS via disko)

`modules/system/disko.nix` (`mkBtrfsLayout`) creates `/root`, `/home`, `/nix`,
`/swap` subvolumes. Two ways to make `/` ephemeral:

1. **Rotate the btrfs `/root` subvolume on every boot** (fits this layout, no
   repartition, keeps old roots for recovery). Add a `/persistent` subvolume and
   a `boot.initrd.postResumeCommands` that renames `/root` and recreates it
   empty. `/home` and `/nix` stay on disk, so only the OS root is wiped.
2. **tmpfs `/`** (simplest; `/` becomes RAM). Drawbacks: OOM/disk-full on large
   writes. `/home` and `/nix` remain real mounts.

Either way you need a mounted `/persistent` marked `neededForBoot = true`.

## Enable steps

1. Add a `/persistent` subvolume + root rotation (option 1) to the host's disko
   config, and set `fileSystems."/persistent".neededForBoot = true`.
2. Add the module to the host's import list and enable it. The option only
   exists once the module is imported (dendritic), so in the host's
   `nixosSystem { modules = [ ... ]; }` list add
   `config.nixconf.modules.nixos.impermanence`, then on the host set
   `modules.impermanence.enable = true;` and extend
   `directories` / `files` / `userDirectories` for that host.
3. Apply the filesystem change — re-image with disko
   (`--mode destroy,format,mount`) or create the `/persistent` subvolume +
   mounts by hand, then reboot.
4. Move current state into `/persistent` (e.g.
   `rsync -aHAX /var/log/ /persistent/var/log/`, etc.) before the first
   ephemeral boot, or impermanence creates empty dirs instead.
5. `sudo nixos-rebuild switch --flake $NIXCONF` (or `nur`).

## Must-persist (else things break after reboot)

- System: `/etc/machine-id`, `/var/lib/nixos` (uid/gid map), `/var/log`,
  `/etc/ssh` (host keys), NetworkManager connections, `/var/lib/bluetooth`.
- User: `~/.ssh`, `~/.gnupg`, `~/.local/share/keyrings`,
  `~/.local/share/direnv`, and **`~/.config/sops`** — the workstation's
  software age key (`~/.config/sops/age/keys.txt`) lives there and sops-nix
  decryption fails without it.
- The Nix store (`/nix`) is its own subvolume and persists; never persist `/`.
