pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    property bool isLocked: false
    property var layouts: ({})
    property string lastSavedText: ""
    readonly property string filePath: `${Paths.config}/dashboard-layout.json`

    signal layoutChanged()

    function getCard(id: string, defX: real, defY: real, defW: real, defH: real): var {
        if (layouts[id]) {
            return {
                x: layouts[id].x ?? defX,
                y: layouts[id].y ?? defY,
                width: layouts[id].width ?? defW,
                height: layouts[id].height ?? defH,
                visible: layouts[id].visible ?? true
            };
        }
        return {
            x: defX,
            y: defY,
            width: defW,
            height: defH,
            visible: true
        };
    }

    function setCardGeometry(id: string, x: real, y: real, w: real, h: real): void {
        const current = layouts[id] || {};
        layouts[id] = {
            x: Math.round(x),
            y: Math.round(y),
            width: Math.round(w),
            height: Math.round(h),
            visible: current.visible ?? true
        };
        root.layoutChanged();
        saveTimer.restart();
    }

    function setCardVisible(id: string, vis: bool): void {
        const current = layouts[id] || {};
        current.visible = vis;
        layouts[id] = current;
        root.layoutChanged();
        saveTimer.restart();
    }

    function isCardVisible(id: string, defVis: var): bool {
        const fallback = defVis === undefined ? true : !!defVis;
        if (layouts[id] && layouts[id].visible !== undefined)
            return layouts[id].visible;
        return fallback;
    }

    function toggleLock(): void {
        isLocked = !isLocked;
        saveTimer.restart();
    }

    function save(): void {
        const data = {
            isLocked: root.isLocked,
            cards: root.layouts
        };
        const text = JSON.stringify(data, null, 2);
        if (text !== lastSavedText) {
            lastSavedText = text;
            file.setText(text);
        }
    }

    function load(jsonText: string): void {
        if (!jsonText || jsonText.trim() === "" || jsonText === lastSavedText)
            return;
        try {
            const data = JSON.parse(jsonText);
            if (data.isLocked !== undefined)
                root.isLocked = data.isLocked;
            if (data.cards)
                root.layouts = data.cards;
            root.layoutChanged();
        } catch (e) {
            console.warn("DashboardState: error loading layout.json:", e);
        }
    }

    Timer {
        id: saveTimer
        interval: 350
        onTriggered: root.save()
    }

    FileView {
        id: file
        path: root.filePath
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: root.load(text())
    }
}
