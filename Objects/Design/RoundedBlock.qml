import QtQuick.Controls.Basic
import QtQuick
import QtQuick.Shapes
import Quickshell
import Qt5Compat.GraphicalEffects

Pane {
    id: block
    property string color: root.wallpaperColors.colors[0];
    property int radius: 25;
    property double alpha: 0.8;
    property int sidePadding: 15
    property int tbPadding: 0

    // ── Angular mode ────────────────────────────────────────────────
    // When enabled the block is drawn as a polygon instead of a rounded
    // rectangle. Corners that sit on an edge of the bar window are left
    // perfectly square; every other corner is cut off at an angle, with
    // a very slight rounding on each end of the cut.
    property bool angular: false

    // Size of the diagonal cut. chamfer runs along the horizontal edge,
    // chamferHeight runs along the vertical edge. Equal values give 45°.
    property int chamfer: 14
    property int chamferHeight: chamfer

    // Rounding applied to the two ends of each diagonal cut.
    property int softRadius: 3

    // Which sides of this block sit flush against an edge of the bar.
    property bool flushTop: false
    property bool flushBottom: false
    property bool flushLeft: false
    property bool flushRight: false

    // A corner is square when it lands on one of those flush edges.
    readonly property bool squareTopLeft: flushTop || flushLeft
    readonly property bool squareTopRight: flushTop || flushRight
    readonly property bool squareBottomRight: flushBottom || flushRight
    readonly property bool squareBottomLeft: flushBottom || flushLeft

    readonly property string blockPath: block.buildPath(block.width, block.height)

    width: block.implicitWidth

    Behavior on width {
        NumberAnimation {
            duration: 250
            easing.type: Easing.InOutQuad
        }
    }

    // ── Path construction ───────────────────────────────────────────
    // Walks the four corners clockwise from the top left. A square corner
    // contributes one point, a cut corner contributes two.
    function buildPath(w, h) {
        if (w <= 0 || h <= 0)
            return ""

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

        return block.pathFromPoints(pts)
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

    background : Item {
        id: bg

        Rectangle {
            anchors.fill: parent
            visible: !block.angular
            color: block.color
            radius: block.radius
            opacity: block.alpha
        }

        Shape {
            anchors.fill: parent
            visible: block.angular
            antialiasing: true
            smooth: true
            opacity: block.alpha
            layer.enabled: true
            layer.samples: 8
            layer.smooth: true

            ShapePath {
                fillColor: block.color
                strokeColor: "transparent"
                strokeWidth: 0
                PathSvg { path: block.blockPath }
            }
        }

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 1
            verticalOffset: 1
            radius: 25
            samples: 100
            color: "#80000000"
        }
    }

    padding: 0
    leftPadding: sidePadding
    rightPadding: sidePadding
    topPadding: tbPadding
    bottomPadding: tbPadding
}
