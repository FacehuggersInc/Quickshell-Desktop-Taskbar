//@ pragma UseQApplication
//@ pragma IconTheme material-symbols

import QtQuick
import Quickshell
import Quickshell.Io

import Quickshell.Services.Notifications

import qs.Objects.Window
import qs.Objects.Systems

ShellRoot {
    // INIT
    id: root

    FileView {
        id: configFile
        preload: true
        blockLoading: true
        path: Qt.resolvedUrl("./config.json")
        watchChanges: true
        onFileChanged: this.reload()
        onAdapterUpdated: this.writeAdapter()
    }
    property var settings: JSON.parse(configFile.text()) 
    property var utill: ["python3", "/home/fach/.config/quickshell/Scripts/utill.py"]
    property bool initialDarkHourCheck: false
    property var monitorResolutions: ({})  // name -> {w, h}
    property var ddcMap: ({})              // connector name -> DDC display number
    property var monitorInfos: []          // full monitor info sorted left-to-right

    // ── Startup batch — replaces separate monitorResProc, detectDisplaysProc, ddcMappingProc
    Process {
        id: startupBatchProc
        command: root.newBatch([
            ["getmonitorres"],
            ["getdisplays"],
            ["ddcmapping"]
        ])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var results = root.parseBatch(this.text)

                // getmonitorres
                if (results["getmonitorres"]) {
                    var res = {}
                    results["getmonitorres"].split("|").forEach(function(entry) {
                        var parts = entry.split(":")
                        if (parts.length >= 3)
                            res[parts[0]] = { w: parseInt(parts[1]), h: parseInt(parts[2]) }
                    })
                    root.monitorResolutions = res
                }

                // getdisplays
                if (results["getdisplays"] && results["getdisplays"] !== "none") {
                    var names = []
                    var infos = []
                    var focusedIdx = 0
                    results["getdisplays"].split("\n").forEach(function(line, i) {
                        var parts = line.split("|")
                        if (parts.length < 7) return
                        names.push(parts[0])
                        infos.push({
                            name: parts[0], w: parseInt(parts[1]), h: parseInt(parts[2]),
                            x: parseInt(parts[3]), y: parseInt(parts[4]),
                            focused: parts[5] === "yes", transform: parseInt(parts[6])
                        })
                        if (parts[5] === "yes") focusedIdx = i
                    })
                    root.monitorInfos = infos

                    var current = root.settings.displays || []
                    var changed = names.length !== current.length
                    if (!changed) {
                        for (var j = 0; j < names.length; j++) {
                            if (names[j] !== current[j]) { changed = true; break }
                        }
                    }
                    if (changed) {
                        root.settings.displays = names
                        if (root.settings.primaryDisplayIndex === undefined
                                || root.settings.primaryDisplayIndex === null) {
                            root.settings.primaryDisplayIndex = focusedIdx
                        }
                        root.saveSettings()
                    }
                }

                // ddcmapping
                if (results["ddcmapping"] && results["ddcmapping"] !== "none") {
                    var map = {}
                    results["ddcmapping"].split("|").forEach(function(entry) {
                        var parts = entry.split(":")
                        if (parts.length >= 2) map[parts[0]] = parseInt(parts[1])
                    })
                    root.ddcMap = map
                }
            }
        }
    }

    // Theater mode
    property bool theaterMode: false
    property var theaterPrevBrightness: []

    // Reads current brightness before dimming for theater mode restore
    Process {
        id: theaterBrightnessProc
        command: root.newUtill(["--ddcgetbrightness"])
        property int pendingDim: 10
        property int pendingPrimary: 0
        property string pendingWallpaper: ""
        stdout: StdioCollector {
            onStreamFinished: {
                // Parse current brightness values
                var displays = this.text.trim().split("|")
                var vals = []
                for (var i = 0; i < displays.length; i++) {
                    var parts = displays[i].split(":")
                    if (parts.length < 3) { vals.push(50); continue }
                    var cur = parseInt(parts[1])
                    var max = parseInt(parts[2])
                    vals.push(max > 0 ? Math.round((cur / max) * 100) : 50)
                }
                root.theaterPrevBrightness = vals

                // pendingPrimary -1 means read-only — just store values, don't dim
                if (theaterBrightnessProc.pendingPrimary === -1) return

                var primary = theaterBrightnessProc.pendingPrimary
                var dim     = theaterBrightnessProc.pendingDim
                var wp      = theaterBrightnessProc.pendingWallpaper

                var rawCmd = (root.settings.commands && root.settings.commands.wallpaper_set)
                    || "awww img -o {display} {wallpaper}"

                for (var j = 0; j < root.settings.displays.length; j++) {
                    if (j !== primary) {
                        var connector = root.settings.displays[j]
                        var ddcNum = root.ddcMap[connector] || (j + 1)
                        root.execute(root.newUtill(["--ddcsetbrightness", ddcNum, dim]))
                        if (wp !== "") {
                            var wallpaperCmd = rawCmd
                                .replace("{display}", connector)
                                .replace("{wallpaper}", wp)
                            root.execute(wallpaperCmd.split(" "))
                        }
                    }
                }

                root.theaterMode = true
                root.settings.theater.enabled = true
                // Stop wallpaper cycling while theater is active
                wallpaperSwitchTimer.running = false
                root.saveSettings()
            }
        }
    }

    function setTheaterMode(on) {
        var theater = settings.theater || {}
        var primary = (theater.primaryDisplay !== undefined && theater.primaryDisplay !== null)
            ? theater.primaryDisplay
            : (settings.primaryDisplayIndex || 0)
        var dimBrightness  = theater.dimBrightness !== undefined ? theater.dimBrightness : 10
        var theaterWallpaper = theater.wallpaper || ""

        if (on) {
            // Read current brightness first, then dim in the proc callback
            theaterBrightnessProc.pendingDim      = dimBrightness
            theaterBrightnessProc.pendingPrimary  = primary
            theaterBrightnessProc.pendingWallpaper = theaterWallpaper
            theaterBrightnessProc.running = true
        } else {
            // Restore brightness on non-primary displays using correct DDC numbers
            for (var k = 0; k < settings.displays.length; k++) {
                if (k !== primary) {
                    var restoreConnector = settings.displays[k]
                    var restoreDdc = root.ddcMap[restoreConnector] || (k + 1)
                    root.execute(root.newUtill(["--ddcsetbrightness", restoreDdc, theaterPrevBrightness[k] || 50]))
                }
            }
            root.nextWallpaper()
            // Resume cycling if it was enabled
            if (root.settings.wallpapers.cycling !== false) {
                wallpaperSwitchTimer.running = true
            }
            theaterMode = false
            settings.theater = settings.theater || {}
            settings.theater.enabled = false
            root.saveSettings()
        }
    }

    Component.onCompleted: {
        // Reset theater mode if it was left on from previous session
        var theater = settings.theater || {}
        if (theater.enabled === true) {
            settings.theater.enabled = false
            root.saveSettings()
            // Restore cycling if it should be running
            if (root.settings.wallpapers.cycling !== false) {
                wallpaperSwitchTimer.running = true
            }
            // Re-fetch brightness so sliders reflect actual state after reset
            theaterBrightnessProc.pendingDim       = 100  // restore all to full
            theaterBrightnessProc.pendingPrimary   = -1   // -1 = skip dimming, just read
            theaterBrightnessProc.pendingWallpaper = ""
            theaterBrightnessProc.running = true
        }
    }

    // wallpaperMode: 0=auto (follow dark hours), 1=force day, 2=force night
    property int wallpaperMode: root.settings.wallpapers.wallpaperMode || 0


    // FUNCTIONS
    function notify(title, body, icon){
        if (icon){
            notifyServer.iconName = icon
        } else {
            notifyServer.iconName = "notify"
        }
        
        root.execute(["notify-send", title, body])
    }

    function saveSettings(){
        configFile.setText( JSON.stringify( settings, null, 4 ) )
    }

    // cmd() — look up a command by key and return as args array
    // Supports:
    //   {placeholder}   — replaced by value in replacements object
    //   {v-varname}     — replaced by value in settings.variables
    // Shell pipelines (bash -c "...") are handled by wrapping in bash -c automatically
    function cmd(key, replacements) {
        var command = settings.commands[key]
        if (!command) {
            console.log("cmd: unknown key '" + key + "'")
            return []
        }

        // 1. Substitute {v-varname} from settings.variables
        var vars = settings.variables || {}
        command = command.replace(/\{v-([^}]+)\}/g, function(match, varname) {
            return vars[varname] !== undefined ? vars[varname] : match
        })

        // 2. Substitute {placeholder} from caller replacements
        if (replacements) {
            for (var k in replacements) {
                command = command.replace("{" + k + "}", replacements[k])
            }
        }

        // 3. Smart split — if command contains shell operators (&&, ||, |, ;, >)
        //    wrap in bash -c "..." so the shell can evaluate them
        var shellOps = /&&|\|\||[|;&>]/
        if (shellOps.test(command)) {
            return ["bash", "-c", command]
        }

        // 4. Split respecting single and double quoted strings
        var args = []
        var current = ""
        var inSingle = false
        var inDouble = false
        for (var i = 0; i < command.length; i++) {
            var c = command[i]
            if (c === "'" && !inDouble) {
                inSingle = !inSingle
            } else if (c === '"' && !inSingle) {
                inDouble = !inDouble
            } else if (c === " " && !inSingle && !inDouble) {
                if (current.length > 0) { args.push(current); current = "" }
            } else {
                current += c
            }
        }
        if (current.length > 0) args.push(current)
        return args
    }

    // cmdDesc() — get a truncated command string for display in UI
    function cmdDesc(key, maxLen) {
        var command = settings.commands[key] || ""
        var limit = maxLen || 32
        return command.length > limit ? command.substring(0, limit) + "…" : command
    }

    // cmdExec() — look up and immediately execute
    function cmdExec(key, replacements) {
        var args = root.cmd(key, replacements)
        if (args.length > 0) execute(args)
    }

    function copy(text){
        Quickshell.clipboardText = text
    }

    function execute(args){
        var commandArgs = args
        // Only split if a single string was passed (legacy convenience)
        // Never split if multiple args given — paths can contain spaces
        if (commandArgs.length === 1 && typeof commandArgs[0] === "string") {
            if (!commandArgs[0].startsWith("/") && commandArgs[0].includes(" ")){
                commandArgs = args[0].split(" ")
            }
        }
        console.log("Executing -> " + commandArgs)
        Quickshell.execDetached({ command: commandArgs })
    }

    function copyArray(array){
        var newArray = [];
        for (var i = 0; i < array.length; i++){
            newArray.push(array[i]);
        }
        return newArray;
    }

    function combine(listA, listB){
        var newList = copyArray(listA);
        for (var i = 0; i < listB.length; i++){
            newList.push(listB[i]);
        }
        return newList;
    }

    function newUtill(args){
        return combine(root.utill, args);
    }

    function newBatch(commands) {
        // commands: [["funcname", arg1, arg2], ["funcname2"]]
        // Returns: combine(utill, ["--batch", "-funcname", arg1, "-funcname2"])
        var batchArgs = ["--batch"]
        for (var i = 0; i < commands.length; i++) {
            var parts = commands[i]
            batchArgs.push("-" + parts[0])
            for (var j = 1; j < parts.length; j++) {
                batchArgs.push(String(parts[j]))
            }
        }
        return combine(root.utill, batchArgs)
    }

    // parseBatch() — parse batch result into a map of {funcname: result}
    function parseBatch(text) {
        var map = {}
        var lines = text.trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
            var idx = lines[i].indexOf(":")
            if (idx === -1) continue
            var key = lines[i].substring(0, idx)
            var val = lines[i].substring(idx + 1)
            map[key] = val
        }
        return map
    }



    function iconSource(name){
        return settings.iconsPath + name + ".png"
    }

    function setWallpaperInterval(ms) {
        root.settings.wallpapers.interval = ms
        wallpaperSwitchTimer.interval = ms
        root.saveSettings()
    }

    function nextWallpaper(){
        wallpaperSwitchTimer.restart()
        checkDarkHour()
    }

    function checkDarkHour(){ 
        // Do nothing if wallpaper cycling is disabled
        if (!settings.wallpapers.cycling) return

        if (!initialDarkHourCheck) {
            wallpaperSwitchTimer.interval = settings.wallpapers.interval
            initialDarkHourCheck = true 
        }

        // wallpaperMode overrides the hour check
        if (root.wallpaperMode === 1) {
            wallpaperRandomChoice.wallpaperFolder = settings.wallpapers.day
            wallpaperRandomChoice.running = true
            return
        }
        if (root.wallpaperMode === 2) {
            wallpaperRandomChoice.wallpaperFolder = settings.wallpapers.night
            wallpaperRandomChoice.running = true
            return
        }

        var hour = new Date().getHours()
        if (hour >= settings.wallpapers.darkModeHours.at || hour < settings.wallpapers.darkModeHours.before){
            wallpaperRandomChoice.wallpaperFolder = settings.wallpapers.night
        } else {
            wallpaperRandomChoice.wallpaperFolder = settings.wallpapers.day
        }
        wallpaperRandomChoice.running = true
    }

    function wallColors(){
        return wallpaperColors.colors
    }

    function wallColorsLen(){
        return wallpaperColors.colors.length
    }


    // GLOBAL OBJECTS

    // -- NOTIFICATIONS
    property NotificationServer notifyServer: NotificationServer {
        id: notifyServer
        keepOnReload: true 
        bodySupported: true
        imageSupported: true
        actionsSupported: true

        property string iconName: "notify"
    }

    // -- USB HOTPLUG WATCHER
    property string usbLastMountpoint: ""
    property string usbLastLabel: ""

    // Python handles the full check: finds mountpoint, label, sends notification
    // Returns: "mountpoint|label" on success, "none" if not mounted yet
    Process {
        id: usbMountCheckProc
        property string pendingDevice: ""
        property int retryCount: 0

        function checkDevice(devName) {
            pendingDevice = devName
            retryCount    = 0
            command = root.newUtill(["--usbmountcheck", devName])
            running = true
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var result = this.text.trim()
                console.log("USB mount check result: " + result)

                if (result === "none" || result === "") {
                    // Not mounted yet — retry up to 3 times
                    if (usbMountCheckProc.retryCount < 3) {
                        usbMountCheckProc.retryCount++
                        usbRetryTimer.restart()
                    }
                    return
                }

                var parts = result.split("|")
                var mountpoint = parts[0]
                var label      = parts.length > 1 ? parts[1] : "USB Drive"

                root.usbLastMountpoint = mountpoint
                root.usbLastLabel      = label

                root.execute([
                    "notify-send",
                    "--app-name=USB",
                    "--action=open=Open in Files",
                    "--urgency=normal",
                    "USB Drive Connected",
                    label + " mounted at " + mountpoint
                ])
            }
        }
    }

    Timer {
        id: usbRetryTimer
        interval: 1500
        repeat: false
        onTriggered: {
            var dev = usbMountCheckProc.pendingDevice
            if (dev !== "") {
                usbMountCheckProc.command = root.newUtill(["--usbmountcheck", dev])
                usbMountCheckProc.running = true
            }
        }
    }

    // Permanent udevadm monitor — SplitParser fires onRead per line instantly
    Process {
        id: usbWatcher
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block"]
        running: true
        onRunningChanged: if (!running) running = true

        stdout: SplitParser {
            onRead: function(line) {
                line = line.trim()
                console.log("udevadm: " + line)

                if (!line.includes(" add ")) return

                var match = line.match(/add\s+(\S+)\s+\(block\)/)
                if (!match) return

                var devName = match[1].split("/").pop()
                console.log("USB device detected: " + devName)

                if (devName.startsWith("loop")) return
                if (devName.startsWith("dm-"))  return
                if (!/\d$/.test(devName)) return

                console.log("USB partition detected: " + devName)
                usbMountInitTimer.devName = devName
                usbMountInitTimer.restart()
            }
        }
    }

    Timer {
        id: usbMountInitTimer
        interval: 1500
        repeat: false
        property string devName: ""
        onTriggered: {
            console.log("Checking mount for: " + devName)
            if (devName !== "") usbMountCheckProc.checkDevice(devName)
        }
    }

    // USB action handled directly in Notification.qml via root.usbLastMountpoint
    
    // -- MEDIA
    property MediaSystem media: MediaSystem{
        id: mediaSystem
    }

    // Temp file cleanup after smart crop wallpaper is set
    Timer {
        id: cleanupTimer
        interval: 3000
        repeat: false
        property string tempFile: ""
        onTriggered: {
            if (tempFile !== "") {
                root.execute(["rm", "-f", tempFile])
                tempFile = ""
            }
        }
    }

    // Smart crop process — handles vertical monitor wallpapers
    Process {
        id: smartCropProc
        property string wallpaper: ""
        property int    monW: 0
        property int    monH: 0
        property string displayName: ""
        property string rawCommand: ""
        property string lastTempFile: ""

        command: root.newUtill(["--smartcrop", wallpaper, monW, monH])

        stdout: StdioCollector {
            onStreamFinished: {
                var result = this.text.trim()
                if (!result) return

                // Clean up previous temp file
                if (smartCropProc.lastTempFile !== ""
                        && smartCropProc.lastTempFile !== smartCropProc.wallpaper) {
                    root.execute(["rm", "-f", smartCropProc.lastTempFile])
                }

                smartCropProc.lastTempFile = result

                // Set the wallpaper with cropped (or original) path
                var cmd = smartCropProc.rawCommand
                    .replace("{wallpaper}", result)
                root.execute(cmd.split(" "))
                // Clean up temp file after a short delay
                if (result !== smartCropProc.wallpaper) {
                    cleanupTimer.tempFile = result
                    cleanupTimer.restart()
                }
            }
        }
    }

    // Portrait wallpaper proc — picks and sets a wallpaper from the portrait folder
    Process {
        id: portraitWallpaperProc
        property string display: ""
        property int    displayIdx: 0
        property string rawCmd: ""

        stdout: StdioCollector {
            onStreamFinished: {
                var wallpaper = this.text.trim().split(",")[0].trim()
                if (!wallpaper) return

                var finalWallpaper = wallpaper

                // Apply smart crop if enabled
                if (root.settings.wallpapers.smartCrop) {
                    var monRes = root.monitorResolutions[portraitWallpaperProc.display]
                    if (monRes && monRes.h > monRes.w) {
                        smartCropProc.wallpaper   = wallpaper
                        smartCropProc.monW        = monRes.w
                        smartCropProc.monH        = monRes.h
                        smartCropProc.displayName = portraitWallpaperProc.display
                        smartCropProc.rawCommand  = portraitWallpaperProc.rawCmd
                        smartCropProc.running     = true
                        return
                    }
                }

                var cmd = portraitWallpaperProc.rawCmd.replace("{wallpaper}", finalWallpaper)
                root.execute(cmd.split(" "))
            }
        }
    }

    // -- THEME
    Timer{
        id: themeCheckTimer
        interval: 100
        running: false
        repeat: true
        onTriggered:{
            // Only generate theme if autoTheme is enabled
            if (!root.settings.wallpapers.autoTheme) {
                themeCheckTimer.running = false
                return
            }
            if (colorQuan.colors.length > 0){
                var themeCommand = combine( newUtill(["--generatetheme", "dark"]), root.wallpaperColors.colors )
                themeGenerator.command = themeCommand
                themeGenerator.running = true
                themeCheckTimer.repeat = false
                themeCheckTimer.running = false
            } 
        }
    }
    Process{
        id:themeGenerator
        command: newUtill(["--generatetheme", "dark"])
        stdout : StdioCollector {
            onStreamFinished: {
                var theme = {"mode":"dark"}
                var obj = this.text.trim()
                if (!obj) { return }
                var pairs = obj.split(",")
                for (var i = 0; i < pairs.length; i++){
                    var pair = pairs[i].split(":")
                    theme[pair[0]] = pair[1]
                }

                settings.theme = theme

                saveSettings()
            }
        }
    }

    // -- WALLPAPERS
    property ColorQuantizer wallpaperColors: ColorQuantizer{
        id: colorQuan
        depth: 3
        rescaleSize: 256
    }
    Timer{
        id: wallpaperSwitchTimer
        interval: 100 //Gets Altered in checkDarkHour
        running: root.settings.wallpapers.cycling !== false  // default true if key absent
        repeat: true
        onTriggered: checkDarkHour()
    }
    Process{
        id: wallpaperRandomChoice
        property string wallpaperFolder: settings.wallpapers.day; 
        property int wallpapersToGet: settings.wallpapers.randomWallpaperPerDisplay ? settings.displays.length : 1
        command: newUtill( ["--randomfile", wallpaperRandomChoice.wallpaperFolder, wallpaperRandomChoice.wallpapersToGet] )
        stdout : StdioCollector {
            onStreamFinished: {
                
                var wallpapers = this.text.split(",")
                var rawCommand = (settings.commands && settings.commands.wallpaper_set)
                    || settings.wallpapers.setWallpaperCommand
                    || "awww img -o {display} {wallpaper}"
                var setWallpaperCommand = rawCommand
                for (var i = 0; i < settings.displays.length; i++) {
                    setWallpaperCommand = rawCommand
                    
                    setWallpaperCommand = setWallpaperCommand.replace( "{display}", settings.displays[i] )

                    var wallpaper = null
                    if (settings.wallpapers.randomWallpaperPerDisplay) {
                        wallpaper = wallpapers[i].trim()
                    } else {
                        wallpaper = wallpapers[0].trim()
                    }

                    // Portrait monitor — use portrait wallpaper folder if configured
                    var monRes = root.monitorResolutions[settings.displays[i]]
                    if (monRes && monRes.h > monRes.w
                            && settings.wallpapers.randomWallpaperPerDisplay
                            && settings.wallpapers.portraitFolder) {
                        portraitWallpaperProc.display    = settings.displays[i]
                        portraitWallpaperProc.displayIdx = i
                        portraitWallpaperProc.rawCmd     = rawCommand.replace("{display}", settings.displays[i])
                        portraitWallpaperProc.command    = root.newUtill(["--randomfile", settings.wallpapers.portraitFolder])
                        portraitWallpaperProc.running    = true
                        continue  // handled by portraitWallpaperProc
                    }

                    // Smart crop for vertical monitors if setting enabled
                    var finalWallpaper = wallpaper
                    if (settings.wallpapers.smartCrop) {
                        var displayName = settings.displays[i]
                        var monRes = root.monitorResolutions[displayName]
                        if (monRes && monRes.h > monRes.w) {
                            // Vertical monitor — run smartcrop synchronously via proc
                            // We use a blocking call pattern here by launching the command
                            // and substituting inline. Since execDetached is async we
                            // store the crop path and use it in a separate proc.
                            smartCropProc.wallpaper   = wallpaper
                            smartCropProc.monW        = monRes.w
                            smartCropProc.monH        = monRes.h
                            smartCropProc.displayName = displayName
                            smartCropProc.rawCommand  = setWallpaperCommand
                                .replace("{display}", settings.displays[i])
                            smartCropProc.running     = true
                            continue  // handled by smartCropProc
                        }
                    }

                    var wallpaperCmd = setWallpaperCommand
                        .replace("{display}", settings.displays[i])
                        .replace("{wallpaper}", finalWallpaper)
                    execute( wallpaperCmd.split(" ") )
                }
                
                root.wallpaperColors.source = Qt.resolvedUrl(wallpapers[settings.primaryDisplayIndex].trim())
                themeCheckTimer.repeat = true
                themeCheckTimer.running = true
            }
        }
    }

    // -- UI OBJECTS
    property MainWindow main: MainWindow {}
}