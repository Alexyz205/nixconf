# Tailscale (remote access plane)

Tailscale is a WireGuard-based mesh between devices you own. It is **not** the
public entry point (that stays Cloudflare Tunnel) and **not** the privacy
egress (that is Mullvad on the workstation). Its job here is one thing: give
your phone and laptop a private path to `192.168.1.0/24` without opening a port
on the router.

## Topology

```text
phone / laptop (4G, 5G, cafe wifi)
   |  WireGuard, direct peer-to-peer or via DERP relay
   v
backup-nas (subnet router, advertises 192.168.1.0/24)
   |
   +-- 192.168.1.110:8006   Proxmox
   +-- 192.168.1.120:6443   Talos VIP (kubectl) / :50000 (talosctl)
   +-- 192.168.1.192        Traefik -> every *.alexyz.org Ingress
   +-- 192.168.1.253:53     PiHole
   +-- 192.168.1.101/.102   GitLab VM, monitoring
   +-- 192.168.1.113        the NAS itself (SSH, NFS, restic)
```

The router is the NAS on purpose: it is wired, UPS-backed, always on, and
**outside** the Talos cluster. A VPN gateway that lives inside the cluster
cannot help when the cluster is what needs fixing.

## Enabling it on a host

The feature module is auto-discovered by `import-tree`; add it to the host and
switch the flag:

```nix
modules = [
  config.nixconf.modules.nixos.tailscale
];

# in the host's config
modules.tailscale = {
  enable = true;
  advertiseRoutes = [ "192.168.1.0/24" ]; # subnet router
};
```

Options (`modules.tailscale.*`):

| Option            | Default | Meaning                                                                  |
| ----------------- | ------- | ------------------------------------------------------------------------ |
| `advertiseRoutes` | `[]`    | Non-empty makes the host a subnet router (IP forwarding on).             |
| `acceptRoutes`    | `false` | Client side: use routes advertised by other tailnet nodes.               |
| `acceptDns`       | `false` | Let Tailscale rewrite this host's DNS. Kept off so resolvers stay local. |
| `ssh`             | `false` | Tailscale SSH, gated by the tailnet ACL.                                 |
| `openFirewall`    | `true`  | Open UDP 41641 for direct peer connections.                              |
| `trustInterface`  | `true`  | Trust `tailscale0` in the NixOS firewall.                                |

Both NAS hosts (`backup-nas` and the current test `backup-nas-minimal`) enable
it. Leave `workstation` off: it runs Mullvad always-on with a kill switch, and
two WireGuard stacks fight over the default route, DNS and the packet mark.

## One-time setup in the admin console

1. **Log in on the NAS.** There is no auth key in the Nix store, so the account
   lives in `/var/lib/tailscale` after one manual login:

   ```bash
   sudo tailscale up --advertise-routes=192.168.1.0/24 --accept-dns=false
   ```

   The tailnet is created with **Authentik custom OIDC**, not GitHub/Google:
   open the printed `login.tailscale.com` URL, enter `homelab@alexyz.org`, and
   it redirects to Authentik. Tailscale finds the issuer through
   `https://alexyz.org/.well-known/webfinger` (served by the `webfinger` chart
   in the homelab repo), so that endpoint must be up for a _new_ login.
   `tailscaled-set` applies the declarative flags on every later boot.

2. **Approve the route.** Machines -> `backup-nas` -> Subnets -> tick
   `192.168.1.0/24` -> Save. Nothing on the LAN is reachable until this is
   done. To automate it, tag the device and add an `autoApprovers` rule (below).

3. **Disable key expiry** for the router (Machines -> `...` -> Disable key
   expiry), or tag it: tagged devices never expire. An expired router key
   fails closed and silently removes your remote LAN access.

4. **Split DNS for `alexyz.org`.** DNS -> Nameservers -> Add nameserver ->
   custom `192.168.1.253`, then restrict it to the domain `alexyz.org`. Do not
   enable _Override DNS servers_; that would point every query at PiHole.
   Without this step `gitlab.alexyz.org` does not resolve off-LAN, because
   Traefik routes by Host header and the bare IP will not match.

5. **Scope the ACL.** Tailscale applies allow-all when no policy exists, so
   define one. Two rules are needed: one so your devices reach _each other_
   over `100.x` (MagicDNS/SSH to the NAS itself), one so they reach the LAN
   behind the router.

   ```json
   {
     "acls": [
       {
         "action": "accept",
         "src": ["autogroup:member"],
         "dst": ["autogroup:self:*"]
       },
       {
         "action": "accept",
         "src": ["autogroup:member"],
         "dst": ["192.168.1.0/24:*"]
       }
     ]
   }
   ```

   Without the `autogroup:self` rule, `ssh alexis@backup-nas` fails even though
   `ssh 192.168.1.113` works — the first goes to the NAS's tailnet IP, which is
   not inside `192.168.1.0/24`.

   For less reach, replace the second `dst` with explicit hosts and ports, for
   example `192.168.1.110:8006`, `192.168.1.120:6443,50000`,
   `192.168.1.253:53`, `192.168.1.192:80,443`. To get automatic route approval
   and no key expiry, tag the NAS `tag:homelab-router` and add:

   ```json
   "tagOwners": { "tag:homelab-router": ["autogroup:admin"] },
   "autoApprovers": { "routes": { "192.168.1.0/24": ["tag:homelab-router"] } }
   ```

6. **Join the phone.** Install the Tailscale app, sign in with the same
   `homelab@alexyz.org` OIDC identity, leave _Use Tailscale DNS_ enabled (needed
   for the `alexyz.org` split DNS), and connect. iOS/Android pick up approved
   subnet routes automatically; no flags needed.

7. **Join the Mac.** The standalone macOS app is installed declaratively as a
   Homebrew cask on `macbook` (`modules/darwin/homebrew.nix`), so `dr` installs
   it. On first launch macOS asks to allow the system extension in
   _System Settings -> Privacy & Security_ — approve, then sign in from the menu
   bar with `homelab@alexyz.org`. The app is a login item and self-updates; the
   CLI lands at `/usr/local/bin/tailscale`.

## Verify

Layers, cheapest first. A tunnel can be up while routing or DNS is still broken,
so check them in this order.

### 1. Control plane (both devices enrolled)

```bash
ssh root@192.168.1.113 'tailscale status'
# 100.79.214.124  backup-nas     homelab@  linux  -
# 100.100.206.58  iphone-15-pro  homelab@  iOS    -
```

### 2. Data plane (path is real)

```bash
ssh root@192.168.1.113 'tailscale ping -c 2 iphone-15-pro'
# pong ... via [2a0d:...]:41641 in 39ms   -> direct
# pong ... via DERP(par)                   -> relayed, still works
```

`tailscale netcheck` on the NAS shows the path quality. Note this host reports
no IPv4 STUN address (IPv6-only upstream), so IPv4 peers may land on DERP while
IPv6 peers go direct.

### 3. Route approved and installed on the client

- Console: Machines -> `backup-nas` should show the `Subnet` badge and
  `192.168.1.0/24` enabled under Subnets.
- Linux/macOS client: `ip route show table 52 | grep 192.168.1.0/24` (Linux)
  or `netstat -rn | grep 192.168.1` (macOS) must list the route via `tailscale0`.
- Phone: the Tailscale app shows the subnet under the connected node; iOS/Android
  need no flag.

From the Mac (CLI shipped with the app):

```bash
tailscale status                 # backup-nas + iphone listed
tailscale ip -4
tailscale ping backup-nas        # direct vs "via DERP"
netstat -rn | grep 192.168.1     # subnet route present
```

### 4. DNS (split DNS reaches PiHole)

```bash
# on a tailnet Linux client with accept-dns
dig +short gitlab.alexyz.org        # 192.168.1.192
dig +short @100.100.100.100 alexyz.org
```

`dig` is in `host.dnsutils` if it is not installed:
`nix shell nixpkgs#host.dnsutils -c dig +short gitlab.alexyz.org`.

On the phone: open `https://pihole.alexyz.org/admin/`. If the name resolves but
the page 404s, routing works and only the app is missing; if the name does not
resolve, split DNS is not applied (check _Use Tailscale DNS_).

### 5. Services end-to-end (phone on 5G, Wi-Fi off)

| Target                       | Expected                                |
| ---------------------------- | --------------------------------------- |
| `https://gitlab.alexyz.org`  | GitLab login, valid `*.alexyz.org` cert |
| `https://192.168.1.192`      | Traefik 404 (proof the route works)     |
| `https://192.168.1.110:8006` | Proxmox UI                              |
| `https://192.168.1.120:6443` | TLS error/refused is fine — it answers  |
| `ssh alexis@backup-nas`      | shell via the NAS tailnet IP            |

Egress IP is **unchanged**: no exit node is configured, so websites still see
your home/5G address. That is expected — Tailscale here is a private path, not a
privacy VPN.

## Troubleshooting

| Symptom                                               | Cause / fix                                                                                                  |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Phone connected, LAN unreachable                      | Route not approved (Machines -> Subnets), or the ACL lacks the `192.168.1.0/24` rule.                        |
| `ssh backup-nas` fails but `ssh 192.168.1.113` works  | Missing `autogroup:self` ACL rule, or MagicDNS off on that client.                                           |
| `gitlab.alexyz.org` does not resolve                  | Split DNS missing or _Use Tailscale DNS_ disabled; `192.168.1.192` alone cannot satisfy Traefik's Host rule. |
| NAS reachable, everything else times out              | Router not forwarding: `sysctl net.ipv4.ip_forward`, and the route must be approved.                         |
| `tailscaled-set.service` red after install            | Expected before the first login; it succeeds on the next boot after `tailscale up`.                          |
| LAN hosts unreachable, `/var/log` has rp_filter drops | `src_valid_mark` is set by the module; verify with `sysctl net.ipv4.conf.all.src_valid_mark`.                |
| NFS mount hangs from a tailnet client                 | SNAT must stay enabled (default). Disabling it needs a return route for `100.64.0.0/10` and wider exports.   |
| Slow throughput                                       | UDP 41641 blocked -> DERP relay. `tailscale netcheck` shows the path.                                        |
| Linux client sees only 100.x peers                    | Add `acceptRoutes = true` (or `tailscale set --accept-routes`). Phones do it automatically.                  |
| `invalid_client` during tailnet signup                | Authentik has not re-applied the rotated blueprint yet: restart `deploy/authentik-worker`.                   |

## Second router on pve0 (redundancy)

The NAS is the primary subnet router. To keep LAN access when the NAS is down or
upgrading, the Proxmox host advertises the same `/24`. pve0 is Debian, not part
of this NixOS tree, so this one-time setup is imperative:

```bash
ssh root@192.168.1.110
. /etc/os-release; C=$VERSION_CODENAME          # trixie

curl -fsSL "https://pkgs.tailscale.com/stable/debian/${C}.noarmor.gpg" \
  -o /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL "https://pkgs.tailscale.com/stable/debian/${C}.tailscale-keyring.list" \
  -o /etc/apt/sources.list.d/tailscale.list
apt-get update && apt-get install -y tailscale

printf 'net.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1\n' \
  >/etc/sysctl.d/99-tailscale.conf
sysctl --system

tailscale up --advertise-routes=192.168.1.0/24 --accept-dns=false --hostname=pve0
```

Then approve `192.168.1.0/24` for **pve0** in the console (Machines -> pve0 ->
Subnets), and disable key expiry or tag it like the NAS. Multiple routers for
the same prefix are supported: clients use one and fall back when it goes away.
pve0's `pve-firewall` is currently disabled; if you enable it later, trust
`tailscale0` and allow forwarding.

Rollback: `tailscale down && systemctl disable --now tailscaled && apt-get remove tailscale`
(and delete `/etc/sysctl.d/99-tailscale.conf`).

## Limitations

- The NAS is a single point of failure for remote LAN access. Cloudflare Tunnel
  remains the fallback for public services; neither helps if the NAS is down.
- The router exposes the whole `/24` subject to ACLs, not one service at a time.
  Narrow the `dst` list if that matters.
- Tailscale Inc. sees metadata (device names, keys, connection timing); it
  cannot read traffic. Self-hosted Headscale is the alternative if that matters.
- No exit node is configured on purpose: internet egress stays local, or goes
  through Mullvad on the workstation.
