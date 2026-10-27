---
name: artcraft
description: The ArtCraft desktop suite (PhotoCraft, LightCraft, PDFCraft, FilmCraft, WordCraft, GridCraft, CadCraft, DeckCraft, SoundCraft) and how to launch/update it
license: MIT
compatibility: opencode
metadata:
  audience: makers
  workflow: desktop
---

# ArtCraft

The ArtCraft suite is a set of GUI apps installed from pinned upstream release
tarballs on Linux x86_64. They are feature modules under
`modules/desktop/artcraft.nix`; the flake outputs are also named
`photocraft`, `lightcraft`, etc.

| Binary | App | Replaces | Typical files |
| --- | --- | --- | --- |
| `photocraft` | PhotoCraft | Photoshop | PSD, PNG, JPEG, TIFF |
| `lightcraft` | LightCraft | Lightroom | RAW, DNG, JPEG |
| `pdfcraft` | PDFCraft | Acrobat | PDF |
| `filmcraft` | FilmCraft | Premiere Pro | MP4, MOV, ProRes |
| `wordcraft` | WordCraft | Microsoft Word | DOCX, ODT |
| `gridcraft` | GridCraft | Microsoft Excel | XLSX, CSV |
| `cadcraft` | CadCraft | AutoCAD | DWG, DXF |
| `deckcraft` | DeckCraft | PowerPoint | PPTX |
| `soundcraft` | SoundCraft | Pro Tools | WAV, AIFF, FLAC |

## Usage

- On NixOS the binaries are on `$PATH`; launch with `photocraft <file>` etc.
- From the repo: `nix run $NIXCONF#photocraft -- <file>`.
- These are GUI-first; OpenCode can launch them and inspect their files, but
  cannot drive the GUI. Use the CLI/flags exposed by each app (`--help`).
- Do not delete or overwrite a user's project file without asking. Prefer
  opening the file and letting the user save.

## Updates

Versions and hashes live in `modules/desktop/artcraft.nix`. To update:

1. Check the latest `storytold/<app>` GitHub release and the
   `<app>-<version>-linux-x86_64.tar.gz` asset.
2. Update `version` and `hash` (`nix-prefetch-url --unpack`, then SRI).
3. Run `nix flake check`; build at least one app to catch new runtime libs.
4. Add runtime libraries to the app's `extraRuntimeLibs` only if the binary
   fails to start.
