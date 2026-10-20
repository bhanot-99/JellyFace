import "modules"
import "modules/drawers"
import "modules/dock"
import "modules/clipboard"
import "modules/jellypanel"
import "modules/island"
import "modules/agenda"
import Quickshell

// The original JellyFace interface ("Classic"). shell.qml loads this or Quill (quill/QuillShell.qml), never both; the
// lock screen, idle handling and battery warnings live in shell.qml and serve both.
Scope {
    Dock {}
    JellyPanelWindow {}
    DynamicIsland {}
    Drawers {}
    ClipboardPopup {}
    Agenda {}
    EventForm {}

    Shortcuts {}
}
