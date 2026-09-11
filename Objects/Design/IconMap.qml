pragma Singleton

import QtQuick

QtObject {
    id: map

    // ## Material Symbols
    // The font renders an icon from its name as a ligature, so most of our
    // names pass straight through. Only the ones we invented need translating.

    property string family: "Material Symbols Rounded"
    property string mode: "auto"

    readonly property bool fontPresent:
        Qt.fontFamilies().indexOf(map.family) !== -1

    readonly property bool useFont:
        mode === "font" ? true : (mode === "images" ? false : map.fontPresent)

    readonly property var aliases: ({
        "backlight_high": "brightness_high",
        "backlight_low": "brightness_low",
        "backlight_off": "brightness_empty",
        "brightness": "brightness_medium",
        "copy_content": "content_copy",
        "filter": "colorize",
        "hide": "visibility_off",
        "show": "visibility",
        "masked": "theater_comedy",
        "masked_add": "add_circle",
        "media_input": "mic_external_on",
        "media_output": "speaker",
        "microphone": "mic",
        "microphone_alert": "mic",
        "microphone_mute": "mic_off",
        "music_note_single": "music_note",
        "music_pause": "pause",
        "music_play": "play_arrow",
        "music_prev": "skip_previous",
        "music_skip": "skip_next",
        "no": "block",
        "notify": "notifications",
        "notify_unread": "notifications_active",
        "open_app": "open_in_new",
        "open_folder": "folder_open",
        "pin": "push_pin",
        "unpin": "keep_off",
        "restart": "restart_alt",
        "screenshot": "screenshot_monitor",
        "stop": "power_settings_new",
        "volume_max": "volume_up",
        "volume_min": "volume_down",
        "volume_mute": "volume_off",
        "vpn": "vpn_lock",
        "wired": "lan",
        "wifi_max": "wifi"
    })

    function glyph(name) {
        if (!name)
            return "help"
        return map.aliases[name] !== undefined ? map.aliases[name] : name
    }
}
