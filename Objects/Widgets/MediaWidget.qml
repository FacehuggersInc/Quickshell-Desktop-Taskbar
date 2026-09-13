import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Theme

// Now playing, with transport controls. Was a single icon button inside the
// volume widget that could only toggle.
Item {
    id: mediaWidget

    readonly property bool playing: root.media && root.media.status === "Playing"
    readonly property bool paused: root.media && root.media.status === "Paused"
    readonly property bool active: mediaWidget.playing || mediaWidget.paused

    readonly property string title: root.media && root.media.title ? root.media.title : ""
    readonly property string artist: root.media && root.media.artist ? root.media.artist : ""

    // Title scrolling would fight the bar's width animation, so it elides
    property int titleWidth: 120
    property bool showTitle: true

    visible: mediaWidget.active
    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(22, row.implicitHeight)

    Process { id: mediaToggle; command: root.cmd("media_toggle") }
    Process { id: mediaNext; command: root.cmd("media_next") }
    Process { id: mediaPrev; command: root.cmd("media_previous") }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        IconButton {
            iconName: "music_prev"
            iconSize: 16
            color: Theme.textDim
            tooltipText: "Previous"
            onClicked: mediaPrev.running = true
        }

        IconButton {
            iconName: mediaWidget.playing ? "music_pause" : "music_play"
            iconSize: 20
            color: Theme.accentIcon
            tooltipText: mediaWidget.playing ? "Pause" : "Play"
            onClicked: mediaToggle.running = true
        }

        IconButton {
            iconName: "music_skip"
            iconSize: 16
            color: Theme.textDim
            tooltipText: "Next"
            onClicked: mediaNext.running = true
        }

        ColumnLayout {
            Layout.leftMargin: 2
            Layout.preferredWidth: mediaWidget.titleWidth
            Layout.maximumWidth: mediaWidget.titleWidth
            spacing: 0
            visible: mediaWidget.showTitle && mediaWidget.title !== ""

            // Scrolled rather than elided — a cut title usually loses the part
            // that tells you what it is
            ScrollingText {
                Layout.fillWidth: true
                text: mediaWidget.title
                color: Theme.text
                pixelSize: Theme.descSize
                weight: 600
            }

            ScrollingText {
                Layout.fillWidth: true
                visible: mediaWidget.artist !== ""
                text: mediaWidget.artist
                color: Theme.textMute
                pixelSize: 9
                weight: 500
            }
        }
    }
}
