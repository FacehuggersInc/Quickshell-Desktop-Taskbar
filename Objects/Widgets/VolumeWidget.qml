import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Theme
import qs.Objects.Widgets.Internal
import qs.Objects.Window

RowLayout{
    id: volumeWidget
    Component.onCompleted: root.volumeWidget = volumeWidget
    property var volumeState

    // Read by the quick panel, which should not have to open the popup to learn
    // what the volume is
    property int volumeLevel: 0
    property bool volumeMuted: false

    // "icon" is the plain glyph, "text" adds the percentage, "dots" draws it
    // in the same matrix the clock uses, "meter" shows it as rising bars
    readonly property bool showIcon: {
        var bump = root.settingsRevision
        var widgets = root.settings.widgets || ({})
        return widgets.volumeIcon !== false
    }

    readonly property string style: {
        var bump = root.settingsRevision
        var widgets = root.settings.widgets || ({})
        return widgets.volumeStyle ? widgets.volumeStyle : "text"
    }
    spacing: 0

    function getStyleFromPercentage(str){
        var num = parseInt(str)
        if (num >= 60){
            return ['#ff4a4a', "volume_max", num]
        } else if (num >= 50) {
            return [root.theme.primary, "volume_max", num]
        } else if (num >= 20) {
            return [root.theme.primary, "volume_med", num]
        } else {
            return ['#fffcfc', "volume_min", num]
        }
    }

    IconButton {
        id: volumeButton
        visible: volumeWidget.showIcon || volumeWidget.style === "text"
        iconName: "volume_max"
        iconSize: 30
        tooltipText: "Volume Control"
        
        font.family: root.settings.fontFamily
        font.weight: 500
        font.pixelSize: 18

        Timer {
            interval: 300
            running: true
            repeat: true
            onTriggered: volumeProc.running = true
        }
        Process {
            id: volumeProc
            command: root.newUtill( ["--getaudio"] )
            running: true

            stdout: StdioCollector {
                onStreamFinished: {
                
                    // A short or empty reply used to throw on parts[1]. The
                    // reader can return nothing when the audio stack is not
                    // answering, and that is not an error worth a stack trace.
                    var parts = this.text.trim().split(",")
                    while (parts.length < 4)
                        parts.push("")

                    volumeState = parts
                    var volumeActive = String(parts[1] || "")
                    var volumeText = String(parts[0] || "")

                    //Volume Percentage / Color
                    volumeWidget.volumeLevel = parseInt(volumeText.replace("%", "")) || 0
                    volumeWidget.volumeMuted = volumeActive.indexOf("on") === -1

                    if (volumeActive.indexOf("on") !== -1){
                        var look = getStyleFromPercentage(volumeText.replace("%", ""))
                        volumeButton.setColor(look[0])
                        volumeButton.setIcon(look[1])
                        volumeButton.text = volumeWidget.style === "text"
                            ? look[2] + "%" : ""
                    
                    //Volume Mute
                    } else {
                        volumeButton.setColor(Theme.textMute)
                        volumeButton.setIcon("volume_mute")
                        volumeButton.text = volumeWidget.style === "text" ? "Mute" : ""
                    }
      
                    if (root.audioPopup) root.audioPopup.updateSliderInfo(true)
                }
            }
        }

        onClicked: {
            if (root.audioPopup) root.audioPopup.toggle(volumeWidget)
        }

    }

    LevelMeter {
        Layout.alignment: Qt.AlignVCenter
        visible: volumeWidget.style === "meter"
        level: volumeWidget.volumeLevel / 100
        muted: volumeWidget.volumeMuted
    }

    DotMatrix {
        Layout.alignment: Qt.AlignVCenter
        visible: volumeWidget.style === "dots"
        text: volumeWidget.volumeMuted ? "" : String(volumeWidget.volumeLevel)
        dotSize: 2
        dotGap: 1.2
        charGap: 3
        onColor: Theme.accentText
        offColor: Theme.alpha(Theme.textBase, 0.07)
    }
}


