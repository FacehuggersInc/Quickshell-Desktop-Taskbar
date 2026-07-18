import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material


import qs.Objects.Window
import qs.Objects.Design
import qs.Objects.Widgets

RoundedBlock{
    id: appBarWidget

    property var contextIcon
    property var contextTarget
    property var contextPopupObject: null
    property bool addedStaticApps: false
    property ListModel apps: ListModel{}
    property var appStore: ({})

    property var queuedAppClassesForIcons: ([])

    // Drag reorder state (must live here — delegates reference appBarWidget.dragSourceIndex/Target)
    property int dragSourceIndex: -1
    property int dragTargetIndex: -1

    // Gaming mode runtime state (not saved — resets each session)
    property bool gamingAppActive: false   // true when any gaming app class is in appStore
    property bool gamingUserPaused: false  // true when user manually exited while a game runs

    // Args that are never meaningful to save as launch options —
    // typically DBus activation, daemon, or session-management flags
    // that only make sense when the desktop environment spawns the app.
    readonly property var stripArgs: [
        "--gapplication-service",
        "--gapplication-replace",
        "--daemon",
        "-d",
        "--no-desktop",
        "--session",
        "--ozone-platform-hint=auto",
        "--enable-features=WaylandWindowDecorations",
        "--started-from-file",
    ]

    // FUNCTIONS
    function encodeOptions(options) {
        try {
            return JSON.stringify(options || [])
        } catch(e) {
            return "[]"
        }
    }

    function decodeOptions(options) {
        if (!options) return []
        if (typeof options === "string") {
            try {
                return JSON.parse(options)
            } catch(e) {
                return []
            }
        }
        return options
    }

    function cleanArgs(args) {
        // Strip known bad args.
        // Also drop any arg that looks like an instance-specific path or
        // socket (e.g. /run/user/1000/..., /tmp/...) since those will
        // never be valid on a fresh launch.
        var out = []
        for (var i = 0; i < args.length; i++) {
            var a = args[i]
            if (stripArgs.indexOf(a) !== -1) continue
            if (a.startsWith("/run/") || a.startsWith("/tmp/") || a.startsWith("/proc/"))
                continue
            out.push(a)
        }
        return out
    }

    function parseCommand(fullCommand, className) {
        if (!fullCommand || fullCommand.trim() === "")
            return { command: "", options: [] }

        var tokens = fullCommand.trim().split(/\s+/)

        function isPath(t) {
            return t.indexOf("/") === 0
        }

        function isInterpreter(t) {
            return (
                t === "python" ||
                t === "python3" ||
                t === "bash" ||
                t === "sh" ||
                t === "node"
            )
        }

        if (className) {
            for (var i = 0; i < tokens.length; i++) {
                var classParts = className.toLowerCase().split(".")
                if (tokens[i].trim().includes(classParts[classParts.length - 1])) {
                    var launch = tokens[i]
                    var args = cleanArgs(tokens.slice(i + 1))
                    return {
                        command: launch,
                        options: args.length > 0 ? [args] : []
                    }
                }
            }
        }

        if (tokens.length >= 2 && isInterpreter(tokens[0]) && isPath(tokens[1])) {
            var launch = tokens[0] + " " + tokens[1]
            var args = cleanArgs(tokens.slice(2))
            return {
                command: launch,
                options: args.length > 0 ? [args] : []
            }
        }

        if (isPath(tokens[0])) {
            var launch = tokens[0]
            var args = cleanArgs(tokens.slice(1))
            return {
                command: launch,
                options: args.length > 0 ? [args] : []
            }
        }

        return {
            command: fullCommand,
            options: []
        }
    }

    function getProcessCount(name){
        return appStore[name].procs.length
    }

    function getHiddenCount(name) {
        var state = appStore[name]
        var list = state ? state.procs : []
        var count = 0

        for (var i = 0; i < list.length; i++) {
            if (list[i].workspace === "special:hidden") {
                count++
            }
        }

        return count
    }

    function getPIDs(name) {
        var state = appStore[name]
        var list = state ? state.procs : []
        return list.map(x => x.pid)
    }

    function getAppStateFromPID(pid){
        for (var name in appStore){
            var value = appStore[name]
            if (!value) continue
            for (var i=0; i < value.procs.length; i++){
                var instance = value.procs[i]
                if (instance.pid === pid){
                    return instance
                }
            }
        }
        return undefined
    }

    function isAppPinned(name){
        var pinned = false
        for (var i=0; i < root.settings.launchers.length; i++){
            var item = root.settings.launchers[i]
            if (item.name === name){
                pinned = true
                break
            }
        }
        return pinned
    }

    function clearInactiveApps(){
        for (var i = apps.count - 1; i >= 0; i--) {
            var app = apps.get(i)
            if (!app.type.includes("static") && getPIDs(app.name).length === 0) {
                apps.remove(i)
            }
        }
    }

    function getActiveApps(newDataStr){
        if (!appStore) {
            appStore = {}
        }

        var newApps = newDataStr.split("|")
        var newPIDs = []
        var newAddresses = []
        var newClasses = []
        var classes = []

        // Get Pinned Masks
        var masques = {}
        for (var i=0; i < root.settings.launchers.length; i++){
            var item = root.settings.launchers[i]
            if (item.masque){
                masques[item.name] = item.masque
            }
        }

        //Build New Instances Into AppStore
        for (var i = 0; i < newApps.length; i++){ 
            var app = newApps[i].split(",")
            if (app.length < 5) continue

            var pid = app[0]
            newPIDs.push(pid)
            var name = app[1].trim()
            classes.push(name)
            if (!appStore[name]) newClasses.push(name)
            var workspace = app[4].trim()
            var windowTitle = app[5] ? app[5].trim() : ""
            var address = app[6] ? app[6].trim() : pid
            newAddresses.push(address)

            //Masking & Reassignment
            var stateAssignmentKey = name
            for (var masqueKey in masques){
                var masque = masques[masqueKey]
                var reassign = false
                if (masque.classIncludes && name.includes(masque.classIncludes)){
                    reassign = true
                } else if (masque.cmdIncludes && app[3].includes(masque.cmdIncludes)){
                    reassign = true
                }

                if (reassign){
                    if (appStore[name]){
                        delete appStore[name]
                    }
                    if (!appStore[masqueKey]) {
                        appStore[masqueKey] = {
                            procs: []
                        }
                    }
                    stateAssignmentKey = masqueKey
                    break
                }
            }

            // Create State
            if (name === stateAssignmentKey && !appStore[name]) {
                appStore[name] = {
                    procs: []
                }
            }

            // Deduplicate by window address (not PID — one process can have many windows)
            var hasAddress = false
            for (var j=0; j < appStore[stateAssignmentKey].procs.length; j++){
                var instance = appStore[stateAssignmentKey].procs[j]
                if (instance.address === address){
                    hasAddress = true
                    instance['workspace'] = workspace
                    instance['windowTitle'] = windowTitle
                    break
                }
            }
            if (hasAddress) continue

            appStore[stateAssignmentKey].procs.push({
                pid: pid,
                address: address,
                name: name,
                windowTitle: windowTitle,
                workspace: workspace 
            })
        }

        //Remove Dead Instances from AppStore
        for (var name in appStore) {
            var instances = appStore[name].procs
            if (!instances || instances.length === 0) {
                delete appStore[name]
                continue
            }
            for (var i = instances.length - 1; i >= 0; i--) {
                var instance = instances[i]
                if (!newAddresses.includes(instance.address) || !classes.includes(instance.name)) {
                    instances.splice(i, 1)
                }
            }
            if (instances.length == 0) delete appStore[name]
        }

        //Update Pinned UI State Data
        for (var j=0; j < apps.count; j++){
            var app = apps.get(j)
            if (isAppPinned(app.name)){
                var instances = appStore[app.name] ? appStore[app.name].procs : []
                var hidden = getHiddenCount(app.name)
                var state = "static"
                if (instances.length === 1) state = "static|active"
                else if (instances.length > 1) state = "static|multi-active"
                if (app.type != state || app.instanceCount != instances.length || app.hiddenCount != hidden){
                    apps.set(
                        j, 
                        {
                            name: app.name,
                            nickname: app.nickname,
                            icon: app.icon,
                            command: app.command,
                            options: app.options,
                            type: state,
                            instanceCount: instances.length,
                            hiddenCount: hidden
                        }
                    )
                }
            }
        }

        //Build UI
        for (var name in appStore) {
            var instances = appStore[name].procs
            var first = newApps.find(a => a.includes("," + name + ","))
            if (!first) continue
            var parts = first.split(",")
            var parsed = parseCommand(parts[3], parts[1])

            // Update Pinned Options Data / Skip
            if (isAppPinned(name)) {
                
                //Update Pinned Settings
                for (var i = 0; i < root.settings.launchers.length; i++) {
                    var pinned = root.settings.launchers[i]
                    if (pinned.name !== name)
                        continue

                    if (root.settings.launcherflags.lockOptions.includes(name)) break
                    if (root.settings.launcherflags.ignoreOptions.includes(name)) {
                        var hadOptions = pinned.options.length > 0
                        if (hadOptions) {
                            pinned.options = []
                            root.saveSettings()
                        }
                        break
                    }
                    var filters = root.settings.launcherflags.filters[name]
                    if (filters && filters.length > 0){
                        var includesFilter = false
                        for (var i=0; i < filters.length; i++){
                            if (parsed.options.includes(filters[i])){
                                includesFilter = true
                                break
                            }
                        }
                        if (includesFilter) break
                    }

                    var existingOptions = pinned.options || []
                    var newOptions = parsed.options
                    if (!newOptions || newOptions.length === 0) break 
                    var newStr = JSON.stringify(newOptions[0])
                    var exists = false
                    for (var j = 0; j < existingOptions.length; j++) {
                        if (JSON.stringify(existingOptions[j]) === newStr) {
                            exists = true
                            break
                        }
                    }

                    if (root.settings.launcherflags.setOptions[name] != undefined && newOptions.length + existingOptions.length >= root.settings.launcherflags.setOptions[name]){
                        break
                    }

                    if (!exists) {
                        existingOptions.unshift(newOptions[0])
                        if (existingOptions.length > root.settings.launcherflags.maxOptions){
                            existingOptions = existingOptions.slice(0, -1)
                        }
                        pinned.options = existingOptions
                        root.saveSettings()
                    }

                    break
                }

                continue
            }

            //Add New Apps
            if (newClasses.includes(name)){
                apps.append({
                    name: name,
                    nickname: "",
                    icon: parts[2],
                    command: parsed.command,
                    options: root.settings.launcherflags.ignoreOptions.includes(name) ? "[]" : encodeOptions(parsed.options),
                    type: "active",
                    instanceCount: instances.length,
                    hiddenCount: getHiddenCount(name)
                })

            //Update Non-Pinned UI State Data
            } else {
                for (var j=0; j < apps.count; j++){
                    var app = apps.get(j)
                    if (app.name === name){
                        apps.set(j, {
                            name: app.name,
                            nickname: app.nickname,
                            icon: app.icon,
                            command: app.command,
                            options: root.settings.launcherflags.ignoreOptions.includes(name) ? "[]" : encodeOptions(parsed.options),
                            type: app.type,
                            instanceCount: instances.length,
                            hiddenCount: getHiddenCount(app.name)
                        })
                        break
                    }
                }
            }
        }
    }

    function getStaticApps(){
        var staticApps = root.settings.launchers

        var startProc = false
        for (var i = 0; i < staticApps.length; i++){
            var item = staticApps[i]
            if (item.icon === "*" && !queuedAppClassesForIcons.includes(item.name)){
                queuedAppClassesForIcons.push(item.name)
                startProc = true
            } 
        }
        if (startProc) getAppIconsProc.getIcons(true)
        
        for (var i = 0; i < staticApps.length; i++){ 
            var item = staticApps[i]
            if (!item.icon || !item.command || !item.name) continue

            var matches = getPIDs(item.name)
            var state = "static"
            if (matches.length === 1) state = "static|active"
            else if (matches.length > 1) state = "static|multi-active"

            apps.insert(
                i,
                {
                    name: item.name,
                    nickname: item.nickname ? item.nickname : "",
                    icon: item.icon,
                    command: item.command,
                    options: root.settings.launcherflags.ignoreOptions.includes(item.name) ? "[]" : encodeOptions(item.options),
                    type: state,
                    instanceCount: matches.length,
                    hiddenCount: getHiddenCount(item.name)
                }
            )
        }
    }

    function updateApps(newDataStr){
        clearInactiveApps()
        getActiveApps(newDataStr)
        if (!addedStaticApps){
            addedStaticApps = true
            getStaticApps()
        }
        checkGamingMode()
    }

    // ── Gaming mode auto-trigger ────────────────────────────────────
    // Checks if any app in settings.gaming.apps is currently active,
    // including apps that are masqued under a different pinned app.
    function checkGamingMode() {
        if (!root.settings.gaming) return
        var gamingApps = root.settings.gaming.apps || []
        if (gamingApps.length === 0) {
            gamingAppActive = false
            return
        }

        var anyActive = false
        for (var i = 0; i < gamingApps.length && !anyActive; i++) {
            var gamingApp = gamingApps[i]
            // Direct match in appStore
            if (appStore[gamingApp] && appStore[gamingApp].procs.length > 0) {
                anyActive = true
                break
            }
            // Check inside masqued entries — the proc's original class name
            // is stored in proc.name even when reassigned to a parent
            for (var key in appStore) {
                var procs = appStore[key].procs
                for (var j = 0; j < procs.length; j++) {
                    if (procs[j].name === gamingApp) {
                        anyActive = true
                        break
                    }
                }
                if (anyActive) break
            }
        }

        var wasActive = gamingAppActive
        gamingAppActive = anyActive

        if (anyActive && !wasActive) {
            // A gaming app just appeared — auto-enable (fresh start, clear pause)
            gamingUserPaused = false
            root.settings.gaming.enabled = true
            root.saveSettings()
        } else if (anyActive && !root.settings.gaming.enabled && !gamingUserPaused) {
            // Gaming app still running, mode got disabled externally but user didn't pause
            root.settings.gaming.enabled = true
            root.saveSettings()
        } else if (!anyActive && wasActive) {
            // All gaming apps closed — disable and clear pause
            gamingUserPaused = false
            if (root.settings.gaming.enabled) {
                root.settings.gaming.enabled = false
                root.saveSettings()
            }
        }
    }

    function isGamingApp(className) {
        if (!root.settings.gaming || !root.settings.gaming.apps) return false
        return root.settings.gaming.apps.includes(className)
    }

    function toggleGamingApp(className) {
        if (!root.settings.gaming) {
            root.settings.gaming = { enabled: false, apps: [] }
        }
        if (!root.settings.gaming.apps) {
            root.settings.gaming.apps = []
        }
        var idx = root.settings.gaming.apps.indexOf(className)
        if (idx >= 0) {
            root.settings.gaming.apps.splice(idx, 1)
        } else {
            root.settings.gaming.apps.push(className)
        }
        root.saveSettings()
    }

    // Sync the apps ListModel with settings.launchers without clearing.
    // - Adds any new launcher that's missing from the list
    // - Updates the icon on any launcher whose icon changed (e.g. resolved from "*")
    // - Removes any pinned-only entry whose launcher was deleted (un-pinned)
    // - Queues icon resolution for any "*" icons
    function syncLaunchers() {
        var launchers = root.settings.launchers

        // Build a set of launcher names for quick lookup
        var launcherNames = {}
        for (var i = 0; i < launchers.length; i++) {
            launcherNames[launchers[i].name] = true
        }

        // Remove apps whose launcher was deleted (un-pinned static-only entries)
        for (var r = apps.count - 1; r >= 0; r--) {
            var app = apps.get(r)
            if (app.type.includes("static") && !launcherNames[app.name]) {
                apps.remove(r)
            }
        }

        // Add missing launchers / update changed icons
        var needsIconProc = false
        for (var i = 0; i < launchers.length; i++) {
            var item = launchers[i]
            if (!item.icon || !item.command || !item.name) continue

            // Queue icon resolution for "*" icons
            if (item.icon === "*" && !queuedAppClassesForIcons.includes(item.name)) {
                queuedAppClassesForIcons.push(item.name)
                needsIconProc = true
            }

            // Check if already in the list
            var found = false
            for (var j = 0; j < apps.count; j++) {
                if (apps.get(j).name === item.name) {
                    found = true
                    // Update icon if it changed
                    var currentIcon = apps.get(j).icon
                    if (currentIcon !== item.icon) {
                        apps.setProperty(j, "icon", item.icon)
                    }
                    break
                }
            }

            if (!found) {
                var matches = getPIDs(item.name)
                var state = "static"
                if (matches.length === 1) state = "static|active"
                else if (matches.length > 1) state = "static|multi-active"

                // Insert after the last pinned app (before non-pinned active apps)
                var insertIdx = 0
                for (var k = 0; k < apps.count; k++) {
                    if (apps.get(k).type.includes("static")) insertIdx = k + 1
                    else break
                }
                apps.insert(insertIdx, {
                    name: item.name,
                    nickname: item.nickname ? item.nickname : "",
                    icon: item.icon,
                    command: item.command,
                    options: root.settings.launcherflags.ignoreOptions.includes(item.name)
                        ? "[]" : encodeOptions(item.options),
                    type: state,
                    instanceCount: matches.length,
                    hiddenCount: getHiddenCount(item.name)
                })
            }
        }

        if (needsIconProc) getAppIconsProc.getIcons(true)
    }

    function openContextMenu(popupObject){
        var contextHiddenCount = getHiddenCount(contextTarget.name)
        var contextIsPinned = isAppPinned(contextTarget.name)
        var items = []

        // ── Launch section (always visible at top) ──────────────────
        var appLabel = contextTarget.nickname || contextTarget.name
        items.push({"name": "Open " + appLabel, "action":"launch", "icon":"open_app"})

        if (contextTarget.options && contextTarget.options.length > 0) {
            items.push({"name":"Open w/ last args", "action":"launch:last", "icon":"history"})
        }

        // Jump list sub-menu (only if there are saved arg sets)
        if (contextTarget.options && contextTarget.options.length > 0) {
            var jumpItems = []
            for (var i = 0; i < contextTarget.options.length; i++) {
                if (i > root.settings.launcherflags.maxOptions) break
                var index = contextTarget.options.length - 1 - i
                var optSet = contextTarget.options[index]
                jumpItems.push({"name": optSet[0], "action":"launch:custom", "icon":"terminal", "index": index})
            }
            items.push({
                "name": "Jump List (" + jumpItems.length + ")",
                "type": "submenu",
                "icon": "history",
                "children": jumpItems
            })
        }

        items.push({"name":"Open w/ new args", "action":"launch:with", "icon":"terminal"})

        if (contextTarget.command.includes("/")) {
            items.push({"name":"Open In Files", "action":"open", "icon":"open_folder"})
        }

        // ── Windows section (only for running apps) ─────────────────
        var pids = getPIDs(contextTarget.name)
        if (contextTarget.type.includes("active") && pids.length > 0) {
            items.push({"name": "Windows", "type": "divider"})

            if (contextHiddenCount > 0) {
                items.push({"name": "Show", "action": "workspace:show", "icon": "show"})
            } else {
                items.push({"name": "Hide", "action": "workspace:hide", "icon": "hide"})
            }

            items.push({"name": "Send to workspace...", "action": "workspace:send", "icon": "home"})

            // Close sub-menu — one entry per window
            var state = appStore[contextTarget.name]
            if (state && state.procs && state.procs.length > 0) {
                if (state.procs.length === 1) {
                    // Only one window — show directly, no sub-menu needed
                    items.push({"name": "Close '" + state.procs[0].windowTitle.trim() + "'", "action":"close", "icon":"close", "index": 0})
                } else {
                    var closeItems = []
                    for (var i = 0; i < state.procs.length; i++) {
                        var instance = state.procs[i]
                        closeItems.push({"name": "Close '" + instance.windowTitle.trim() + "'", "action":"close", "icon":"close", "index": i})
                    }
                    items.push({
                        "name": "Close Window (" + closeItems.length + ")",
                        "type": "submenu",
                        "icon": "close",
                        "children": closeItems
                    })
                }
                items.push({"name":"Kill all", "action":"kill", "icon":"stop"})
            }
        }

        // ── Settings section ────────────────────────────────────────
        items.push({"name": "Settings", "type": "divider"})

        items.push({
            "name": contextIsPinned ? "Un-Pin" : "Pin",
            "action": "pin",
            "icon": contextIsPinned ? "unpin" : "pin"
        })

        items.push({"name": "Copy cmd", "action":"copy:command", "icon":"copy_content"})
        if (contextTarget.options && contextTarget.options.length > 0) {
            items.push({"name": "Copy cmd + last args", "action":"copy:args", "icon":"copy_content"})
        }

        // Masque options as sub-menu
        var masqueItems = []
        var currentMasque = getAppMasque(contextTarget.name)
        if (currentMasque !== "") {
            masqueItems.push({"name": "Remove Masque (" + currentMasque + ")", "action": "masque:remove", "icon": "masked"})
            // Gaming toggle for this masqued app itself
            var selfIsGaming = isGamingApp(contextTarget.name)
            masqueItems.push({
                "name": contextTarget.name + " Gaming: " + (selfIsGaming ? "ON" : "OFF"),
                "action": "toggleGamingMasque",
                "icon": "dark_mode",
                "className": contextTarget.name
            })
        } else {
            masqueItems.push({"name": "Add as Masque...", "action": "masque:open", "icon": "masked_add"})
        }
        if (contextIsPinned) {
            var masquesUnder = getMasquesUnder(contextTarget.name)
            if (masquesUnder.length > 0) {
                masqueItems.push({"name": "Manage Masques (" + masquesUnder.length + ")...", "action": "masque:manage", "icon": "masked"})
                // Gaming toggle for each masqued class under this pin
                for (var m = 0; m < masquesUnder.length; m++) {
                    var masqueClass = masquesUnder[m].className
                    var mIsGaming = isGamingApp(masqueClass)
                    masqueItems.push({
                        "name": masqueClass + " Gaming: " + (mIsGaming ? "ON" : "OFF"),
                        "action": "toggleGamingMasque",
                        "icon": "dark_mode",
                        "className": masqueClass
                    })
                }
            }
        }
        items.push({
            "name": "Masque",
            "type": "submenu",
            "icon": "masked",
            "children": masqueItems
        })

        if (appHasNoOptionsFlag(contextTarget.name)) {
            items.push({"name": "Arg Options: Turn OFF", "action": "toggleOptions", "icon": "settings"})
        } else {
            items.push({"name": "Arg Options: Turn ON", "action": "toggleOptions", "icon": "settings"})
        }

        // Gaming mode auto-trigger toggle
        var isGaming = isGamingApp(contextTarget.name)
        items.push({
            "name": isGaming ? "Gaming App: ON" : "Gaming App: OFF",
            "action": "toggleGaming",
            "icon": isGaming ? "dark_mode" : "dark_mode"
        })

        // ── Populate the menu model ─────────────────────────────────
        popup.closeSubMenu()

        // Extract submenu children into a separate map (ListModel can't
        // store nested arrays, and we now use a plain JS array anyway)
        var subData = {}
        for (var k = 0; k < items.length; k++) {
            if (items[k].type === "submenu" && items[k].children) {
                subData[items[k].name] = items[k].children
            }
        }
        popup.subMenuData = subData
        popup.actions = items

        // Calculate height: normal items = 35px, dividers = 28px
        var totalHeight = 0
        for (var k = 0; k < items.length; k++) {
            totalHeight += (items[k].type === "divider") ? 28 : 35
        }
        popup.implicitHeight = totalHeight + 8
        popup.forceOpen(popupObject)
    }

    //CONTEXT MENU ACTIONS
    function launch(data, includeOptions=true, optionsIndex=0){
        var opts = decodeOptions(data.options)
        // data.command may be a multi-word string from a .desktop Exec field
        // (e.g. "/usr/bin/flatpak run --branch=master ... com.app.Name")
        // Split into a proper args array so execute doesn't try to find
        // a binary whose name is the entire string.
        var cmdStr = data.command.trim()
        var args = cmdStr.includes(" ") ? cmdStr.split(/\s+/) : [cmdStr]
        if (includeOptions && opts.length > 0) {
            args = root.combine(args, opts[optionsIndex])
        }
        root.execute(args)
    }

    function togglePin(target) {
        for (var i = 0; i < root.settings.launchers.length; i++) {
            if (root.settings.launchers[i].name === target.name) {
                root.settings.launchers.splice(i, 1)
                delete appStore[target.name]
                return
            }
        }
        
        contextIcon = target.icon
        root.settings.launchers.push({
            name: target.name,
            nickname: target.nickname || "",
            icon: target.icon,
            command: target.command,
            options: decodeOptions(target.options)
        })
    }

    function killApp(pid){
        root.execute(["kill", pid])
    }

    function closeApp(index, name){
        var state = appStore[name]
        var instance = state.procs[index]
        // Close by hyprland window address — exact, no fuzzy matching needed
        if (instance.address) {
            root.execute(['hyprctl', 'dispatch', 'closewindow', 'address:' + instance.address])
        } else {
            // Fallback for windows without address data
            var title = instance.windowTitle
            root.execute( root.newUtill( root.combine( ["--closehyprwindow"], title.split(" ") ) ) )
        }
        state.procs.splice(index, 1)
        if (state.procs.length === 0){
            delete appStore[name]
        }
    }

    function hideInWorkspace(pid){
        var pidAppState = getAppStateFromPID(pid)
        if (pidAppState){
            pidAppState['lastWorkspace'] = pidAppState['workspace'].trim()
        }
        root.execute(['hyprctl', 'dispatch', 'movetoworkspacesilent', 'special:hidden,pid:' + pid])
    }

    function showInDefault(pid){
        var pidAppState = getAppStateFromPID(pid)
        if (pidAppState.lastWorkspace){
            root.execute(['hyprctl', 'dispatch', 'movetoworkspacesilent', pidAppState['lastWorkspace'].trim()+',pid:'+pid])
        } else {
            root.execute(['hyprctl', 'dispatch', 'movetoworkspacesilent', 1+',pid:'+pid])
        }
    }

    function hideAll(data){
        var pids = getPIDs(data.name)
        for (var i=0; i < pids.length; i++){
            hideInWorkspace( pids[i] )
        }
    }

    function showAll(data){
        var pids = getPIDs(data.name)
        for (var i=0; i < pids.length; i++){
            showInDefault( pids[i] )
        }
    }

    function appHasNoOptionsFlag(name){
        return root.settings.launcherflags.ignoreOptions.includes(name)
    }

    function toggleNoOptions(name){
        if (root.settings.launcherflags.lockOptions.includes(name)) return
        if (appHasNoOptionsFlag(name)) {
            for (var j = 0; j < root.settings.launcherflags.ignoreOptions.length; j++){
                if (name === root.settings.launcherflags.ignoreOptions[j]){
                    root.settings.launcherflags.ignoreOptions.splice(j, 1)
                    break
                }
            }
        } else {
            root.settings.launcherflags.ignoreOptions.push(name)
        }
        root.saveSettings()
    }

    function setMasque(targetClass, masqueUnderName) {
        // Sets classIncludes masque on the chosen pinned launcher
        // so targetClass always appears under masqueUnderName
        for (var i = 0; i < root.settings.launchers.length; i++) {
            var launcher = root.settings.launchers[i]
            if (launcher.name === masqueUnderName) {
                launcher.masque = { classIncludes: targetClass }
                root.saveSettings()
                return
            }
        }
    }

    function removeMasque(className) {
        // Removes any masque that references this class
        for (var i = 0; i < root.settings.launchers.length; i++) {
            var launcher = root.settings.launchers[i]
            if (launcher.masque && launcher.masque.classIncludes === className) {
                delete launcher.masque
                root.saveSettings()
                return
            }
        }
    }

    function getAppMasque(className) {
        // Returns the name of the pinned app this class is masquing under, or ""
        for (var i = 0; i < root.settings.launchers.length; i++) {
            var launcher = root.settings.launchers[i]
            if (launcher.masque && launcher.masque.classIncludes === className) {
                return launcher.name
            }
        }
        return ""
    }

    function getPinnedApps() {
        // Returns array of {name, nickname, icon} for all pinned launchers
        var pinned = []
        for (var i = 0; i < root.settings.launchers.length; i++) {
            var l = root.settings.launchers[i]
            pinned.push({
                name:     l.name,
                nickname: l.nickname || l.name,
                icon:     l.icon || ""
            })
        }
        return pinned
    }

    function getMasquesUnder(pinnedName) {
        // Returns array of {classIncludes} for all masques assigned to this pinned app
        var result = []
        for (var i = 0; i < root.settings.launchers.length; i++) {
            var launcher = root.settings.launchers[i]
            if (launcher.name === pinnedName && launcher.masque) {
                // Support both single masque object and future array
                var m = launcher.masque
                if (m.classIncludes) result.push({ className: m.classIncludes })
                if (m.cmdIncludes)   result.push({ className: m.cmdIncludes })
            }
        }
        return result
    }

    // OBJECTS
    Timer{
        id: getAppsTimer
        interval: 10
        running: true
        repeat: true
        onTriggered: {
            if (!addedStaticApps){ 
                getAppsTimer.interval = 650
            }
            if (!getActiveAppsProc.running){
                getActiveAppsProc.running = true
            }
        }
    }

    Process{
        id: getAppIconsProc
        command: root.newUtill(["--getappicons"])

        function getIcons(clearCache){
            if (queuedAppClassesForIcons.length > 0 && !getAppIconsProc.running) {
                var args = clearCache
                    ? root.combine(["--getappicons", "--clearcache"], queuedAppClassesForIcons)
                    : root.combine(["--getappicons"], queuedAppClassesForIcons)
                getAppIconsProc.command = root.newUtill(args)
                getAppIconsProc.running = true
            }
        }

        stdout: StdioCollector{
            onStreamFinished: {
                var text = this.text.trim()
                if (!text) return

                // Result format: "className:/path/to/icon,className2:/path/to/icon2"
                // Split on comma but paths can't contain commas so this is safe
                var entries = text.split(",")
                var iconMap = {}
                for (var e = 0; e < entries.length; e++) {
                    var colonIdx = entries[e].indexOf(":")
                    if (colonIdx === -1) continue
                    var cls  = entries[e].substring(0, colonIdx).trim()
                    var path = entries[e].substring(colonIdx + 1).trim()
                    iconMap[cls] = path
                }

                // Update settings.launchers
                for (var i = 0; i < root.settings.launchers.length; i++) {
                    var launcher = root.settings.launchers[i]
                    if (iconMap[launcher.name]) {
                        launcher.icon = iconMap[launcher.name]
                    }
                }

                // Update apps ListModel so UI reflects immediately without restart
                for (var j = 0; j < apps.count; j++) {
                    var app = apps.get(j)
                    if (iconMap[app.name]) {
                        apps.set(j, {
                            name:          app.name,
                            nickname:      app.nickname,
                            icon:          iconMap[app.name],
                            command:       app.command,
                            options:       app.options,
                            type:          app.type,
                            instanceCount: app.instanceCount,
                            hiddenCount:   app.hiddenCount
                        })
                    }
                }

                // Clear the queue for processed classes
                queuedAppClassesForIcons = queuedAppClassesForIcons.filter(
                    function(cls) { return !iconMap[cls] }
                )

                root.saveSettings()
            }
        }
    }

    Process{
        id: getActiveAppsProc
        command: root.newUtill(["--getactiveapplications"])
        stdout: StdioCollector{
            onStreamFinished: updateApps(this.text)
        }
    } 

    // -- LAUNCHER POPUP
    AppBarLaunchPopup {
        id: launchPopup
    }

    // -- CUSTOM ARG POPUP
    AppBarArgPopup {
        id: argPopup
        onLaunched: {
            launchPopup.setAndOpen(
                contextTarget.nickname
                    ? "Launching " + contextTarget.nickname
                    : "Launching " + contextTarget.name,
                contextIcon
            )
        }
    }

    // -- CONTEXT MENU
    AppBarContextMenu {
        id: popup
        onActionTriggered: function(modelData) {
            if (modelData.action === "pin") {
                togglePin(contextTarget)
                root.saveSettings()
                syncLaunchers()
            } else if (modelData.action === "debug:data") {
                var pids = getPIDs(contextTarget.name)
            } else if (modelData.action === "launch:with") {
                argPopup.contextTarget = contextTarget
                argPopup.contextIcon   = contextIcon
                argPopup.forceOpen(appBarWidget)
            } else if (modelData.action === "launch:custom") {
                if (contextTarget.command) {
                    launch(contextTarget, true, modelData.index)
                    launchPopup.setAndOpen(
                        contextTarget.nickname ? "Launching " + contextTarget.nickname : "Launching " + contextTarget.name,
                        contextIcon
                    )
                }
            } else if (modelData.action === "launch:last") {
                if (contextTarget.command) {
                    launch(contextTarget, true, 0)
                    launchPopup.setAndOpen(
                        contextTarget.nickname ? "Launching " + contextTarget.nickname : "Launching " + contextTarget.name,
                        contextIcon
                    )
                }
            } else if (modelData.action === "launch") {
                if (contextTarget.command) {
                    launch(contextTarget, false)
                    launchPopup.setAndOpen(
                        contextTarget.nickname ? "Launching " + contextTarget.nickname : "Launching " + contextTarget.name,
                        contextIcon
                    )
                }
            } else if (modelData.action === "copy:command") {
                root.copy(contextTarget.command)
            } else if (modelData.action === "workspace:hide") {
                hideAll(contextTarget)
            } else if (modelData.action === "workspace:show") {
                showAll(contextTarget)
            } else if (modelData.action === "copy:args") {
                var opts = decodeOptions(contextTarget.options)
                var str = contextTarget.command
                for (var i = 0; i < opts[0].length; i++) str += " " + opts[0][i]
                root.copy(str)
            } else if (modelData.action === "open") {
                var args = contextTarget.command.split(" ")
                for (var i = 0; i < args.length; i++) {
                    if (args[i].startsWith("/")) { root.execute(root.cmd("files_open", {"path": args[i]})); break }
                }
            } else if (modelData.action === "close") {
                closeApp(modelData.index, contextTarget.name)
            } else if (modelData.action === "kill") {
                var pids = getPIDs(contextTarget.name)
                for (var i = 0; i < pids.length; i++) killApp(pids[i])
            } else if (modelData.action === "toggleOptions") {
                toggleNoOptions(contextTarget.name)
            } else if (modelData.action === "toggleGaming") {
                toggleGamingApp(contextTarget.name)
            } else if (modelData.action === "toggleGamingMasque") {
                toggleGamingApp(modelData.className)
            } else if (modelData.action === "workspace:send") {
                var pids = getPIDs(contextTarget.name)
                workspaceSendPopup.targetPid   = pids.length > 0 ? pids[0] : ""
                workspaceSendPopup.targetClass = contextTarget.name
                workspaceSendPopup.forceOpen(appBarWidget)
            } else if (modelData.action === "masque:open") {
                masquePopup.contextTarget = contextTarget
                masquePopup.forceOpen(appBarWidget)
            } else if (modelData.action === "masque:manage") {
                masqueManagePopup.masques = getMasquesUnder(contextTarget.name)
                masqueManagePopup.forceOpen(appBarWidget)
            } else if (modelData.action === "masque:remove") {
                removeMasque(contextTarget.name)
            }
        }
    }

    // -- ADD APP WINDOW
    AddAppWindow {
        id: addAppWindow
        onSaved: function() {
            syncLaunchers()
        }
    }

    // -- RUN COMMAND POPUP
    AppBarRunPopup {
        id: runPopup
        onLaunched: function(cmd) {
            launchPopup.setAndOpen("Running: " + cmd, root.iconSource("terminal"))
        }
    }

    // -- COMMAND HISTORY POPUP
    AppBarHistoryPopup {
        id: historyPopup
        onCommandSelected: function(cmd) {
            root.execute(cmd.split(/\s+/))
            launchPopup.setAndOpen("Running: " + cmd, root.iconSource("terminal"))
        }
    }

    // -- ADD BUTTON DROPDOWN
    AppBarAddDropdown {
        id: addDropdown
        appWindow: addAppWindow
        onRunRequested:     runPopup.forceOpen(addAppButton)
        onHistoryRequested: historyPopup.forceOpen(addAppButton)
    }

    // -- MASQUE SELECTOR POPUP
    AppBarMasquePopup {
        id: masquePopup
        onMasqueSelected: function(targetClass, masqueUnderName) {
            setMasque(targetClass, masqueUnderName)
        }
    }

    // -- MASQUE MANAGE POPUP
    AppBarMasqueManagePopup {
        id: masqueManagePopup
        onRemoveMasqueRequested: function(className) {
            removeMasque(className)
        }
    }

    // -- WORKSPACE SEND POPUP
    WorkspaceSendPopup {
        id: workspaceSendPopup
    }

    // -- WIDGET ROW
    RowLayout{
        id: row
        anchors.centerIn: parent
        spacing: 15

        Tooltip {
            id: tooltip
            text: ""

            function openAndSet(text, point){
                tooltip.text = text
                tooltip.showAt(point)
            }
        }

        Repeater{
            model: appBarWidget.apps
            
            // APP BUTTON
            delegate: RoundButton {
                id: button

                property string name: model.name 
                property string nickname: model.nickname
                property string iconSource: model.icon 
                property string command: model.command
                property string options: model.options
                property string type: model.type
                property int instanceCount: model.instanceCount
                property int hiddenCount: model.hiddenCount
                property string tooltipText: nickname ? nickname : name
                property bool pinned: isAppPinned(name)
                property int modelIndex: model.index

                // Drop indicator — shows left of button when dragging over it
                Rectangle {
                    width: 4
                    height: parent.height + 14
                    anchors.left: parent.left
                    anchors.leftMargin: -8
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                    visible: appBarWidget.dragTargetIndex === modelIndex
                             && appBarWidget.dragSourceIndex !== modelIndex
                             && appBarWidget.dragSourceIndex !== -1
                    radius: 2

                    // Glow behind the indicator for contrast on any background
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 6
                        height: parent.height + 4
                        radius: parent.radius + 3
                        color: root.settings.theme.primary
                        opacity: 0.6
                        z: -1
                    }
                }

                // Dim while being dragged
                opacity: appBarWidget.dragSourceIndex === modelIndex ? 0.4 : 1.0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                padding: 1
                Layout.preferredWidth: 25
                Layout.preferredHeight: 25
                font.family: root.settings.fontFamily

                background: Rectangle {
                    radius: button.radius
                    color: "transparent"
                    border.color: 'transparent'
                    border.width: 0
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    // ── Drag reorder state ────────────────────────
                    property bool isDragging: false
                    property real startX: 0

                    onPressed: (mouse) => {
                        if (mouse.button === Qt.LeftButton)
                            startX = mouse.x
                    }

                    onPositionChanged: (mouse) => {
                        if (mouse.buttons & Qt.LeftButton) {
                            if (!isDragging && Math.abs(mouse.x - startX) > 10) {
                                // Only allow dragging pinned apps
                                if (!button.pinned) return
                                isDragging = true
                                appBarWidget.dragSourceIndex = modelIndex
                                tooltip.hide()
                            }
                            if (isDragging) {
                                var rowX = mapToItem(row, mouse.x, 0).x
                                var target = -1
                                for (var i = 0; i < row.children.length; i++) {
                                    var child = row.children[i]
                                    if (!child || child.modelIndex === undefined) continue
                                    // Only allow dropping onto other pinned apps
                                    if (!child.pinned) continue
                                    if (rowX >= child.x && rowX <= child.x + child.width) {
                                        if (child.modelIndex !== modelIndex)
                                            target = child.modelIndex
                                        break
                                    }
                                }
                                appBarWidget.dragTargetIndex = target
                            }
                        }
                    }

                    onReleased: (mouse) => {
                        if (isDragging) {
                            var fromIdx = appBarWidget.dragSourceIndex
                            var toIdx   = appBarWidget.dragTargetIndex
                            if (toIdx !== -1 && toIdx !== fromIdx) {
                                // Grab names BEFORE moving anything
                                var srcName = appBarWidget.apps.get(fromIdx).name
                                var dstName = appBarWidget.apps.get(toIdx).name

                                // 1. Move inside the visual ListModel (instant, no flicker)
                                appBarWidget.apps.move(fromIdx, toIdx, 1)

                                // 2. Mirror the reorder in settings.launchers for persistence
                                var launchers = root.settings.launchers
                                var fromL = -1
                                var toL   = -1
                                for (var i = 0; i < launchers.length; i++) {
                                    if (launchers[i].name === srcName) fromL = i
                                    if (launchers[i].name === dstName) toL   = i
                                }
                                if (fromL !== -1 && toL !== -1 && fromL !== toL) {
                                    var moved = launchers.splice(fromL, 1)[0]
                                    var insertAt = toL > fromL ? toL - 1 : toL
                                    launchers.splice(insertAt, 0, moved)
                                    root.saveSettings()
                                }
                            }
                            isDragging = false
                            appBarWidget.dragSourceIndex = -1
                            appBarWidget.dragTargetIndex = -1
                            return  // don't trigger click after drag
                        }
                    }

                    onCanceled: {
                        isDragging = false
                        appBarWidget.dragSourceIndex = -1
                        appBarWidget.dragTargetIndex = -1
                    }

                    // ── Click handlers ────────────────────────────
                    onClicked: (mouse) => {
                        if (isDragging) return  // ignore click after drag
                        if (mouse.button == Qt.LeftButton){
                            if (!type.includes("active")){
                                appBarWidget.contextIcon = content.getImageIcon()
                                launch(model)
                                launchPopup.setAndOpen(
                                    nickname ? "Launching " + nickname : "Launching " + name,
                                    content.getImageIcon()
                                )
                            } 
                        } else if (mouse.button == Qt.RightButton){
                            if (!appBarWidget.contextTarget || appBarWidget.contextTarget.command != command){
                                appBarWidget.contextIcon = content.getImageIcon()
                                appBarWidget.contextTarget = {
                                    name: name,
                                    nickname: nickname,
                                    icon: iconSource,
                                    command: command.trim(),
                                    options: decodeOptions(options),
                                    type: type
                                }
                                openContextMenu(button)
                            } else {
                                if (!popup.visible && appBarWidget.contextTarget.command == command){
                                    appBarWidget.contextIcon = content.getImageIcon()
                                    appBarWidget.contextTarget = {
                                        name: name,
                                        nickname: nickname,
                                        icon: iconSource,
                                        command: command.trim(),
                                        options: decodeOptions(options),
                                        type: type
                                    } 
                                    openContextMenu(button)
                                } else {
                                    popup.forceClose()
                                }
                            }
                        } 
                    }

                    HoverHandler {
                        id:hoverHandler
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered) {
                                tooltip.openAndSet(
                                    button.nickname ? button.nickname : button.name,
                                    hoverHandler.point
                                )
                            } else {
                                tooltip.hide()
                            }
                        }
                    }
                }

                contentItem: Item {
                    id: content
                    anchors.centerIn: parent

                    function getImageIcon(){
                        return image.source
                    }

                    Image {
                        id: image
                        source: iconSource === "*" || iconSource === ""
                            ? root.iconSource("open_app")
                            : iconSource
                        anchors.centerIn: parent
                        width: parent.width * 1.5
                        height: parent.height * 1.5
                        fillMode: Image.PreserveAspectFit
                        opacity: hiddenCount > 0 ? 0.4 : 1.0
                    }
                    Rectangle {
                        width: parent.width - 2
                        height: 4
                        radius: 2
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: -12
                        color: {
                            if (instanceCount === 0) return "transparent"
                            if (hiddenCount === instanceCount) return "#666666"
                            if (hiddenCount > 0) return "#ffaa00"
                            return root.settings.theme.primary
                        }
                    }
                }
            }
        }

        // ── Gaming mode re-enter button ─────────────────────────────
        // Visible when a gaming app is running but the user manually
        // exited gaming mode. Click to go back into gaming mode.
        // Also stays visible if gamingUserPaused is set, even during
        // brief appStore rebuilds, to prevent flickering.
        IconButton {
            id: gamingModeButton
            iconName: "dark_mode"
            iconSize: 22
            tooltipText: "Re-enter Gaming Mode"
            color: root.settings.theme.primary
            visible: (appBarWidget.gamingAppActive || appBarWidget.gamingUserPaused)
                && !(root.settings.gaming && root.settings.gaming.enabled)
            onClicked: {
                appBarWidget.gamingUserPaused = false
                if (!root.settings.gaming) root.settings.gaming = { enabled: false, apps: [] }
                root.settings.gaming.enabled = true
                root.saveSettings()
            }
        }

        // ── Add App button — always at the end ─────────────────── 
        IconButton {
            id: addAppButton
            iconName: "apps"
            iconSize: 26
            tooltipText: "Add App"
            color: root.settings.theme.text
            onClicked: addDropdown.toggle(addAppButton)
        }
    }
}