---
name: blender
description: Blender 5.x 3D-printing modeling, mesh validation, export, and the Blender MCP bridge
license: MIT
compatibility: opencode
metadata:
  audience: makers
  workflow: 3d
---

# Blender

Use Blender for organic/sculpted parts, quick mockups, and mesh repair. For
precision mechanical parts, prefer FreeCAD. Always export print-ready meshes
with real-world scale.

## Environment

- Blender 5.2.x is built with Cycles CUDA/OptiX on the workstation.
- Print addons are system extensions: 3D Print Toolbox, MeasureIt,
  MeshCheck HUD, Printing Helper, Print Prep, Easy Print.
- The Blender MCP addon is `blender_mcp`; start its server from the
  **MCP for Blender** sidebar before using the OpenCode `blender` MCP server.
- The OpenCode MCP server runs `uvx --from mcp-for-blender mcp-for-blender`
  (pinned in the Nix config).

## 3D-printing rules

- Set scene unit scale to metres with 1.0 scale, and model dimensions in mm
  (e.g. type `20mm` in transform fields).
- Apply scale (`Ctrl+A`) before booleans, bevels, and export.
- Keep the mesh manifold: no interior faces, no non-manifold edges, no
  duplicate vertices. Run **3D Print Toolbox → Check All**.
- Minimum wall for FDM: 0.8 mm (2 perimeters at 0.4 mm), 1.2–1.6 mm preferred.
- Add clearance for mating parts (0.2–0.4 mm per side).
- Use Remesh/Voxel or Boolean + Remesh for organic forms, then validate.
- Export STL with `+Y up` disabled for printing; use binary STL and check the
  bounding box in the slicer.

## MCP workflow

When the `blender` MCP server is connected, prefer its scene/object tools for
inspection and simple edits. Use Python (`bpy`) for repeatable modeling or
batch export. Ask before deleting objects or overwriting `.blend` files.

Useful Python entry points:

```python
import bpy
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1.0
bpy.ops.object.select_all(action='DESELECT')
```

For print validation, use the 3D Print Toolbox operators and report the
manifold/overhang/thickness results explicitly.
