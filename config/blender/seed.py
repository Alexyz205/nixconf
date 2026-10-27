"""Seed Blender 5.x preferences once (home-manager activation).

Only runs when userpref.blend does not exist, so GUI changes are preserved.
"""

import os

import bpy

prefs = bpy.context.preferences

# Core + system extensions installed by the nixconf Blender wrapper.
for module in (
    "node_wrangler",
    "bl_ext.system.print3d_toolbox",
    "bl_ext.system.measureit",
    "bl_ext.system.yl_meshcheckhud",
    "bl_ext.system.printing_helper",
    "bl_ext.system.print_prep",
    "bl_ext.system.easy_print",
    # Legacy add-on from mcp-for-blender.
    "blender_mcp",
):
    try:
        bpy.ops.preferences.addon_enable(module=module)
    except Exception:
        pass

# Catppuccin Mocha interface theme (installed as a user preset).
try:
    theme = os.path.join(
        bpy.utils.user_resource(
            "SCRIPTS", path="presets/interface_theme", create=True
        ),
        "Catppuccin_Mocha.xml",
    )
    if os.path.exists(theme):
        bpy.ops.script.execute_preset(
            filepath=theme,
            menu_idname="USERPREF_MT_interface_theme_presets",
        )
except Exception:
    pass

# Autosave every 5 minutes.
try:
    prefs.filepaths.use_auto_save_temporary_files = True
    prefs.filepaths.auto_save_time = 5
except Exception:
    pass

# Prefer OptiX on RTX hardware, fall back to CUDA, then leave CPU.
try:
    cycles = prefs.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA"):
        try:
            cycles.compute_device_type = kind
            cycles.get_devices()
            if cycles.devices:
                for device in cycles.devices:
                    device.use = True
                break
        except Exception:
            continue
except Exception:
    pass

bpy.ops.wm.save_userpref()
