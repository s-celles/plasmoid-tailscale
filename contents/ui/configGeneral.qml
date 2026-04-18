import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    property alias cfg_simulationMode: simulationCheck.checked
    property alias cfg_pollIntervalMs: pollSpin.value

    CheckBox {
        id: simulationCheck
        Kirigami.FormData.label: i18n("Simulation mode:")
        text: i18n("Use fixture data (demo / screenshots)")
    }

    Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        font.italic: true
        opacity: 0.7
        text: i18n("When enabled, the applet shows a fake tailnet with NATO-phonetic hostnames (alpha, bravo, …) and CGNAT IPs — the tailscale CLI is never called. Useful for demos, taking screenshots without leaking real hostnames/IPs, or developing without Tailscale installed.")
    }

    Item { Kirigami.FormData.isSection: true }

    SpinBox {
        id: pollSpin
        Kirigami.FormData.label: i18n("Poll interval:")
        from: 1000
        to: 300000
        stepSize: 1000
        editable: true
        textFromValue: function(value) { return (value / 1000) + " s"; }
        valueFromText: function(text) { return parseInt(text) * 1000; }
    }
}
