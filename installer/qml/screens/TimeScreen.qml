pragma ComponentBehavior: Bound
import QtQuick
import "../components"

SetupPage {
    id: page
    anchors.fill: parent
    title: qsTr("Review your time and date settings")
    description: ""
    showBack: true

    property date now: new Date()
    property int calendarYear: now.getFullYear()
    property int calendarMonth: now.getMonth()
    property int firstWeekday: new Date(calendarYear, calendarMonth, 1).getDay()
    property int daysInMonth: new Date(calendarYear, calendarMonth + 1, 0).getDate()

    Timer { interval: 1000; running: true; repeat: true; onTriggered: page.now = new Date() }

    body: [
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 7

            Text { text: qsTr("Time zone:"); color: "#25323b"; font.pixelSize: 12 }
            AeroComboBox {
                width: 500
                model: ["Europe/Amsterdam", "Europe/London", "Europe/Berlin", "America/New_York", "America/Los_Angeles", "Asia/Tokyo"]
                currentIndex: Math.max(0, model.indexOf(controller.timezone))
                onActivated: controller.timezone = currentText
            }

            AeroCheckBox {
                checked: true
                text: qsTr("Automatically adjust the clock for Daylight Saving Time")
            }

            Item { width: 1; height: 7 }

            Row {
                spacing: 42

                Column {
                    spacing: 6

                    Text { text: qsTr("Date:"); color: "#25323b"; font.pixelSize: 12 }

                    Rectangle {
                        width: 235
                        height: 182
                        color: "#ffffff"
                        border.color: "#c3c9cd"

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 8
                            text: Qt.formatDate(page.now, "MMMM yyyy")
                            color: "#24313b"
                            font.pixelSize: 13
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.top: parent.top
                            anchors.topMargin: 7
                            text: "‹"
                            color: "#34434d"
                            font.pixelSize: 15
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.top: parent.top
                            anchors.topMargin: 7
                            text: "›"
                            color: "#34434d"
                            font.pixelSize: 15
                        }

                        Grid {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.top: parent.top
                            anchors.topMargin: 35
                            columns: 7
                            rowSpacing: 1

                            Repeater {
                                model: [qsTr("Su"), qsTr("Mo"), qsTr("Tu"), qsTr("We"), qsTr("Th"), qsTr("Fr"), qsTr("Sa")]
                                Text {
                                    required property string modelData
                                    width: 30
                                    height: 19
                                    text: modelData
                                    color: "#3e4c55"
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Repeater {
                                model: 42
                                Item {
                                    required property int index
                                    property int dayNumber: index - page.firstWeekday + 1
                                    width: 30
                                    height: 19

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 23
                                        height: 18
                                        visible: parent.dayNumber === page.now.getDate()
                                        color: "#c9eaff"
                                        border.color: "#3a9bd4"
                                    }
                                    Text {
                                        anchors.fill: parent
                                        visible: parent.dayNumber > 0 && parent.dayNumber <= page.daysInMonth
                                        text: parent.dayNumber
                                        color: "#26333d"
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: 170
                    spacing: 7
                    Text { text: qsTr("Time:"); color: "#25323b"; font.pixelSize: 12 }
                    AnalogClock { anchors.horizontalCenter: parent.horizontalCenter; width: 150; height: 150; now: page.now }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatTime(page.now, "h:mm:ss AP")
                        color: "#25323b"
                        font.pixelSize: 12
                    }
                }
            }
        }
    ]
}
