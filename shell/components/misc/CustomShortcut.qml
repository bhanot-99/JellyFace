import QtQuick

// COSMIC has no hyprland_global_shortcuts_v1, so a real GlobalShortcut could never bind (it only logged two warnings
// per shortcut at every start). Keybindings come from COSMIC itself (config/cosmic-shortcuts.ron runs
// `jellyface ipc ...`); this inert stand-in keeps the declarations, which document the available actions.
QtObject {
    property string appid: "jellyface"
    property string name
    property string description

    signal pressed
    signal released
}
