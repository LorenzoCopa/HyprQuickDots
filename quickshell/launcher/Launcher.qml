// ─── Launcher principal de Quickshell ──────────────────────────────
// Ventana flotante que es SOLO un buscador: al abrirla solo se ve la
// barra de búsqueda; los resultados aparecen y se filtran conforme se
// escribe, y el recuadro crece/encoge según los resultados (dinámico,
// sin recuadro gigante vacío). Desde aquí se puede abrir el navegador
// de aplicaciones (AppBrowser) buscando "Aplicaciones". El reloj ya no
// vive aquí: se movió al QuickAccess (SUPER+B).

pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Wayland._BackgroundEffect
import QtQuick
import "../config"

// ─── Ventana flotante del launcher ────────────────────────────────
FloatingWindow {
    id: launcher
    color: "transparent"
    implicitHeight: 580   // fijo; el recuadro crece dentro, la lista no se corta
    title: "qs-launcher"
    visible: false

    // Blur del fondo SOLO tras el listado de resultados (protocolo
    // ext-background-effect-v1). El resto de la ventana sigue sin blur
    // gracias a la regla `no_blur` de Hyprland.
    BackgroundEffect.blurRegion: launcherBlur

    Region {
        id: launcherBlur
        item: listBackdrop
    }

    // El ancho se calcula ANTES de abrir (Quickshell no re-dimensiona
    // ventanas flotantes mientras están visibles).
    function updateWidth(): void {
        launcher.implicitWidth = launcher.searchWidth;
    }

    // ── Métricas del layout ─────────────────────────────────────
    readonly property int searchWidth: 300       // ancho del buscador (fino)
    readonly property int inputHeight: 34        // alto de la barra de búsqueda
    readonly property int rowHeight: 46          // 44 alto + 2 spacing
    readonly property int maxRows: 8              // máx. resultados visibles
    readonly property int contentSpacing: 6

    // Alto máximo del listado bajo la barra fija: si hay más resultados,
    // el ListView scrollea en vez de recentrar (eso provocaba el "salto").
    readonly property int maxListHeight: Math.max(0, Math.floor(launcher.height / 2 - launcher.inputHeight / 2 - launcher.contentSpacing - 12))

    // ── Alto del recuadro visible según los resultados ──────────
    function visibleListHeight(): int {
        if (searchInput.text.length === 0)
            return 0;
        const n = appList.count;
        if (n <= 0)
            return 0;
        return Math.min(n, maxRows) * rowHeight;
    }

    // ── Lanza la aplicación actualmente seleccionada ────────────
    function launchSelection(): void {
        if (!launcher.visible)
            return;
        const idx = appList.currentIndex;
        if (idx < 0)
            return;
        const entry = filteredModel.values[idx];
        if (entry) {
            entry.execute();
            launcher.visible = false;
        }
    }

    // ── Comunicación IPC: activa/desactiva el launcher ─────────
    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (!launcher.visible) {
                launcher.updateWidth();
                searchInput.text = "";
                launcher.visible = true;
                Qt.callLater(() => searchInput.forceActiveFocus());
            } else {
                launcher.visible = false;
            }
        }
        function hide(): void { launcher.visible = false; }
    }

    // ── Captura el foco para que el launcher no se cierre solo ──
    HyprlandFocusGrab {
        windows: [launcher]
        active: launcher.visible && !Settings.captureActive
        onCleared: launcher.visible = false
    }

    // El preview de captura se pinnea por encima (juegos fullscreen); al abrir
    // el launcher lo bajamos para poder lanzar apps y lo volvemos a pinner al
    // cerrar. (Settings.screenshotManager viene de shell.qml.)
    onVisibleChanged: {
        if (launcher.visible) {
            if (Settings.screenshotManager) Settings.screenshotManager.suspendPin();
        } else {
            if (Settings.screenshotManager) Settings.screenshotManager.resumePin();
        }
    }

    // Sobre un juego fullscreen el foco inicial puede quedarse en el juego
    // (constraint del puntero); pedirlo por dispatcher rompe el bloqueo.
    SelfFocus {
        targetTitle: "qs-launcher"
        active: launcher.visible
    }

    // ─── Buscador, centrado y un poco más arriba ─────────────────
    // La BARRA queda fija un poco por encima del centro de la ventana
    // (verticalCenterOffset) y la lista aparece siempre por debajo. El
    // alto del bloque no cambia: la lista crece hacia abajo y, si
    // excede maxListHeight, scrollea.
    Item {
        id: searchBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -100
        width: launcher.searchWidth
        height: inputHeight

        Column {
            anchors.fill: parent
            spacing: contentSpacing

            // ── Barra de búsqueda ───────────────────────────────
            Rectangle {
                width: parent.width
                height: inputHeight
                radius: 10
                color: Settings.bg
                border {
                    width: 1
                    color: Settings.surface
                }

                // Lupa (icono de búsqueda) a la izquierda.
                SymbolicIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    path: Icons.search
                    color: Settings.subtext0
                    implicitSize: 16
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 34
                    verticalAlignment: Text.AlignVCenter
                    color: Settings.subtext0
                    font.family: Settings.fontFamily
                    font.weight: Font.Medium
                    font.pixelSize: 15
                    text: "Buscar aplicaciones..."
                    visible: searchInput.text.length === 0
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 34
                    verticalAlignment: TextInput.AlignVCenter
                    color: Settings.fg
                    font.family: Settings.fontFamily
                    font.weight: Font.Medium
                    font.pixelSize: 15

                    Keys.onEscapePressed: launcher.visible = false
                    Keys.onReturnPressed: launcher.launchSelection()
                    Keys.onUpPressed: appList.decrementCurrentIndex()
                    Keys.onDownPressed: appList.incrementCurrentIndex()
                    Keys.onPressed: event => {
                        if (event.modifiers & Qt.ControlModifier) {
                            if (event.key === Qt.Key_P) {
                                appList.decrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_N) {
                                appList.incrementCurrentIndex();
                                event.accepted = true;
                            }
                        }
                    }
                }
            }
        }

        // ── Panel del listado (blur + fondo oscuro) ───────────
        // Solo aparece al escribir; el fondo tras él se desenfoca
        // (BackgroundEffect.blurRegion) y se oscurece para leer bien
        // los iconos y nombres.
        Rectangle {
            id: listBackdrop
            visible: launcher.visibleListHeight() > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: searchBox.bottom
            anchors.topMargin: contentSpacing
            width: parent.width
            height: Math.min(launcher.visibleListHeight(), launcher.maxListHeight)
            radius: 12
            color: Settings.bg
            border {
                width: 1
                color: Settings.surface
            }
            clip: true

            // ── Lista de resultados (solo si se escribe) ─────────
            ListView {
                id: appList
                anchors.fill: parent
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                // ── Modelo: filtra por búsqueda (vacío = vacío) ──
                model: ScriptModel {
                    id: filteredModel
                    objectProp: "id"
                    values: {
                        const q = searchInput.text.toLowerCase();
                        return q
                            ? DesktopEntries.applications.values.filter(app =>
                                app.name.toLowerCase().includes(q) ||
                                (app.genericName && app.genericName.toLowerCase().includes(q))
                            )
                            : [];
                    }
                    onValuesChanged: appList.currentIndex = 0
                }

                // ── Cada elemento de la lista ─────────────────────
                delegate: Rectangle {
                    id: delegate
                    required property int index
                    required property var modelData

                    width: appList.width
                    height: 44
                    radius: 10
                    color: appList.currentIndex === delegate.index ? Settings.selectionBg : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            width: 34
                            height: 34
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 8
                            color: Settings.surface

                            IconImage {
                                id: listIcon
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                source: Quickshell.iconPath(delegate.modelData.icon, true)
                                visible: status === Image.Ready
                            }

                            // Respaldo: si la entrada no trae icono, se
                            // muestra un glifo genérico para que la fila
                            // no quede vacía.
                            SymbolicIcon {
                                anchors.centerIn: parent
                                path: Icons.glyphForClass(delegate.modelData.name)
                                color: Settings.accent
                                implicitSize: 18
                                visible: !listIcon.visible
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: delegate.modelData.name
                                color: Settings.fg
                                font.family: Settings.fontFamily
                                font.weight: Font.DemiBold
                                font.pixelSize: 14
                                elide: Text.ElideRight
                            }

                            Text {
                                text: delegate.modelData.genericName || ""
                                color: appList.currentIndex === index ? Settings.fg : Settings.subtext0
                                font.family: Settings.fontFamily
                                font.weight: Font.Normal
                                font.pixelSize: 12
                                visible: text !== ""
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: appList.currentIndex = index
                        onClicked: {
                            delegate.modelData.execute();
                            launcher.visible = false;
                        }
                    }
                }
            }
        }
    }
}
