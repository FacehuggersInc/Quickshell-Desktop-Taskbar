pragma Singleton

import QtQuick

QtObject {
    id: schema

    // ## Config access lives in SettingControl, not here
    // A singleton is created outside the component tree, so the ShellRoot id
    // does not resolve in it and every read silently returned its fallback.
    // This file is pure data.

    readonly property var hourOptions: {
        var out = []
        for (var h = 0; h < 24; h++) {
            var suffix = h < 12 ? "am" : "pm"
            var display = h % 12 === 0 ? 12 : h % 12
            out.push({ label: display + ":00" + suffix, value: h })
        }
        return out
    }

    // ## Pages

    readonly property var pages: [
        {
            id: "appearance",
            title: "Appearance",
            icon: "light_mode",
            groups: [
                {
                    title: "Theme",
                    items: [
                        {
                            key: "theme.mode", type: "segmented", label: "Mode",
                            description: "Auto follows the dark hours below",
                            options: [
                                { label: "Auto", value: "auto" },
                                { label: "Light", value: "light" },
                                { label: "Dark", value: "dark" }
                            ],
                            fallback: "auto"
                        },
                        {
                            key: "theme.accentSource", type: "segmented", label: "Accent Source",
                            description: "Wallpaper picks a hue and clamps it for contrast",
                            options: [
                                { label: "Fixed", value: "fixed" },
                                { label: "Wallpaper", value: "wallpaper" }
                            ],
                            fallback: "fixed"
                        },
                        {
                            key: "theme.accent", type: "field", label: "Accent Colour",
                            description: "Used when the source is fixed, and as the hue fallback",
                            fallback: "#6b5d62"
                        }
                    ]
                },
                {
                    title: "Surfaces",
                    items: [
                        {
                            key: "theme.glass", type: "switch", label: "Glass",
                            description: "Translucent blurred surfaces instead of opaque ones",
                            fallback: true
                        },
                        {
                            key: "theme.blurMode", type: "segmented", label: "Blur Mode",
                            description: "Compositor follows the drawn shape exactly but needs layer rules",
                            options: [
                                { label: "Protocol", value: "protocol" },
                                { label: "Compositor", value: "compositor" }
                            ],
                            fallback: "protocol"
                        },
                        {
                            key: "theme.panelDim", type: "slider", label: "Panel Dimming",
                            description: "Scrim strength behind popups and panels",
                            from: 0.5, to: 1.4, step: 0.05, fallback: 1.0
                        },
                        {
                            key: "theme.overlayDim", type: "slider", label: "Overlay Dimming",
                            description: "Scrim strength behind fullscreen overlays",
                            from: 0.5, to: 1.4, step: 0.05, fallback: 1.0
                        }
                    ]
                },
                {
                    title: "Icons",
                    items: [
                        {
                            key: "theme.icons", type: "segmented", label: "Icon Source",
                            description: "Material Symbols needs ttf-material-symbols-variable",
                            options: [
                                { label: "Auto", value: "auto" },
                                { label: "Font", value: "font" },
                                { label: "Folder", value: "images" }
                            ],
                            fallback: "auto"
                        },
                        {
                            key: "theme.iconFamily", type: "select", label: "Symbol Style",
                            options: [
                                { label: "Rounded", value: "Material Symbols Rounded" },
                                { label: "Outlined", value: "Material Symbols Outlined" },
                                { label: "Sharp", value: "Material Symbols Sharp" }
                            ],
                            fallback: "Material Symbols Rounded"
                        }
                    ]
                },
                {
                    title: "Typography",
                    items: [
                        {
                            key: "fontFamily", type: "field", label: "Font Family",
                            fallback: "JetBrainsMono"
                        },
                        {
                            key: "dateTimeFormat", type: "field", label: "Clock Format",
                            description: "strftime, e.g. %I:%M%p %a, %b %d",
                            fallback: "%I:%M%p %a, %b %d"
                        }
                    ]
                }
            ]
        },
        {
            id: "wallpaper",
            title: "Wallpaper",
            icon: "wallpaper",
            groups: [
                {
                    title: "Cycling",
                    items: [
                        {
                            key: "wallpapers.cycling", type: "switch", label: "Cycle Wallpapers",
                            description: "Turn off to manage wallpapers yourself",
                            fallback: true
                        },
                        {
                            key: "wallpapers.wallpaperMode", type: "segmented", label: "Set",
                            options: [
                                { label: "Day", value: 1, color: "#f5a623" },
                                { label: "Auto", value: 0 },
                                { label: "Night", value: 2 }
                            ],
                            fallback: 0
                        },
                        {
                            key: "wallpapers.interval", type: "select", label: "Interval",
                            description: "Time between wallpaper changes",
                            options: [
                                { label: "1 minute", value: 60000 },
                                { label: "5 minutes", value: 300000 },
                                { label: "10 minutes", value: 600000 },
                                { label: "15 minutes", value: 900000 },
                                { label: "30 minutes", value: 1800000 },
                                { label: "45 minutes", value: 2700000 },
                                { label: "1 hour", value: 3600000 },
                                { label: "2 hours", value: 7200000 },
                                { label: "4 hours", value: 14400000 },
                                { label: "8 hours", value: 28800000 }
                            ],
                            fallback: 600000
                        },
                        {
                            key: "wallpapers.randomWallpaperPerDisplay", type: "switch",
                            label: "Different Per Display", fallback: true
                        }
                    ]
                },
                {
                    title: "Folders",
                    items: [
                        { key: "wallpapers.day", type: "field", label: "Day Folder", fallback: "" },
                        { key: "wallpapers.night", type: "field", label: "Night Folder", fallback: "" },
                        {
                            key: "wallpapers.portraitFolder", type: "field", label: "Portrait Folder",
                            description: "Preferred on vertical monitors", fallback: ""
                        }
                    ]
                },
                {
                    title: "Dark Hours",
                    items: [
                        {
                            key: "wallpapers.darkModeHours.at", type: "select", label: "Night Starts",
                            options: schema.hourOptions, fallback: 21
                        },
                        {
                            key: "wallpapers.darkModeHours.before", type: "select", label: "Day Starts",
                            options: schema.hourOptions, fallback: 6
                        }
                    ]
                },
                {
                    title: "Cropping",
                    items: [
                        {
                            key: "wallpapers.smartCrop", type: "switch", label: "Smart Crop",
                            description: "Crop to the most interesting region on vertical monitors",
                            fallback: false
                        }
                    ]
                }
            ]
        },
        {
            id: "bar",
            title: "Bar",
            icon: "apps",
            custom: "bar",
            groups: [
                {
                    title: "Placement",
                    items: [
                        {
                            key: "bar.position", type: "segmented", label: "Position",
                            description: "Which edge of the screen the bar sits on",
                            options: [
                                { label: "Top", value: "top" },
                                { label: "Bottom", value: "bottom" }
                            ],
                            fallback: "top"
                        },
                        {
                            key: "bar.style", type: "segmented", label: "Style",
                            description: "Separate rounded blocks, or one bar spanning the screen",
                            options: [
                                { label: "Blocks", value: "blocks" },
                                { label: "Full", value: "full" }
                            ],
                            fallback: "blocks"
                        }
                    ]
                },
                {
                    title: "Metrics",
                    items: [
                        {
                            key: "bar.height", type: "stepper", label: "Bar Height",
                            from: 24, to: 72, step: 1, suffix: "px", fallback: 42
                        },
                        {
                            key: "bar.padding", type: "stepper", label: "Edge Padding",
                            description: "Inset before the first and after the last block",
                            from: 0, to: 40, step: 1, suffix: "px", fallback: 0
                        },
                        {
                            key: "bar.spacing", type: "stepper", label: "Block Spacing",
                            description: "Gap between the bar's blocks",
                            from: 0, to: 40, step: 1, suffix: "px", fallback: 5
                        },
                        {
                            key: "bar.widgetSpacing", type: "stepper", label: "Widget Spacing",
                            description: "Gap between widgets inside a block",
                            from: 0, to: 30, step: 1, suffix: "px", fallback: 8
                        },
                        {
                            key: "bar.blockPadding", type: "stepper", label: "Block Inset",
                            description: "Space between a block's edge and its widgets",
                            from: 0, to: 40, step: 1, suffix: "px", fallback: 15
                        }
                    ]
                },
                {
                    title: "Clock",
                    items: [
                        {
                            key: "widgets.clockStyle", type: "segmented", label: "Clock Style",
                            description: "Dot matrix renders the time as a lit grid",
                            options: [
                                { label: "Text", value: "text" },
                                { label: "Dots", value: "dots" }
                            ],
                            fallback: "text"
                        },
                        {
                            key: "widgets.clock24", type: "switch", label: "24 Hour Clock",
                            fallback: false
                        }
                    ]
                },
                {
                    title: "Network",
                    items: [
                        {
                            key: "widgets.networkStyle", type: "segmented", label: "Network Style",
                            description: "Dots show live up and down throughput",
                            options: [
                                { label: "Dots", value: "dots" },
                                { label: "Text", value: "text" }
                            ],
                            fallback: "dots"
                        }
                    ]
                },

                {
                    title: "Gaming Bar",
                    items: [
                        {
                            key: "gaming.barHeight", type: "stepper", label: "Revealed Height",
                            description: "How tall the bar becomes when you hover the edge",
                            from: 8, to: 48, step: 1, suffix: "px", fallback: 14
                        }
                    ]
                },
                {
                    title: "Launchers",
                    items: [
                        {
                            key: "launcherflags.maxOptions", type: "stepper", label: "Max Jump List Items",
                            from: 1, to: 10, step: 1, fallback: 3
                        }
                    ]
                }
            ]
        },
        {
            id: "displays",
            title: "Displays",
            icon: "brightness",
            custom: "displays",
            groups: [
                {
                    title: "Brightness",
                    items: [
                        { key: "", type: "brightness", label: "Brightness",
                          description: "Applies to every ddc capable display" },
                        { key: "", type: "action", label: "Re-detect Monitors",
                          description: "Rescan for ddc capable displays",
                          action: "brightnessRefresh" }
                    ]
                },
                {
                    title: "Theater",
                    items: [

                        {
                            key: "theater.dimBrightness", type: "stepper", label: "Dim Level",
                            description: "Brightness of non primary displays",
                            from: 0, to: 50, step: 1, suffix: "%", fallback: 10
                        },
                        {
                            key: "theater.wallpaper", type: "field", label: "Theater Wallpaper",
                            description: "Shown on dimmed displays", fallback: ""
                        }
                    ]
                }
            ]
        },
        {
            id: "hotkeys",
            title: "Hotkeys",
            icon: "terminal",
            custom: "hotkeys",
            groups: []
        },
        {
            id: "startup",
            title: "Startup Apps",
            icon: "restart",
            custom: "startup",
            groups: []
        },
        {
            id: "pinned",
            title: "Pinned Apps",
            icon: "apps",
            custom: "pinned",
            groups: []
        },
        {
            id: "audio",
            title: "Audio",
            icon: "volume_max",
            custom: "audio",
            groups: []
        },
        {
            id: "network",
            title: "Network",
            icon: "wired",
            custom: "network",
            groups: []
        },
        {
            id: "bluetooth",
            title: "Bluetooth",
            icon: "bluetooth",
            custom: "bluetooth",
            groups: []
        },
        {
            id: "mime",
            title: "File Types",
            icon: "open_folder",
            custom: "mime",
            groups: []
        },
        {
            id: "packages",
            title: "Packages",
            icon: "download",
            custom: "packages",
            groups: []
        },
        {
            id: "commands",
            title: "Commands",
            icon: "terminal",
            groups: [
                {
                    title: "Applications",
                    items: [
                        { key: "commands.terminal", type: "field", label: "Terminal", fallback: "" },
                        { key: "commands.files", type: "field", label: "File Manager", fallback: "" },
                        { key: "commands.editor", type: "field", label: "Editor", fallback: "" },
                        { key: "commands.screenshot", type: "field", label: "Screenshot", fallback: "" },
                        { key: "commands.colorpicker", type: "field", label: "Colour Picker", fallback: "" },
                        { key: "commands.wallpaper_set", type: "field", label: "Set Wallpaper", fallback: "" }
                    ]
                },
                {
                    title: "Session",
                    items: [
                        { key: "commands.lock", type: "field", label: "Lock", fallback: "" },
                        { key: "commands.logout", type: "field", label: "Log Out", fallback: "" },
                        { key: "commands.suspend", type: "field", label: "Suspend", fallback: "" },
                        { key: "commands.reboot", type: "field", label: "Restart", fallback: "" },
                        { key: "commands.poweroff", type: "field", label: "Power Off", fallback: "" },
                        { key: "commands.restart_shell", type: "field", label: "Restart Shell", fallback: "" }
                    ]
                }
            ]
        },
        {
            id: "gaming",
            title: "Gaming",
            icon: "hide",
            custom: "gaming",
            groups: []
        },
        {
            id: "debug",
            title: "Debug",
            icon: "search",
            custom: "debug",
            groups: []
        },
        {
            id: "advanced",
            title: "Advanced",
            icon: "settings",
            groups: [
                {
                    title: "Utility Script",
                    items: [
                        {
                            key: "utill.interpreter", type: "field", label: "Interpreter",
                            fallback: "python3"
                        },
                        {
                            key: "utill.path", type: "field", label: "Script Path",
                            description: "Empty resolves to ./Scripts/utill.py",
                            fallback: ""
                        },
                        { key: "iconsPath", type: "field", label: "Icons Path",
                          description: "Trailing slash required", fallback: "" }
                    ]
                },
                {
                    title: "Compositor",
                    items: [
                        {
                            key: "hyprland.animations", type: "switch", label: "Animations",
                            description: "Applies immediately via hyprctl",
                            apply: "hyprAnimations", fallback: true
                        },
                        {
                            key: "hyprland.blur", type: "switch", label: "Window Blur",
                            description: "Applies immediately via hyprctl",
                            apply: "hyprBlur", fallback: true
                        }
                    ]
                },
                {
                    title: "Hyprland",
                    items: [
                        { key: "", type: "action", label: "Reload Hyprland",
                          description: "hyprctl reload", action: "hyprReload" },
                        { key: "", type: "action", label: "Restart Shell",
                          description: "Reload quickshell", action: "restartShell" }
                    ]
                },
                {
                    title: "Config",
                    items: [
                        { key: "", type: "action", label: "Edit config.json",
                          description: "Open in your editor", action: "editConfig" },
                        { key: "", type: "action", label: "Open Shell Folder",
                          action: "editShell" }
                    ]
                }
            ]
        }
    ]

    // ## Search
    // Filters the real items rather than a parallel index, so nothing can drift

    function search(query) {
        var needle = query.trim().toLowerCase()
        if (!needle)
            return []

        var hits = []
        for (var p = 0; p < pages.length; p++) {
            var page = pages[p]
            for (var g = 0; g < page.groups.length; g++) {
                var group = page.groups[g]
                for (var i = 0; i < group.items.length; i++) {
                    var item = group.items[i]
                    var haystack = (item.label + " " + (item.description || "")
                        + " " + (item.key || "") + " " + page.title + " " + group.title).toLowerCase()
                    if (haystack.indexOf(needle) !== -1) {
                        hits.push({
                            item: item,
                            pageId: page.id,
                            pageTitle: page.title,
                            groupTitle: group.title
                        })
                    }
                }
            }
        }
        return hits
    }
}
