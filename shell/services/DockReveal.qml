pragma Singleton

import Quickshell

// Lets an auto-hidden dock be called back by pushing the cursor to the bottom edge. The very bottom of the screen
// belongs to the shell's frame (modules/drawers), so the frame reports the cursor there and the dock listens.
Singleton {
    // the dock's horizontal span on screen, set by the dock
    property real left
    property real right
    // the cursor is on the bottom edge, under the dock
    property bool edge
}
