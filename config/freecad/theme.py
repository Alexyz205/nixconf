"""Activate the Catppuccin theme (home-manager activation).

The add-on ships the style sheet as a preference pack, but applying a pack is a
GUI-only action in FreeCAD, so the activation sets the two keys the pack would
have written. Idempotent: safe to run on every switch.
"""

import FreeCAD

main_window = FreeCAD.ParamGet("User parameter:BaseApp/Preferences/MainWindow")
main_window.SetString("StyleSheet", "CatppuccinNights.qss")
main_window.SetString("OverlayActiveStyleSheet", "CatppuccinNights_Overlay.qss")

FreeCAD.saveParameter()
