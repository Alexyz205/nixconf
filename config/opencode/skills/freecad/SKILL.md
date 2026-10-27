---
name: freecad
description: FreeCAD 1.x modeling, 3D-printing workflows, Python addons, and the FreeCAD MCP bridge
license: MIT
compatibility: opencode
metadata:
  audience: makers
  workflow: cad
---

# FreeCAD

FreeCAD is the CAD source of truth for 3D-printed parts. Work in millimetres,
keep parametric sketches constrained, and verify the exported mesh before
printing.

## Environment

- FreeCAD 1.1.x runs through XWayland (`QT_QPA_PLATFORM=xcb`) on Niri.
- The MCP bridge addon is `FreeCADMCP` (workbench **MCP Addon**). The nixconf
  module enables its auto-start, so the RPC server is up as soon as FreeCAD
  opens (see "MCP tools" below).
- The OpenCode MCP server is `freecad` and runs
  `uvx --from freecad-mcp freecad-mcp` (pinned in the Nix config).
- Addons are installed declaratively through `pkgs.freecad.customize`; do not
  edit `~/.local/share/FreeCAD/Mod` by hand when a Nix addon exists.
- The wrapper exports `FREECAD_USER_HOME`/`FREECAD_USER_DATA` to the standard
  XDG paths. FreeCAD 1.1 resolves `$HOME` via `getpwuid()` and segfaults when
  NSS can't resolve the user (SSSD/LDAP accounts missing from `/etc/passwd`,
  e.g. the RNSL/RNSW work stations); the env override skips that lookup.
  Never unset those two variables when launching FreeCAD on such hosts.

## Modeling rules

- Units: mm, 0.01 mm precision unless the printer/part demands less.
- Prefer PartDesign bodies with fully constrained sketches over Draft shapes.
- Name bodies, sketches, pads, and pockets after the feature they represent.
- Model clearances explicitly for FDM: 0.2–0.4 mm per side for sliding fits,
  0.15–0.3 mm for snap fits; do not rely on slicer compensation.
- Add fillets/chamfers after the main form, and keep wall thickness >= 2
  perimeters (typically 0.8–1.2 mm minimum, 1.6 mm preferred).
- Keep threads modeled only when needed; use `ThreadProfile` or Fasteners for
  standard hardware instead of modeling threads by hand.

## 3D-printing workflow

1. Model the part in PartDesign.
2. Check wall thickness, overhangs, and manifold geometry.
3. Use `MeshRemodel`, `Defeaturing`, or `3D_Printing_Tools` to inspect/repair.
4. Export STL (or 3MF when available) with a sensible deviation:
   `MeshDeviation=0.2–0.5`, `MeshAngularDeflection=6–10°`.
5. Verify the exported mesh is watertight and has the expected bounding box.
6. Ask before overwriting or deleting an existing `.FCStd`/STL artifact.

## Python and macros

FreeCAD's Python API is available in the console and through `freecadcmd`:

```python
import FreeCAD as App
import Part, Sketcher
doc = App.newDocument("part")
body = doc.addObject("PartDesign::Body", "Body")
# ... build the feature tree ...
doc.recompute()
```

- Use `App.ActiveDocument`/`Gui.ActiveDocument` only in GUI context.
- Prefer `doc.recompute()` after feature changes and check `obj.isValid()`.
- Use `App.ParamGet("User parameter:BaseApp/Preferences/...")` for preferences.
- For headless checks run `freecadcmd -c "exec(open('script.py').read())"`.

## Addon development

An addon directory needs `InitGui.py` (or `Init.py`) and ideally `package.xml`.
Expose workbenches/commands from `InitGui.py`; keep GUI imports out of
`Init.py`. Test with the FreeCAD version in `pkgs.freecad` and pin the addon
with `fetchFromGitHub` + `rev`/`hash` in the nixconf module.

FreeCAD 1.1 treats every `--module-path` value as _one_ add-on and runs
`<path>/InitGui.py`, so `pkgs.freecad.customize` must receive one path per
add-on. Passing a `linkFarm` of add-ons loads none of them silently.

## MCP tools

Starting the bridge (already done by the nixconf module):

- `pkgs.freecad.customize` installs the `FreeCADMCP` add-on; the workbench is
  listed as **MCP Addon** in the workbench selector.
- `~/.local/share/FreeCAD/v1-1/freecad_mcp_settings.json` ships with
  `auto_start_rpc: true`, so opening FreeCAD starts the XML-RPC server on
  `127.0.0.1:9875` — the address the `freecad` MCP server dials.
- Manual alternative / recovery: switch to the **MCP Addon** workbench and use
  the **FreeCAD MCP** toolbar → Start RPC Server (also Stop, Toggle Auto Start,
  Toggle Remote Connections, Allowed IPs, Auth Token). Results go to the Report
  view.
- Sanity check without OpenCode: `ss -ltn | grep 9875` while FreeCAD is open.

When the `freecad` MCP server is connected, prefer its structured tools
(document inspection, sketch diagnostics, shape analysis, STL/STEP export)
over ad-hoc Python. Fall back to `execute_script` only for operations the
structured tools do not cover. Always inspect the result and report units,
dimensions, and validation status.
