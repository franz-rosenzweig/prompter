# dmgbuild settings for Prompter's DMG (tools/dmg.sh passes app, background and icon with -D).
# The window is 660x440, the app on the left, the Applications folder on the right, as the
# background draws them; dmgbuild writes the Finder's layout itself, without scripting the Finder.
import os.path

app = defines["app"]
name = os.path.basename(app)

format = "ULFO"                      # lzfse: smaller, and opens on every macOS Prompter runs on
filesystem = "APFS"
files = [app]
symlinks = {"Applications": "/Applications"}
# no hide_extensions: it flags the app folder in a way strict signature checks reject, and the
# Finder hides ".app" by default anyway
icon = defines.get("icon")           # the volume's icon, the app's own
background = defines["background"]

window_rect = ((220, 140), (660, 440))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
arrange_by = None
icon_size = 112
text_size = 13
icon_locations = {name: (165, 196), "Applications": (495, 196)}
