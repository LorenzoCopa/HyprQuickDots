pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../config"

Item {
  id: root

  property var items: []
  property bool cliphistInstalled: true
  property var hoveredItem: null

  Process {
    id: listProc
    command: ["sh", "-c", "cliphist list 2>/dev/null"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var data = text.trim();
        if (!data) {
          root.items = [];
          return;
        }
        var lines = data.split("\n");
        var parsed = [];
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i];
          if (!line) continue;
          var idx = line.indexOf("\t");
          if (idx >= 0) {
            var cid = parseInt(line.substring(0, idx));
            var content = line.substring(idx + 1);
            var isImage = content.indexOf("binary data") >= 0;
            var preview = content.split("\n")[0];
            if (isImage) {
              preview = preview.replace(/^\[\[ binary data | \]\]$/g, "");
            }
            if (preview.length > 80) preview = preview.substring(0, 80) + "...";
            parsed.push({ id: cid, preview: preview, isImage: isImage, thumbReady: false });
          }
        }
        root.items = parsed;
      }
    }
    onExited: function(exitCode) {
      if (exitCode === 127)
        root.cliphistInstalled = false;
    }
  }

  Process {
    id: copyProc
    command: []
    running: false
  }

  Process {
    id: deleteProc
    command: []
    running: false
    onExited: root.refresh()
  }

  Process {
    id: thumbProc
    command: []
    running: false
    onExited: {
      if (root.hoveredItem)
        root.hoveredItem.thumbReady = true;
    }
  }

  function copyItem(id) {
    copyProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"];
    copyProc.running = true;
  }

  function deleteItem(id) {
    deleteProc.command = ["sh", "-c", "cliphist delete " + id + " 2>/dev/null"];
    deleteProc.running = true;
  }

  function clearAll() {
    deleteProc.command = ["sh", "-c", "cliphist wipe 2>/dev/null"];
    deleteProc.running = true;
  }

  function refresh() {
    listProc.running = false;
    listProc.running = true;
  }

  function loadThumbnail(item) {
    if (!item || !item.isImage || item.thumbReady) return;
    thumbProc.command = ["sh", "-c", "cliphist decode " + item.id + " > /tmp/qs_thumb_" + item.id + ".png 2>/dev/null"];
    thumbProc.running = true;
  }

  onHoveredItemChanged: {
    if (root.hoveredItem)
      root.loadThumbnail(root.hoveredItem);
  }

  Component.onCompleted: root.refresh()

  ColumnLayout {
    anchors.fill: parent
    spacing: 6

    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: 24
      Layout.leftMargin: 8
      Layout.rightMargin: 12

      Text {
        text: "Portapapeles"
        color: Settings.subtext0
        font.family: Settings.fontFamily
        font.pixelSize: 11
        font.weight: Font.Bold
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        text: "(" + root.items.length + ")"
        color: Settings.subtext0
        font.family: Settings.fontFamily
        font.pixelSize: 11
        Layout.alignment: Qt.AlignVCenter
      }

      Item { Layout.fillWidth: true }

      SymbolicIcon {
        path: Icons.trash
        color: clearMouse.containsMouse ? Settings.red : Settings.subtext0
        implicitSize: 12
        Layout.alignment: Qt.AlignVCenter

        MouseArea {
          id: clearMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true
          onClicked: root.clearAll()
        }
      }

      SymbolicIcon {
        path: Icons.refresh
        color: Settings.accent
        implicitSize: 12
        Layout.alignment: Qt.AlignVCenter

        MouseArea {
          id: refreshMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true
          onClicked: root.refresh()
        }
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: 20
      Layout.leftMargin: 8
      Layout.rightMargin: 12

      Rectangle {
        anchors.fill: parent
        radius: 6
        color: Settings.surface
      }

      Text {
        anchors {
          left: parent.left
          leftMargin: 8
          verticalCenter: parent.verticalCenter
        }
        text: "Buscar..."
        color: Settings.subtext0
        font.family: Settings.fontFamily
        font.pixelSize: 11
        visible: searchInput.text.length === 0
      }

      TextInput {
        id: searchInput
        anchors {
          fill: parent
          leftMargin: 8
          rightMargin: 8
        }
        verticalAlignment: TextInput.AlignVCenter
        color: Settings.fg
        font.family: Settings.fontFamily
        font.pixelSize: 11
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.leftMargin: 8
      Layout.rightMargin: 12
      Layout.bottomMargin: 8
      radius: 8
      color: Settings.surface
      clip: true

      Text {
        anchors.centerIn: parent
        text: {
          if (!root.cliphistInstalled) return "cliphist no instalado";
          if (root.items.length === 0) return "Portapapeles vac\u00edo";
          return "";
        }
        color: Settings.subtext0
        font.family: Settings.fontFamily
        font.pixelSize: 11
        visible: text !== ""
      }

      ListView {
        id: listView
        anchors {
          top: parent.top
          left: parent.left
          right: parent.right
          bottom: root.hoveredItem ? previewArea.top : parent.bottom
        }
        anchors.margins: 4
        spacing: 2
        visible: root.items.length > 0
        clip: true

        model: {
          var q = searchInput.text.toLowerCase().trim();
          if (!q) return root.items;
          var filtered = [];
          for (var i = 0; i < root.items.length; i++) {
            if (root.items[i].preview.toLowerCase().indexOf(q) >= 0)
              filtered.push(root.items[i]);
          }
          return filtered;
        }

        delegate: Rectangle {
          width: listView.width
          height: 28
          radius: 6
          color: itemMouse.containsMouse ? Settings.selectionBg : "transparent"
          Behavior on color { ColorAnimation { duration: 80 } }

          required property var modelData

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 6

            Item {
              width: 24
              height: 24
              Layout.preferredWidth: 24
              Layout.preferredHeight: 24

              Rectangle {
                anchors.fill: parent
                radius: 4
                color: modelData.isImage ? Settings.bg : "transparent"
                visible: modelData.isImage
              }

              Image {
                anchors.fill: parent
                anchors.margins: 1
                source: modelData.isImage && modelData.thumbReady ? "file:///tmp/qs_thumb_" + modelData.id + ".png" : ""
                sourceSize { width: 24; height: 24 }
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: modelData.isImage && modelData.thumbReady

                SymbolicIcon {
                  anchors.centerIn: parent
                  path: Icons.image
                  color: Settings.yellow
                  implicitSize: 12
                  visible: !modelData.thumbReady
                }
              }

              SymbolicIcon {
                anchors.centerIn: parent
                path: Icons.textFile
                color: Settings.accent
                implicitSize: 12
                visible: !modelData.isImage
              }
            }

            Text {
              Layout.fillWidth: true
              text: modelData.preview
              color: Settings.fg
              font.family: Settings.fontFamily
              font.pixelSize: 10
              elide: Text.ElideRight
              maximumLineCount: 1
            }

            SymbolicIcon {
              path: Icons.check
              color: copyMouse.containsMouse ? Settings.green : "transparent"
              implicitSize: 10

              MouseArea {
                id: copyMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                  root.copyItem(modelData.id);
                  event.accepted = true;
                }
              }
            }

            SymbolicIcon {
              path: Icons.close
              color: delMouse.containsMouse ? Settings.red : "transparent"
              implicitSize: 10

              MouseArea {
                id: delMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                  root.deleteItem(modelData.id);
                  event.accepted = true;
                }
              }
            }
          }

          MouseArea {
            id: itemMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: {
              if (modelData.isImage)
                root.hoveredItem = modelData;
            }
            onExited: {
              if (root.hoveredItem && root.hoveredItem.id === modelData.id)
                root.hoveredItem = null;
            }
            onClicked: root.copyItem(modelData.id)
          }
        }
      }

      Rectangle {
        id: previewArea
        anchors {
          left: parent.left
          right: parent.right
          bottom: parent.bottom
          margins: 4
        }
        height: 120
        radius: 6
        color: Settings.bg
        visible: root.hoveredItem != null

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 6
          spacing: 4

          Text {
            text: root.hoveredItem ? root.hoveredItem.preview : ""
            color: Settings.subtext0
            font.family: Settings.fontFamily
            font.pixelSize: 9
            elide: Text.ElideRight
            maximumLineCount: 1
          }

          Image {
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: root.hoveredItem && root.hoveredItem.thumbReady ? "file:///tmp/qs_thumb_" + root.hoveredItem.id + ".png" : ""
            sourceSize { width: 200; height: 90 }
            fillMode: Image.PreserveAspectFit
            asynchronous: true

            Text {
              anchors.centerIn: parent
              text: "Cargando..."
              color: Settings.subtext0
              font.family: Settings.fontFamily
              font.pixelSize: 10
              visible: parent.status === Image.Loading
            }

            SymbolicIcon {
              anchors.centerIn: parent
              path: Icons.image
              color: Settings.yellow
              implicitSize: 24
              visible: parent.status === Image.Error
            }
          }
        }
      }
    }
  }
}
