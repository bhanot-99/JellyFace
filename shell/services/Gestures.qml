pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Touchpad swipes from helpers/gestures/gestured, which runs on the host (the container cannot read /dev/input) and
// streams lines over this socket: "begin N", "update N dx dy" (mm, dy < 0 = up), "swipe N dir" (once the direction
// is clear), "end N dx dy" (fingers lifted) and "cancel N".
Singleton {
    id: root

    signal began(fingers: int)
    signal moved(fingers: int, dx: real, dy: real)
    signal swiped(fingers: int, direction: string)
    signal ended(fingers: int, dx: real, dy: real)
    signal cancelled(fingers: int)

    SocketServer {
        active: true
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/jellyface-gestures.sock`
        handler: Socket {
            parser: SplitParser {
                onRead: line => {
                    const p = line.split(" ");
                    const n = parseInt(p[1]);
                    if (!(n >= 3 && n <= 5))
                        return;
                    if (p[0] === "update")
                        root.moved(n, parseFloat(p[2]), parseFloat(p[3]));
                    else if (p[0] === "begin")
                        root.began(n);
                    else if (p[0] === "swipe" && ["up", "down", "left", "right"].includes(p[2]))
                        root.swiped(n, p[2]);
                    else if (p[0] === "end")
                        root.ended(n, parseFloat(p[2]), parseFloat(p[3]));
                    else if (p[0] === "cancel")
                        root.cancelled(n);
                }
            }
        }
    }
}
