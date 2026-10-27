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
- The MCP bridge addon is `FreeCADMCP`; start its RPC server from the
  **MCP Addon** workbench before asking the agent to use FreeCAD tools.
- The OpenCode MCP server is `freecad` and runs
  `uvx --from freecad-mcp freecad-mcp` (pinned in the Nix config).
- Addons are installed declaratively through `pkgs.freecad.customize`; do not
  edit `~/.local/share/FreeCAD/Mod` by hand when a Nix addon exists.

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

## MCP tools

When the `freecad` MCP server is connected, prefer its structured tools
(document inspection, sketch diagnostics, shape analysis, STL/STEP export)
over ad-hoc Python. Fall back to `execute_script` only for operations the
structured tools do not cover. Always inspect the result and report units,
dimensions, and validation status.
