pragma Singleton

import QtQuick

QtObject {
    id: theme

    // ## Inputs — assigned from shell.qml

    property bool darkMode: true
    property bool glass: true
    property string accentSource: "fixed"
    property color accentFixed: "#6b5d62"
    property color accentSeed: "#6b5d62"
    property real scrimStrength: 1.0
    // "protocol" blurs through ext-background-effect-v1, which takes a region of
    // rectangles and so only approximates a chamfer. "compositor" leaves the
    // region unset and lets Hyprland blur from the surface alpha instead, which
    // follows the drawn shape exactly but needs layer rules in hyprland.conf.
    property string blurMode: "protocol"

    // "still" captures one frame per layout change, "live" runs a video feed per
    // window, "off" falls back to letters everywhere
    property string previewMode: "still"
    property string fontFamily: "JetBrainsMono"

    // ## Worst-case backdrop
    // Blur shows whatever is behind the surface, so contrast is only safe if it
    // holds against the extreme: a pure white wallpaper in dark mode, pure black
    // in light mode. Every readable token below is checked against this.

    readonly property color scrimBase: darkMode ? Qt.rgba(0.043, 0.051, 0.063, 1)
                                                : Qt.rgba(0.957, 0.965, 0.973, 1)

    readonly property real scrimAlpha: {
        var base = darkMode ? 0.68 : 0.66
        return Math.min(0.96, Math.max(0.30, base * scrimStrength))
    }

    readonly property color scrim: Qt.rgba(scrimBase.r, scrimBase.g, scrimBase.b,
                                           glass ? scrimAlpha : 1.0)

    // A bar block is a thin strip and reads fine over a busy wallpaper. A tall
    // panel full of text does not, so panels and fullscreen overlays each get a
    // heavier scrim than the bar.
    property real panelDimStrength: 1.0
    property real overlayDimStrength: 1.0

    readonly property color panelScrim: {
        var base = glass ? 0.88 : 1.0
        var a = Math.min(0.99, Math.max(0.35, base * panelDimStrength))
        return Qt.rgba(scrimBase.r, scrimBase.g, scrimBase.b, a)
    }

    readonly property color overlayScrim: {
        var base = glass ? 0.72 : 0.94
        var a = Math.min(0.98, Math.max(0.20, base * overlayDimStrength))
        return Qt.rgba(scrimBase.r, scrimBase.g, scrimBase.b, a)
    }

    readonly property color backdropWorst: glass
        ? composite(scrim, darkMode ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1))
        : Qt.rgba(scrimBase.r, scrimBase.g, scrimBase.b, 1)

    readonly property real backdropLum: luminance(backdropWorst)

    // ## Surfaces

    readonly property color bg: darkMode ? "#0d0f12" : "#f4f6f8"
    readonly property color surface: scrim
    readonly property color surfaceRaised: darkMode
        ? Qt.rgba(1, 1, 1, glass ? 0.06 : 0.10)
        : Qt.rgba(0, 0, 0, glass ? 0.05 : 0.07)
    readonly property color surfaceSunken: darkMode ? Qt.rgba(0, 0, 0, 0.22)
                                                    : Qt.rgba(0, 0, 0, 0.07)

    // ## Glass edges
    // A flat stroke plus a brighter top run. Not refraction — Wayland will not
    // let a shell read the pixels behind itself — but it reads as an edge.

    readonly property color border: darkMode ? Qt.rgba(1, 1, 1, 0.08)
                                             : Qt.rgba(0, 0, 0, 0.07)
    readonly property color borderStrong: darkMode ? Qt.rgba(1, 1, 1, 0.14)
                                                   : Qt.rgba(0, 0, 0, 0.12)
    readonly property color highlight: darkMode ? Qt.rgba(1, 1, 1, 0.30)
                                                : Qt.rgba(1, 1, 1, 0.72)
    // Glass surfaces sit closer to the wallpaper than opaque ones, so the cast
    // shadow is pulled back when blur is on
    readonly property color shadow: glass
        ? Qt.rgba(0, 0, 0, darkMode ? 0.34 : 0.15)
        : Qt.rgba(0, 0, 0, darkMode ? 0.50 : 0.22)
    readonly property int borderWidth: 1

    // ## Text
    // Never tinted by the accent. One neutral that is guaranteed readable, plus
    // two reduced-emphasis steps off the same hue.

    readonly property color textBase: darkMode ? "#eef1f4" : "#12161a"
    readonly property color text: readable(textBase, 4.5)
    readonly property color textDim: Qt.rgba(text.r, text.g, text.b, 0.72)
    readonly property color textMute: Qt.rgba(text.r, text.g, text.b, 0.45)
    readonly property color textInvert: darkMode ? "#12161a" : "#f4f6f8"

    // ## Accent
    // One hue. accent is for fills and indicators, accentText is the same hue
    // pushed until it clears 4.5:1 against the worst-case backdrop so icons and
    // small text stay legible whatever the wallpaper does.

    readonly property real accentSatMin: 0.40
    readonly property real accentSatMax: darkMode ? 0.80 : 0.85
    readonly property real accentLightMin: darkMode ? 0.55 : 0.32
    readonly property real accentLightMax: darkMode ? 0.74 : 0.48

    readonly property color accentRaw: accentSource === "wallpaper" ? accentSeed : accentFixed
    readonly property color accent: clampAccent(accentRaw)
    readonly property color accentText: readable(accent, 4.5)
    readonly property color accentIcon: readable(accent, 3.0)
    readonly property color accentHover: shiftLight(accent, darkMode ? 0.07 : -0.07)
    readonly property color accentPressed: shiftLight(accent, darkMode ? -0.07 : 0.07)
    readonly property color accentDim: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
    readonly property color accentLine: Qt.rgba(accent.r, accent.g, accent.b, 0.45)
    readonly property color onAccent: luminance(accent) > 0.35 ? "#12161a" : "#f4f6f8"

    // ## Status

    readonly property color danger: readable(darkMode ? "#f2695c" : "#c0392b", 4.5)
    readonly property color warn: readable(darkMode ? "#e8b04b" : "#a8730f", 4.5)
    readonly property color ok: readable(darkMode ? "#68c98a" : "#2c7a4b", 4.5)

    // ## Geometry

    readonly property int radiusSmall: 8
    readonly property int radius: 15
    readonly property int radiusLarge: 22
    readonly property int chamfer: 14
    readonly property int softRadius: 3

    // ## Control metrics
    // Shared by every control so rows line up without each call site guessing

    readonly property int rowHeight: 44
    readonly property int controlHeight: 26
    readonly property int controlMinWidth: 92
    readonly property int gap: 10
    readonly property int sectionGap: 18
    readonly property int pagePadding: 18

    readonly property int labelSize: 12
    readonly property int descSize: 11
    readonly property int valueSize: 11

    // ## Motion

    readonly property int durFast: 120
    readonly property int durNormal: 180
    readonly property int durSlow: 280

    // ## Compat map
    // The five keys the existing tree reads through root.theme. Kept so the
    // migration does not have to touch every call site at once.

    readonly property var legacy: ({
        "background": panelScrim,
        "surface": surface,
        "primary": accentIcon,
        "secondary": accentDim,
        "text": text
    })

    // ## Color math

    function channel(v) {
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    }

    function luminance(c) {
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }

    function contrast(a, b) {
        var la = luminance(a)
        var lb = luminance(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }

    function contrastOnBackdrop(c) {
        var lc = luminance(c)
        return (Math.max(lc, backdropLum) + 0.05) / (Math.min(lc, backdropLum) + 0.05)
    }

    function composite(fg, bg) {
        var a = fg.a
        return Qt.rgba(fg.r * a + bg.r * (1 - a),
                       fg.g * a + bg.g * (1 - a),
                       fg.b * a + bg.b * (1 - a), 1)
    }

    function shiftLight(c, delta) {
        var l = Math.min(1, Math.max(0, c.hslLightness + delta))
        var h = c.hslHue < 0 ? 0 : c.hslHue
        return Qt.hsla(h, c.hslSaturation, l, c.a)
    }

    function clampAccent(seed) {
        var s = seed.hslSaturation
        var h = seed.hslHue

        // A near-grey seed has no usable hue, so keep the configured one
        if (s < 0.08 || h < 0) {
            h = accentFixed.hslHue < 0 ? 0 : accentFixed.hslHue
            s = Math.max(accentFixed.hslSaturation, accentSatMin)
        }

        s = Math.min(Math.max(s, accentSatMin), accentSatMax)
        var l = Math.min(Math.max(seed.hslLightness, accentLightMin), accentLightMax)
        return Qt.hsla(h, s, l, 1)
    }

    // Walks lightness away from the backdrop until the ratio is met. Hue and
    // saturation are held so the accent stays recognisably one colour.
    function readable(c, target) {
        var out = c
        if (contrastOnBackdrop(out) >= target)
            return out

        var step = darkMode ? 0.02 : -0.02
        for (var i = 0; i < 40; i++) {
            out = shiftLight(out, step)
            if (contrastOnBackdrop(out) >= target)
                return out
            if (out.hslLightness <= 0.001 || out.hslLightness >= 0.999)
                break
        }
        return darkMode ? Qt.rgba(1, 1, 1, c.a) : Qt.rgba(0, 0, 0, c.a)
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
}
