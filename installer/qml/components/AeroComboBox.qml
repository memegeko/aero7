import QtQuick
import QtQuick.Controls

ComboBox {
    id: control

    implicitHeight: 29
    focusPolicy: Qt.StrongFocus
    font.pixelSize: 13
    leftPadding: 7
    rightPadding: 27

    contentItem: Text {
        text: control.displayText
        color: control.enabled ? "#111111" : "#777777"
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        color: "#ffffff"
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? "#2d75b5" : "#747474"
    }

    indicator: Rectangle {
        width: 24
        height: control.height - 4
        x: control.width - width - 2
        y: 2
        border.width: 1
        border.color: control.pressed ? "#2b5d7d" : "#8a8a8a"
        gradient: Gradient {
            GradientStop { position: 0; color: control.pressed ? "#9bc4df" : "#fafafa" }
            GradientStop { position: 0.52; color: control.pressed ? "#d7e9f4" : "#e9e9e9" }
            GradientStop { position: 1; color: control.pressed ? "#f4f9fc" : "#cfcfcf" }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            text: "▼"
            color: "#111111"
            font.pixelSize: 9
        }
    }

    delegate: ItemDelegate {
        required property int index
        required property var modelData
        width: control.width - 2
        height: 25
        highlighted: control.highlightedIndex === index

        contentItem: Text {
            text: control.textRole ? modelData[control.textRole] : modelData
            color: parent.highlighted ? "white" : "#111111"
            font: control.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            color: parent.highlighted ? "#3399ff" : "#ffffff"
        }
    }

    popup: Popup {
        y: control.height - 1
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 2, 220)
        padding: 1

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            color: "#ffffff"
            border.width: 1
            border.color: "#555555"
        }
    }
}
