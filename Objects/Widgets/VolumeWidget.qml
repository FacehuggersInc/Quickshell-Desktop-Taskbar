import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Window

RowLayout{
    id: volumeWidget
    property var volumeState
    spacing: 0

    function getStyleFromPercentage(str){
        var num = parseInt(str)
        if (num >= 60){
            return ['#ff4a4a', "volume_max", num]
        } else if (num >= 50) {
            return [root.settings.theme.primary, "volume_max", num]
        } else if (num >= 20) {
            return [root.settings.theme.primary, "volume_med", num]
        } else {
            return ['#fffcfc', "volume_min", num]
        }
    }

    function toggleMicMute(){
        micToggleProc.running = true
        console.log(currentlyPlaying)
    }

    Process {
        id: micToggleProc
        command: root.newUtill(["--togglemic"])
        stdout: StdioCollector {
            onStreamFinished: micButton.setState(this.text)
        }
    }

    IconButton {
        id: songButton
        color: root.settings.theme.primary
        iconName: root.media.status == "Playing" ? "music_note_single" : "music_off"
        iconSize: 22
        visible: root.media.status == "Playing" ? true : (root.media.status == "Paused" ? true : false)
        tooltipText: {
            return root.media.title + " : " + root.media.artist
        }
        onClicked: toggleCommand.running = true
        Process { id: toggleCommand; command: root.cmd("media_toggle") }
    }

    IconButton {
        id: micButton
        iconName: "microphone_alert"
        iconSize: 22
        tooltipText: "Toggle Mic"

        function setState(state){
            if (state.includes("off")){
                micButton.setIcon("microphone_mute")
                micButton.setColor(root.settings.theme.primary)
                micButton.tooltipText = "Toggle Mic: On"
            } else if (state.includes("on")) { 
                micButton.setIcon("microphone")
                micButton.setColor('#ff4a4a')
                micButton.tooltipText = "Toggle Mic: Off"
            }
        }

        onClicked: toggleMicMute()
    }

    IconButton {
        id: volumeButton
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
                
                    var parts = this.text.split(",")
                    volumeState = parts
                    var volumeActive = parts[1]

                    //Volume Percentage / Color
                    if (volumeActive.includes("on")){
                        var style = getStyleFromPercentage(parts[0].replace("%", ""))
                        volumeButton.setColor(style[0])
                        volumeButton.setIcon(style[1])
                        volumeButton.text = style[2] + "%"
                    
                    //Volume Mute
                    } else {
                        volumeButton.setColor('#848484') 
                        volumeButton.setIcon("volume_mute")
                        volumeButton.text = "Mute"
                    }
      
                    micButton.setState(parts[3])

                    popup.updateSliderInfo(true)
                }
            }
        }

        AudioManagementPopup{
            id: popup
        }
        
        onClicked: popup.toggle(volumeWidget)

    }
}


