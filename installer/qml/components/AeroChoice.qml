import QtQuick

Rectangle {
    id: root

    property string iconSource
    property string title
    property string detail
    property bool selected: false
    property bool compact: false
    signal chosen

    activeFocusOnTab: enabled
    implicitHeight: compact ? 72 : 88
    radius: 2
    color: enabled && (mouse.containsMouse || selected) ? "#eef9ff" : "transparent"
    border.width: enabled && (activeFocus || mouse.containsMouse || selected) ? 1 : 0
    border.color: activeFocus ? "#45a9df" : "#79c9ee"

    Image {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: root.compact ? 42 : 54
        height: width
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: root.enabled ? 1 : 0.38
    }

    Text {
        id: titleLabel
        anchors.left: icon.right
        anchors.leftMargin: 13
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: root.compact ? 10 : 12
        text: root.title
        color: root.enabled ? "#0067b1" : "#8c9297"
        font.pixelSize: root.compact ? 15 : 16
        font.underline: root.enabled && (mouse.containsMouse || activeFocus)
    }

    Text {
        anchors.left: titleLabel.left
        anchors.right: titleLabel.right
        anchors.top: titleLabel.bottom
        anchors.topMargin: 4
        text: root.detail
        color: root.enabled ? "#33414b" : "#989da1"
        font.pixelSize: 12
        lineHeight: 1.12
        wrapMode: Text.WordWrap
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.forceActiveFocus()
            root.chosen()
        }
    }

    Keys.onReturnPressed: if (root.enabled) root.chosen()
    Keys.onEnterPressed: if (root.enabled) root.chosen()
    Keys.onSpacePressed: if (root.enabled) root.chosen()
}
