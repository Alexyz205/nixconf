# GlobalProtect (`gpclient`) on RNSL-APIGEON5

`gpclient` is the command-line client from
[yuezk/GlobalProtect-openconnect](https://github.com/yuezk/GlobalProtect-openconnect)
(GP Connect). Nixpkgs removed the old Qt5 build, so this repo pulls the
upstream flake (prebuilt, pinned in `flake.lock`) and exposes the CLI to the
work home-manager profile. The desktop GUI in the same release is commercial;
only the GPL CLI is used here.

## Enabled where

`modules/system/globalprotect.nix` adds the flake input and a home-manager
module. It is part of `workExtra`, so only the `RNSL-APIGEON5` profile gets it.

```nix
modules.globalprotect = {
  enable = true;                 # default portal below
  portal = "vpn.take2games.com"; # public DNS; override if IT publishes another
  browser = true;                # external browser for SAML/Okta/WebAuthn
};
```

## Usage

```bash
gpvpn                  # connect to vpn.take2games.com (SAML in the browser)
gpvpn connect <portal> # connect to another portal
gpvpn disconnect
gpvpn diagnostics      # collect a support report (no sudo)
gpvpn-sudo             # fallback: run the raw CLI as root
```

`gpvpn` runs `gpclient` as **you**, not as root. The CLI uses `pkexec` for the
privileged tunnel setup, so the sign-in browser stays in your GNOME session and
can use Okta/WebAuthn/YubiKey. The first connection shows a polkit password
prompt; approving it for the session is enough.

Useful connection options (pass through `gpvpn connect ...`):

| Option                   | When                                               |
| ------------------------ | -------------------------------------------------- |
| `--hip`                  | Portal requires Host Information Profile reporting |
| `--cookie-cache`         | Reuse a still-valid portal session                 |
| `--browser manual`       | SSH/headless: print the URL, paste the callback    |
| `--user alexis.pigeon`   | Portal uses username/password instead of SSO       |
| `--certificate file.p12` | Portal requires a client certificate               |

If the embedded login window is preferred, set `modules.globalprotect.browser =
false` (less reliable for Okta/WebAuthn).

## Prerequisites on RNSL

- **Corporate root CA**: the Ubuntu enrollment should already trust the T2
  Palo Alto inspection CA. Verify:

  ```bash
  openssl s_client -connect vpn.take2games.com:443 \
    -servername vpn.take2games.com </dev/null 2>/dev/null |
    grep "Verify return code"        # expect: 0 (ok)
  ```

  If it fails, install the CA from the asset mirror as root and run
  `sudo update-ca-certificates`.

- **TUN device and polkit**: standard Ubuntu desktop has `/dev/net/tun` and
  `pkexec`; GNOME provides the polkit agent for the prompt.
- **Sudo** (fallback only): `gpvpn-sudo` prompts normally.

## Optional: passwordless polkit rule

The package ships a rule that authorizes its own `gpservice` path:

```bash
rule=$(dirname "$(readlink -f "$(command -v gpclient)")")/../share/polkit-1/rules.d/49-gpgui.rules
sudo install -Dm644 "$rule" /etc/polkit-1/rules.d/49-gpgui.rules
```

The rule embeds the current store path, so reinstall it after a `gpclient`
update. Skipping this is fine: polkit simply prompts each time.

## Verify the tunnel

```bash
ip -brief address show tun0
ip route | grep -E 'tun0|10\.|172\.'
resolvectl status | head -30
curl -sS -o /dev/null -w '%{http_code}\n' https://git.dxyz.pro/
gpvpn disconnect
```

## Troubleshooting

| Symptom                                 | Check                                                                                         |
| --------------------------------------- | --------------------------------------------------------------------------------------------- |
| TLS / certificate error                 | Corporate CA above; do not use `--ignore-tls-errors` on a work device                         |
| Blank embedded login                    | Use the default external browser (`browser = true`) or `--browser manual`                     |
| Polkit prompt never appears             | GNOME polkit agent running; log in locally, not over SSH                                      |
| `Operation not permitted` on the tunnel | `pkexec`/polkit unavailable; try `gpvpn-sudo` and report                                      |
| Connected but no DNS                    | `resolvectl status`; systemd-resolved or the vpnc script may need `--disable-ipv6`/MTU        |
| Portal rejects the client               | Try `--hip` or the official Palo Alto client; corporate policy may require it                 |
| Legacy TLS renegotiation warning        | Some portals are old; `gpclient` uses its bundled stack. Do not disable verification globally |

The tunnel is a privileged network change: keep `vpn.take2games.com` access
scoped to the corporate network, do not share diagnostics without reviewing
them, and confirm the open-source client is allowed by Take-Two policy.
