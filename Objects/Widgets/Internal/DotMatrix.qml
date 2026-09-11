import QtQuick

import qs.Objects.Theme

Item {
    id: matrix

    property string text: ""
    property real dotSize: 2
    property real dotGap: 1
    property real charGap: 3
    property color onColor: Theme.accentText
    property color offColor: Theme.alpha(Theme.textBase, 0.07)
    property bool showUnlit: true

    // Lit dots sit on a dark offset twin. Without it the display disappears
    // into a pale wallpaper, since the lit colour is itself light in dark mode.
    // Off by default. A per-dot halo is nearly as wide as the dot itself, so
    // neighbouring halos merge and the glyph reads as a smudge rather than a
    // grid. Kept as an option for very pale wallpapers.
    property bool shadow: false
    property color shadowColor: Qt.rgba(0, 0, 0, 0.62)
    property real shadowSpread: 2

    // 5x7 cells, one string per row. Colon is narrow.
    readonly property var glyphs: ({
        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["01110", "10001", "00001", "00110", "00001", "10001", "01110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
        "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
        ":": ["0", "0", "1", "0", "0", "1", "0"],
        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "M": ["10001", "11011", "10101", "10001", "10001", "10001", "10001"],
        "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
        " ": ["0", "0", "0", "0", "0", "0", "0"]
    })

    readonly property real cell: dotSize + dotGap
    readonly property real glyphHeight: 7 * cell - dotGap

    implicitHeight: glyphHeight
    implicitWidth: row.implicitWidth

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: matrix.charGap

        Repeater {
            model: matrix.text.split("")

            delegate: Item {
                id: glyph
                required property string modelData

                readonly property var rows: matrix.glyphs[modelData]
                    ? matrix.glyphs[modelData] : matrix.glyphs[" "]
                readonly property int columns: rows[0].length

                width: columns * matrix.cell - matrix.dotGap
                height: matrix.glyphHeight

                Repeater {
                    model: glyph.rows.length * glyph.columns

                    delegate: Item {
                        id: cell
                        required property int index

                        readonly property int rowIndex: Math.floor(index / glyph.columns)
                        readonly property int colIndex: index % glyph.columns
                        readonly property bool lit:
                            glyph.rows[rowIndex].charAt(colIndex) === "1"

                        visible: lit || matrix.showUnlit
                        x: colIndex * matrix.cell
                        y: rowIndex * matrix.cell
                        width: matrix.dotSize
                        height: matrix.dotSize

                        Rectangle {
                            visible: cell.lit && matrix.shadow
                            anchors.centerIn: parent
                            width: matrix.dotSize + matrix.shadowSpread
                            height: matrix.dotSize + matrix.shadowSpread
                            radius: width / 2
                            color: matrix.shadowColor
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: matrix.dotSize / 2
                            color: cell.lit ? matrix.onColor : matrix.offColor

                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        }
                    }
                }
            }
        }
    }
}
