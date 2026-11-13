import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import "ui" as UI

Item {
    id: root

    property var host: null
    property var model: null
    readonly property color taskAccent: model ? model.taskColor : "#88c8ae"
    property bool history: false
    property string expanded: ""
    property date dayClock: new Date()
    readonly property string today: Qt.formatDate(dayClock, "yyyy-MM-dd")

    function t(k) {
        return host ? host.t(k) : k;
    }

    function change(data, callback) {
        if (model)
            model.taskAction(data, callback);

    }

    function sync() {
        var rows = model ? model.tasks : [];
        rows = rows.filter(function(r) {
            return root.history || !r.done || (r.completedDay || r.day) >= root.today;
        });
        for (var j = items.count - 1; j >= 0; j--) if (!rows.some(function(r) {
            return r.id === items.get(j).taskId;
        })) {
            items.remove(j);
        }
        for (var i = 0; i < rows.length; i++) {
            var pos = -1;
            for (var k = i; k < items.count; k++) if (items.get(k).taskId === rows[i].id) {
                pos = k;
                break;
            }
            var row = {
                "taskId": rows[i].id,
                "title": rows[i].title,
                "note": rows[i].note || "",
                "done": rows[i].done,
                "priority": rows[i].priority,
                "day": rows[i].day
            };
            if (pos < 0) {
                items.insert(i, row);
            } else {
                if (pos !== i)
                    items.move(pos, i, 1);

                items.set(i, row);
            }
        }
    }

    objectName: "daily-page"
    onTodayChanged: sync()
    onModelChanged: sync()
    onHistoryChanged: sync()

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.dayClock = new Date()
    }

    Connections {
        function onTasksChanged() {
            root.sync();
        }

        target: root.model
    }

    ListModel {
        id: items
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            Column {
                spacing: 3

                PlainLabel {
                    text: root.t("dailyTitle")
                    font.pixelSize: 19
                    font.weight: Font.Bold
                }

                PlainLabel {
                    text: root.t("dailySubtitle")
                    font.pixelSize: 10
                    color: "#98989f"
                }

            }

            Item {
                Layout.fillWidth: true
            }

            NotchButton {
                text: root.t(root.history ? "dailyToday" : "dailyHistory")
                compact: true
                onClicked: root.history = !root.history
            }

            UI.IconButton {
                iconName: "undo-2"
                hint: root.t("undoDelete")
                onClicked: root.change({
                    "op": "undo"
                })
            }

        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Field {
                id: newTask

                objectName: "task-input"
                Layout.fillWidth: true
                placeholderText: root.t("taskPlaceholder")
                maximumLength: 280
                onAccepted: add.clicked()
            }

            UI.IconButton {
                id: add

                objectName: "task-add"
                iconName: "plus"
                hint: root.t("addTask")
                filled: true
                circular: true
                enabled: newTask.text.trim().length > 0
                onClicked: {
                    root.change({
                        "op": "add",
                        "title": newTask.text
                    });
                    newTask.clear();
                }
            }

        }

        ListView {
            id: list

            objectName: "task-list"
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: items
            clip: true
            spacing: 7

            Column {
                visible: items.count === 0
                anchors.centerIn: parent
                spacing: 8

                UI.Icon {
                    name: "check"
                    size: 28
                    opacity: 0.5
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                PlainLabel {
                    text: root.t("dailyEmpty")
                    color: "#92929c"
                    font.pixelSize: 12
                }

            }

            ScrollBar.vertical: ScrollBar {
            }

            add: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Style.duration(140)
                    }

                    NumberAnimation {
                        property: "x"
                        from: 12
                        to: 0
                        duration: Style.duration(140)
                    }

                }

            }

            moveDisplaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: Style.duration(180)
                    easing.type: Easing.OutCubic
                }

            }

            displaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: Style.duration(150)
                    easing.type: Easing.OutCubic
                }

            }

            delegate: Rectangle {
                id: card

                required property string taskId
                required property string title
                required property string note
                required property bool done
                required property int priority
                required property string day
                required property int index
                property bool open: root.expanded === taskId

                width: list.width
                height: open ? 205 : 53
                radius: 12
                color: done ? "#08ffffff" : "#0fffffff"
                border.width: 1
                border.color: open ? Qt.rgba(root.taskAccent.r, root.taskAccent.g, root.taskAccent.b, 0.6) : "#12ffffff"

                RowLayout {
                    height: 32
                    spacing: 9

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 10
                    }

                    AbstractButton {
                        implicitWidth: 25
                        implicitHeight: 25
                        Accessible.name: root.t("completeTask")
                        onClicked: root.change({
                            "op": "toggle",
                            "id": card.taskId
                        })

                        background: Rectangle {
                            radius: 8
                            color: card.done ? root.taskAccent : "transparent"
                            border.color: card.done ? root.taskAccent : "#65ffffff"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Style.duration(150)
                                }

                            }

                        }

                        contentItem: Item {
                            UI.Icon {
                                visible: card.done
                                anchors.centerIn: parent
                                name: "check"
                                color: "#182822"
                                size: 15
                            }

                        }

                    }

                    PlainLabel {
                        text: card.title
                        Layout.fillWidth: true
                        font.pixelSize: 12
                        font.strikeout: card.done
                        color: card.done ? "#85858e" : "#f2f2f4"

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expanded = card.open ? "" : card.taskId
                        }

                    }

                    Rectangle {
                        visible: card.priority !== 1
                        width: 5
                        height: 18
                        radius: 3
                        color: card.priority === 2 ? "#e5a67e" : "#7fa5c0"
                    }

                    UI.IconButton {
                        iconName: "chevron-up"
                        hint: root.t("moveUp")
                        implicitWidth: 22
                        enabled: card.index > 0
                        onClicked: root.change({
                            "op": "move",
                            "id": card.taskId,
                            "direction": -1,
                            "relativeId": items.get(card.index - 1).taskId
                        })
                    }

                    UI.IconButton {
                        objectName: "task-down-" + card.taskId
                        iconName: "chevron-down"
                        hint: root.t("moveDown")
                        implicitWidth: 22
                        enabled: card.index < items.count - 1
                        onClicked: root.change({
                            "op": "move",
                            "id": card.taskId,
                            "direction": 1,
                            "relativeId": items.get(card.index + 1).taskId
                        })
                    }

                    UI.IconButton {
                        iconName: "trash-2"
                        hint: root.t("deleteTask")
                        implicitWidth: 22
                        onClicked: root.change({
                            "op": "delete",
                            "id": card.taskId
                        })
                    }

                }

                ColumnLayout {
                    visible: card.open
                    spacing: 8

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: 55
                        leftMargin: 12
                        rightMargin: 12
                    }

                    Field {
                        id: editTitle

                        Layout.fillWidth: true
                        text: card.title
                        maximumLength: 280
                        Accessible.name: root.t("taskTitle")
                    }

                    TextArea {
                        id: detail

                        objectName: "task-note-" + card.taskId
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        text: card.note
                        textFormat: TextEdit.PlainText
                        onTextChanged: {
                            if (length > 2000) {
                                var cut = 2000, last = text.charCodeAt(cut - 1);
                                if (last >= 55296 && last <= 56319)
                                    cut--;

                                remove(cut, length);
                            }
                        }
                        placeholderText: root.t("taskDetail")
                        font.pixelSize: 11
                        color: "white"
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true

                        background: Rectangle {
                            radius: 8
                            color: "#0affffff"
                        }

                    }

                    RowLayout {
                        Repeater {
                            model: [root.t("priorityLow"), root.t("priorityNormal"), root.t("priorityHigh")]

                            NotchButton {
                                required property string modelData
                                required property int index

                                text: modelData
                                compact: true
                                selected: card.priority === index
                                accent: root.taskAccent
                                onClicked: root.change({
                                    "op": "edit",
                                    "id": card.taskId,
                                    "priority": index
                                })
                            }

                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        NotchButton {
                            objectName: "task-save-" + card.taskId
                            text: root.t("saveTask")
                            enabled: editTitle.text.trim().length > 0 && !!root.model && !root.model.taskBusy
                            compact: true
                            selected: true
                            accent: root.taskAccent
                            onClicked: {
                                root.change({
                                    "op": "edit",
                                    "id": card.taskId,
                                    "title": editTitle.text,
                                    "note": detail.text
                                }, function(ok) {
                                    if (ok && root)
                                        root.expanded = "";

                                });
                            }
                        }

                    }

                }

                Behavior on height {
                    NumberAnimation {
                        duration: Style.duration(170)
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Style.duration(160)
                    }

                }

                ListView.onRemove: SequentialAnimation {
                    PropertyAction {
                        target: card
                        property: "ListView.delayRemove"
                        value: true
                    }

                    ParallelAnimation {
                        NumberAnimation {
                            target: card
                            property: "opacity"
                            to: 0
                            duration: Style.duration(130)
                        }

                        NumberAnimation {
                            target: card
                            property: "x"
                            to: 28
                            duration: Style.duration(130)
                        }

                    }

                    PropertyAction {
                        target: card
                        property: "ListView.delayRemove"
                        value: false
                    }

                }

            }

        }

        RowLayout {
            PlainLabel {
                text: root.t("taskAccent")
                font.pixelSize: 10
                color: "#85858d"
            }

            Repeater {
                model: ["#88c8ae", "#b5a2e0", "#e8b883", "#83b8dc", "#e59cae", "#d2c377"]

                UI.CircleChoice {
                    required property string modelData

                    implicitWidth: 24
                    implicitHeight: 24
                    swatch: modelData
                    selected: root.model && root.taskAccent.toString() === modelData
                    hint: root.t("taskAccent")
                    onClicked: root.change({
                        "op": "color",
                        "color": modelData
                    })
                }

            }

            Item {
                Layout.fillWidth: true
            }

            PlainLabel {
                text: root.today
                font.pixelSize: 10
                color: "#8a8a92"
            }

        }

    }

}
