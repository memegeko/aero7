import QtQuick

Rectangle {
    id: root

    property real value: 0
    property bool animated: true

    implicitWidth: 420
    implicitHeight: 14
    radius: 1
    color: "#9daab6"
    border.width: 1
    border.color: "#71818f"
    clip: true

    Rectangle {
        x: 2
        y: 2
        width: Math.max(0, (parent.width - 4) * Math.min(100, Math.max(0, root.value)) / 100)
        height: parent.height - 4
        radius: 1
        gradient: Gradient {
            GradientStop { position: 0; color: "#c8ed70" }
            GradientStop { position: 0.45; color: "#9edb39" }
            GradientStop { position: 0.5; color: "#82c51d" }
            GradientStop { position: 1; color: "#6eaa18" }
        }
        Behavior on width {
            enabled: root.animated
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        x: 2
        y: 2
        width: parent.width - 4
        height: 3
        color: "#83ffffff"
    }
}
