import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    signal ready()

    property string wallpaperDir: Quickshell.env("HOME") + "/Wallpapers"
    property var images: []
    property int count: 0

    function get(index) {
        if (index < 0 || index >= images.length) return "";
        return images[index];
    }

    function refresh() {
        root.images = [];
        root.count = 0;
        lsProc.running = true;
    }

    Process {
        id: lsProc
        command: ["sh", "-c", "ls -1 " + root.wallpaperDir + " 2>/dev/null | grep -iE '\\.(png|jpg|jpeg|webp|gif)$' | sort"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                const trimmed = line.trim();
                if (trimmed.length > 0) {
                    root.images = root.images.concat(trimmed);
                }
            }
        }
        onExited: {
            root.count = root.images.length;
            root.ready();
        }
    }

    Component.onCompleted: refresh()

    Connections {
        target: root
        function onWallpaperDirChanged() {
            root.refresh();
        }
    }
}
