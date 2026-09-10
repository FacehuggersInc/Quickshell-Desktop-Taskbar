import QtQuick.Controls.Basic
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell

import qs.Objects.Theme

Pane {
    id: block

    property color color: Theme.surface
    property int radius: Theme.radius
    property double alpha: 1.0
    property int sidePadding: 15
    property int tbPadding: 0

    // ## Glass
    // Blur itself is a window-level effect — the window sets
    // BackgroundEffect.blurRegion over this item. What lives here is the scrim,
    // the edge stroke and the top highlight that sit on top of that blur.

    property bool glass: Theme.glass
    property bool border: true
    property bool highlight: true

    // A cast shadow is a blurred copy of the shape, so on a chamfered block it
    // lands in the cut corner with nothing behind it but blur. Angular blocks
    // take their definition from the edge stroke instead.
    property bool elevated: !angular

    // ## Angular mode
    // Corners that sit on an edge of the bar stay square; the rest are cut at an
    // angle with a slight rounding on each end of the cut.

    property bool angular: false
    property int chamfer: Theme.chamfer
    property int chamferHeight: chamfer
    property int softRadius: Theme.softRadius

    property bool flushTop: false
    property bool flushBottom: false
    property bool flushLeft: false
    property bool flushRight: false

    readonly property bool squareTopLeft: flushTop || flushLeft
    readonly property bool squareTopRight: flushTop || flushRight
    readonly property bool squareBottomRight: flushBottom || flushRight
    readonly property bool squareBottomLeft: flushBottom || flushLeft

    // ## Blur region
    // A Region is built from rectangles, so it cannot express a diagonal or a
    // curve. Left as a plain rect it covers the cut corners, and the blurred
    // wallpaper showing through the cut reads as a dark wedge. This subtracts a
    // staircase from each corner instead, so the blur stops at the visible edge.

    readonly property int blurSteps: 4
    readonly property real cutW: angular ? Math.min(chamfer, width / 2)
                                         : Math.min(radius, width / 2)
    readonly property real cutH: angular ? Math.min(chamferHeight, height / 2)
                                         : Math.min(radius, height / 2)

    // corner: 0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left
    function cornerCut(corner) {
        if (!angular)
            return true
        if (corner === 0) return !squareTopLeft
        if (corner === 1) return !squareTopRight
        if (corner === 2) return !squareBottomRight
        return !squareBottomLeft
    }

    function cutRect(corner, i) {
        var w = block.cutW
        var h = block.cutH
        if (w <= 0 || h <= 0 || !block.cornerCut(corner))
            return { x: 0, y: 0, w: 0, h: 0 }

        var n = block.blurSteps
        var band = h / n
        var span

        if (block.angular) {
            span = w * (1 - i / n)
        } else {
            var d = h * i / n
            span = w - Math.sqrt(Math.max(0, w * w - (w - d) * (w - d)))
        }

        var top = (corner === 0 || corner === 1)
        var left = (corner === 0 || corner === 3)

        return {
            x: left ? 0 : block.width - span,
            y: top ? band * i : block.height - band * (i + 1),
            w: span,
            h: band
        }
    }

    readonly property Region blurRegion: Region {
        item: block
        regions: [
            Region {
                readonly property var r: block.cutRect(0, 0)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(0, 1)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(0, 2)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(0, 3)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(1, 0)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(1, 1)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(1, 2)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(1, 3)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(2, 0)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(2, 1)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(2, 2)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(2, 3)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(3, 0)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(3, 1)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(3, 2)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            },
            Region {
                readonly property var r: block.cutRect(3, 3)
                x: r.x; y: r.y; width: r.w; height: r.h
                intersection: Intersection.Subtract
            }
        ]
    }

    readonly property var blockPoints: block.cornerPoints(block.width, block.height)
    readonly property string blockPath: block.pathFromPoints(block.blockPoints)
    readonly property string blockTopPath: block.topSpanFromPoints(block.blockPoints)

    width: block.implicitWidth

    Behavior on width {
        NumberAnimation {
            duration: 250
            easing.type: Easing.InOutQuad
        }
    }

    // ## Path construction

    function cornerPoints(w, h) {
        if (w <= 0 || h <= 0)
            return []

        var cw = Math.min(block.chamfer, w / 2)
        var chh = Math.min(block.chamferHeight, h / 2)
        var pts = []

        if (block.squareTopLeft) {
            pts.push({ x: 0, y: 0, soft: false })
        } else {
            pts.push({ x: 0, y: chh, soft: true })
            pts.push({ x: cw, y: 0, soft: true })
        }

        if (block.squareTopRight) {
            pts.push({ x: w, y: 0, soft: false })
        } else {
            pts.push({ x: w - cw, y: 0, soft: true })
            pts.push({ x: w, y: chh, soft: true })
        }

        if (block.squareBottomRight) {
            pts.push({ x: w, y: h, soft: false })
        } else {
            pts.push({ x: w, y: h - chh, soft: true })
            pts.push({ x: w - cw, y: h, soft: true })
        }

        if (block.squareBottomLeft) {
            pts.push({ x: 0, y: h, soft: false })
        } else {
            pts.push({ x: cw, y: h, soft: true })
            pts.push({ x: 0, y: h - chh, soft: true })
        }

        return pts
    }

    function buildPath(w, h) {
        return block.pathFromPoints(block.cornerPoints(w, h))
    }

    // Pulls a point back from p toward q, never past the midpoint of the edge.
    function pullBack(p, q) {
        var dx = q.x - p.x
        var dy = q.y - p.y
        var len = Math.sqrt(dx * dx + dy * dy)
        if (len <= 0)
            return { x: p.x, y: p.y }
        var d = Math.min(block.softRadius, len / 2)
        return { x: p.x + dx / len * d, y: p.y + dy / len * d }
    }

    function pathFromPoints(pts) {
        var n = pts.length
        if (n === 0)
            return ""

        var out = []
        var started = false

        for (var i = 0; i < n; i++) {
            var p = pts[i]
            var prev = pts[(i - 1 + n) % n]
            var next = pts[(i + 1) % n]

            if (!p.soft || block.softRadius <= 0) {
                out.push((started ? "L " : "M ") + p.x.toFixed(2) + " " + p.y.toFixed(2))
                started = true
                continue
            }

            var a = block.pullBack(p, prev)
            var b = block.pullBack(p, next)

            out.push((started ? "L " : "M ") + a.x.toFixed(2) + " " + a.y.toFixed(2))
            started = true
            out.push("Q " + p.x.toFixed(2) + " " + p.y.toFixed(2)
                     + " " + b.x.toFixed(2) + " " + b.y.toFixed(2))
        }

        out.push("Z")
        return out.join(" ")
    }

    // The top run only, for the specular edge. Points are ordered clockwise from
    // the top left, so this is everything the top left and top right contribute.
    function topSpanFromPoints(pts) {
        var n = pts.length
        if (n === 0)
            return ""

        var tlCount = block.squareTopLeft ? 1 : 2
        var trCount = block.squareTopRight ? 1 : 2
        var start = tlCount - 1
        var end = tlCount + trCount - 1

        var out = []
        var started = false

        for (var i = start; i <= end && i < n; i++) {
            var p = pts[i]
            var prev = pts[(i - 1 + n) % n]
            var next = pts[(i + 1) % n]

            if (!p.soft || block.softRadius <= 0) {
                out.push((started ? "L " : "M ") + p.x.toFixed(2) + " " + p.y.toFixed(2))
                started = true
                continue
            }

            var a = block.pullBack(p, prev)
            var b = block.pullBack(p, next)

            out.push((started ? "L " : "M ") + a.x.toFixed(2) + " " + a.y.toFixed(2))
            started = true
            out.push("Q " + p.x.toFixed(2) + " " + p.y.toFixed(2)
                     + " " + b.x.toFixed(2) + " " + b.y.toFixed(2))
        }

        return out.join(" ")
    }

    background: Item {
        id: bg

        Rectangle {
            id: flatFill
            anchors.fill: parent
            visible: !block.angular
            color: block.color
            opacity: block.alpha
            radius: block.radius

            Rectangle {
                anchors.fill: parent
                visible: block.border
                color: "transparent"
                radius: parent.radius
                border.width: Theme.borderWidth
                border.color: Theme.border
            }

            Rectangle {
                visible: block.highlight
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: Theme.borderWidth
                anchors.leftMargin: parent.radius * 0.5
                anchors.rightMargin: parent.radius * 0.5
                height: Theme.borderWidth
                color: Theme.highlight
            }
        }

        Shape {
            id: angularFill
            anchors.fill: parent
            visible: block.angular
            antialiasing: true
            smooth: true
            opacity: block.alpha
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: block.color
                strokeColor: "transparent"
                strokeWidth: 0
                PathSvg { path: block.blockPath }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: block.border
                    ? (block.elevated ? Theme.border : Theme.borderStrong)
                    : "transparent"
                strokeWidth: Theme.borderWidth
                PathSvg { path: block.blockPath }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: block.highlight ? Theme.highlight : "transparent"
                strokeWidth: Theme.borderWidth
                PathSvg { path: block.blockTopPath }
            }
        }

        layer.enabled: block.elevated
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: 0.6
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
            blurMax: 24
        }
    }

    padding: 0
    leftPadding: sidePadding
    rightPadding: sidePadding
    topPadding: tbPadding
    bottomPadding: tbPadding
}
