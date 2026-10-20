pragma Singleton

import Quickshell

// The dashboard is about to open from a hover at the top edge (modules/drawers): the island stretches downwards over
// the wait, so the opening is visible and can be called off by moving away.
Singleton {
    // the cursor is resting on the trigger and the dashboard opens after `dwell` ms unless it moves off
    property bool active
    property int dwell: 300
}
