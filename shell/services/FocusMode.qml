pragma Singleton

import Quickshell
import Quickshell.Io
import Jellyface
import Jellyface.Config
import Jellyface.I18n
import qs.services

// Focus mode: one switch for "leave me alone": Do Not Disturb on and the screen kept awake. Turning it off puts both
// back the way they were before (so it never switches off a DND or keep-awake you turned on yourself).
Singleton {
    id: root

    property alias enabled: props.enabled

    function toggle(): void {
        enabled = !enabled;
    }

    onEnabledChanged: {
        if (enabled) {
            props.hadDnd = Notifs.dnd;
            props.hadInhibit = IdleInhibitor.enabled;
            Notifs.dnd = true;
            IdleInhibitor.enabled = true;
            Toaster.toast(Tr.tr("Focus mode on"), Tr.tr("Notifications muted and the screen kept awake"), "target");
        } else {
            Notifs.dnd = props.hadDnd;
            IdleInhibitor.enabled = props.hadInhibit;
            Toaster.toast(Tr.tr("Focus mode off"), Tr.tr("Notifications and screen timeout restored"), "target");
        }
    }

    PersistentProperties {
        id: props

        property bool enabled
        property bool hadDnd
        property bool hadInhibit

        reloadableId: "focusMode"
    }

    IpcHandler {
        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
        }

        target: "focus"
    }
}
