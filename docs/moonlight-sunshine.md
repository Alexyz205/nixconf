# Moonlight + Sunshine (replace RDP)

Moonlight replaces RDP for the Windows studio workstation (`rnsw-studio1`):
Sunshine captures/encodes on the Windows host with NVENC and Moonlight decodes
on the Linux client with the GPU. Remmina/FreeRDP remains installed as the
console fallback (RDP keeps working on 3389).

```text
rnsw-studio1 (Windows, NVIDIA + monitor)   Sunshine host
        │  1 GbE, same VLAN
        ├── rnsw-apigeon1  (NixOS, niri, 5120x2160@60)   Moonlight client
        └── RNSL-APIGEON5  (Ubuntu/GNOME work laptop)    Moonlight client
```

Both clients get `pkgs.moonlight-qt` from `modules/desktop/moonlight.nix`;
RDP is not removed. The clients need no inbound ports.

## Windows host: install

1. Install the official MSI from
   <https://github.com/LizardByte/Sunshine/releases/latest>
   (`Sunshine-Windows-AMD64-installer.msi`). Keep the service and the
   ViGEmBus component if you use a controller.
2. Open `https://localhost:47990` on the host, create a strong username and
   password (anyone with the web UI can pair a client).
3. Add a static DHCP reservation for the host: `bind_address` and the firewall
   rules below assume a stable address.
4. In Windows, set the power plan to **High performance** and set
   **Sleep** and **Turn off display** to **Never** while plugged in. A sleeping
   host kills the stream and cannot be woken by Moonlight (use WoL for that).

## Windows host: `sunshine.conf`

The file is `%ProgramFiles%\Sunshine\config\sunshine.conf`; the same values are
available in the web UI. Restart the Sunshine service after editing.

```ini
sunshine_name = rnsw-studio1
min_log_level = info

# Capture / display
capture = ddx
encoder = nvenc
dd_configuration_option = ensure_only_display
dd_resolution_option = auto
dd_refresh_rate_option = auto
# Keep SDR: Moonlight Linux HDR is only supported when launched from a console
# with an Intel GPU. Enable only after verifying an HDR client.
dd_hdr_option = disabled

# Network: LAN/VPN only, never expose Sunshine to the Internet.
upnp = disabled
origin_web_ui_allowed = lan
bind_address = <studio1-ip>
max_bitrate = 150000
minimum_fps_target = 0

# Encryption: 0 = fastest on a trusted wired LAN; connections from another
# subnet (VPN) use wan_encryption_mode.
lan_encryption_mode = 0
wan_encryption_mode = 1

# NVENC: P1 keeps encoder latency minimal; raise bitrate for quality instead
# of raising the preset (LizardByte's recommendation).
nvenc_preset = 1
nvenc_twopass = quarter_res
nvenc_spatial_aq = disabled
nvenc_vbv_increase = 0
nvenc_realtime_hags = enabled
nvenc_split_encode = driver_decides
nvenc_latency_over_power = enabled
nvenc_opengl_vulkan_on_dxgi = enabled

# Audio
stream_audio = enabled
install_steam_audio_drivers = enabled
```

Notes:

- `ensure_only_display` makes the streamed monitor the only active one.
  `dd_config_revert_on_disconnect = enabled` is optional and reverts the
  display layout as soon as the last client disconnects.
- If the host freezes at high VRAM usage, set
  `nvenc_realtime_hags = disabled` (or disable Hardware-accelerated GPU
  Scheduling in Windows).
- If you want to mute the host speakers while streaming, install the Steam
  audio drivers and set `virtual_sink = Steam Streaming Speakers`.
- Windows HDR must be off unless the client and the whole chain are HDR. A
  Linux Moonlight client does not officially support HDR from a desktop
  session.

## Firewall (Windows, inbound LAN/VPN only)

The MSI creates rules; verify and scope them. Run PowerShell as administrator:

```powershell
New-NetFirewallRule -DisplayName "Sunshine TCP" -Direction Inbound -Action Allow `
  -Protocol TCP -LocalPort 47984,47989,47990,48010 -Profile Domain,Private `
  -RemoteAddress 10.113.64.0/24

New-NetFirewallRule -DisplayName "Sunshine UDP" -Direction Inbound -Action Allow `
  -Protocol UDP -LocalPort 5353,47998-48000,48002,48010 -Profile Domain,Private `
  -RemoteAddress 10.113.64.0/24
```

Add the VPN client subnet to `-RemoteAddress` if Moonlight connects over the
VPN. Do not add a public port-forward; use the VPN/Tailscale for remote access.

## Pair

1. Start Moonlight on the client, add the host by name or IP.
2. Click the host: Moonlight shows a 4-digit PIN.
3. On the host, open `https://localhost:47990` -> **PIN**, enter it, name the
   client.
4. Start the **Desktop** application (pre-created by Sunshine).

Pairing must be done while the client can reach the host (same LAN or VPN).
The host key is pinned in Moonlight after pairing.

## Moonlight client settings (best quality/latency)

| Setting                           | rnsw-apigeon1                          | RNSL-APIGEON5                        |
| --------------------------------- | -------------------------------------- | ------------------------------------ |
| Resolution                        | `5120x2160` (native U4021QW)           | Native panel                         |
| FPS                               | 60                                     | 60 (or 120 if the panel supports it) |
| Bitrate                           | 100–150 Mbps (wired)                   | 100–150 Mbps (wired)                 |
| Codec                             | HEVC; AV1 if the host GPU is RTX 40/50 | HEVC                                 |
| Frame pacing                      | On                                     | On                                   |
| V-Sync                            | Off                                    | Off                                  |
| HDR                               | Off                                    | Off                                  |
| Optimize game settings            | On                                     | On                                   |
| Optimize mouse for remote desktop | On (desktop use)                       | On                                   |

If the Windows host monitor cannot do `5120x2160`, stream `3840x2160` (or the
highest mode the host supports) and let Moonlight scale; forcing an unsupported
mode causes a black stream. `Optimize game settings` is what allows Sunshine to
switch the host display to the client's requested mode.

## Latency checklist

- Wired Ethernet on both ends; same switch/VLAN. 1 GbE is enough for 150 Mbps.
- Disable Wi-Fi, VPN segmentation and any traffic shaping between the hosts.
- Host: NVIDIA Control Panel -> Low Latency Mode **Ultra**, Power management
  **Prefer maximum performance**, V-Sync **Off**.
- Host: do not let the display sleep; `ensure_only_display` + Never sleep.
- Client: hardware decoding (default), frame pacing on, V-Sync off.
- Use HEVC at 100–150 Mbps before considering AV1; AV1 needs an RTX 40/50 host
  and an AV1-capable decoder, and is only a bandwidth win at the same quality.
- For a 5K2K client the host has to encode 5120x2160; if NVENC is the limit,
  drop to 4K and upscale on the client.

## Troubleshooting

| Symptom                 | Check                                                                         |
| ----------------------- | ----------------------------------------------------------------------------- |
| Host not discovered     | Add it manually by IP; mDNS may be blocked across VLANs                       |
| PIN rejected            | The 30 s window expired; regenerate the PIN                                   |
| Black screen            | Host display sleeping/absent, wrong `output_name`, unsupported requested mode |
| Choppy video            | Wi-Fi, VPN MTU, or bitrate above the path; lower bitrate or set `packetsize`  |
| Controller not detected | ViGEmBus installed and Sunshine service restarted                             |
| No audio                | `audio_sink`/default device, Steam audio drivers, `stream_audio`              |
| Stream dies when idle   | Windows sleep/display timeout; set to Never                                   |

Sources: LizardByte Sunshine configuration docs (`capture`, `dd_*`, NVENC
options), Moonlight setup guide (ports, pairing, HDR requirements).

## RDP fallback

Remmina/FreeRDP stays installed (`modules.rdp`). Use RDP for console/admin work
when Moonlight is unavailable; RDP on `rnsw-studio1` is already reachable.
