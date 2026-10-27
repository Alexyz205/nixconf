"""Seed FreeCAD 1.x preferences once (home-manager activation).

The Catppuccin preference pack is copied to user.cfg first; this script adds
the nixconf defaults (metric mm, autosave, CAD navigation, theme, workbench).
It only runs when user.cfg does not exist, so GUI changes are preserved.
"""

import FreeCAD

units = FreeCAD.ParamGet("User parameter:BaseApp/Preferences/Units")
units.SetInt("UserSchema", 0)
units.SetBool("IgnoreProjectSchema", True)
units.SetInt("Decimals", 2)

document = FreeCAD.ParamGet("User parameter:BaseApp/Preferences/Document")
document.SetBool("AutoSaveEnabled", True)
document.SetInt("AutoSaveTimeout", 15)

view = FreeCAD.ParamGet("User parameter:BaseApp/Preferences/View")
view.SetString("NavigationStyle", "Gui::CADNavigationStyle")

main_window = FreeCAD.ParamGet("User parameter:BaseApp/Preferences/MainWindow")
main_window.SetString("StyleSheet", "CatppuccinNights.qss")

general = FreeCAD.ParamGet("User parameter:BaseApp/Preferences/General")
general.SetString("AutoloadModule", "PartDesignWorkbench")

FreeCAD.saveParameter()
