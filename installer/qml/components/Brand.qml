import QtQuick

Item {
    id: root
    property int markSize: 108
    property int titleSize: 52
    property bool stacked: false
    property string edition: ""
    property color titleColor: "white"
    property color titleStyleColor: "#36516d"
    implicitWidth: root.stacked ? verticalBrand.implicitWidth : horizontalBrand.implicitWidth
    implicitHeight: root.stacked ? verticalBrand.implicitHeight : horizontalBrand.implicitHeight

    Row {
        id: horizontalBrand
        visible: !root.stacked
        anchors.centerIn: parent
        spacing: 13

        Image {
            width: root.markSize
            height: root.markSize
            source: "qrc:/assets/aero7-logo-plain.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                text: "Aero7"
                color: root.titleColor
                style: Text.Raised
                styleColor: root.titleStyleColor
                font.pixelSize: root.titleSize
                font.weight: Font.Light
                font.letterSpacing: -1
            }
            Text {
                visible: root.edition.length > 0
                anchors.baseline: parent.children[0].baseline
                text: root.edition
                color: root.titleColor
                style: Text.Raised
                styleColor: root.titleStyleColor
                font.pixelSize: Math.round(root.titleSize * 0.55)
                font.weight: Font.Light
            }
        }
    }

    Column {
        id: verticalBrand
        visible: root.stacked
        anchors.centerIn: parent
        spacing: 1

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.markSize
            height: root.markSize
            source: "qrc:/assets/aero7-logo-plain.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Text {
                text: "Aero7"
                color: root.titleColor
                style: Text.Raised
                styleColor: root.titleStyleColor
                font.pixelSize: root.titleSize
                font.weight: Font.Light
                font.letterSpacing: -1
            }
            Text {
                visible: root.edition.length > 0
                anchors.baseline: parent.children[0].baseline
                text: root.edition
                color: root.titleColor
                style: Text.Raised
                styleColor: root.titleStyleColor
                font.pixelSize: Math.round(root.titleSize * 0.55)
                font.weight: Font.Light
            }
        }
    }
}
