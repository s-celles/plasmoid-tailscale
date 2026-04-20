import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    readonly property bool tsRunning: tsBackendState === "Running"
    property string tsBackendState: "Unknown"
    property string tsIP: ""
    property string tsHostname: ""
    property var tsPeers: []
    property string lastError: ""

    Plasmoid.icon: tsRunning ? "network-vpn" : "network-disconnect"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus

    toolTipMainText: tsRunning
        ? i18n("Tailscale: connected")
        : i18n("Tailscale: disconnected")
    toolTipSubText: tsRunning
        ? (tsIP + " · " + i18np("%1 peer", "%1 peers", tsPeers.length))
        : i18n("Click to open")

    P5Support.DataSource {
        id: ds
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            ds.disconnectSource(sourceName);
            if (sourceName.indexOf("status --json") >= 0) {
                if (data["exit code"] === 0 && data.stdout) {
                    try {
                        root.parseStatus(JSON.parse(data.stdout));
                        root.lastError = "";
                    } catch (e) {
                        root.tsBackendState = "Error";
                        root.lastError = "parse: " + e;
                    }
                } else {
                    root.tsBackendState = "Stopped";
                    root.lastError = data.stderr || "";
                }
            } else {
                // après un toggle on rafraîchit
                Qt.callLater(root.refresh);
            }
        }

        function run(cmd) {
            connectSource(cmd);
        }
    }

    function parseStatus(s) {
        root.tsBackendState = s.BackendState || "Unknown";
        if (s.Self) {
            root.tsIP = (s.Self.TailscaleIPs || [])[0] || "";
            root.tsHostname = s.Self.HostName || "";
        }
        var peers = [];
        var raw = s.Peer || {};
        for (var k in raw) {
            var p = raw[k];
            peers.push({
                hostname: p.HostName || "",
                dns: (p.DNSName || "").replace(/\.$/, ""),
                ip: (p.TailscaleIPs || [])[0] || "",
                os: p.OS || "",
                online: !!p.Online
            });
        }
        peers.sort(function (a, b) { return a.hostname.localeCompare(b.hostname); });
        root.tsPeers = peers;
    }

    // Données fictives utilisées quand simulationMode=true. Noms OTAN +
    // IPs CGNAT (100.64.0.0/10) volontairement différentes d'un vrai
    // tailnet → safe pour demos, screenshots, dev sans Tailscale.
    readonly property var fixtureStatus: ({
        BackendState: "Running",
        Self: {
            HostName: "demo-host",
            TailscaleIPs: ["100.64.99.1"]
        },
        Peer: {
            "alpha":   { HostName: "alpha",   DNSName: "alpha.example.ts.net.",   TailscaleIPs: ["100.64.99.10"], OS: "linux",   Online: true  },
            "bravo":   { HostName: "bravo",   DNSName: "bravo.example.ts.net.",   TailscaleIPs: ["100.64.99.11"], OS: "linux",   Online: true  },
            "charlie": { HostName: "charlie", DNSName: "charlie.example.ts.net.", TailscaleIPs: ["100.64.99.12"], OS: "macOS",   Online: true  },
            "delta":   { HostName: "delta",   DNSName: "delta.example.ts.net.",   TailscaleIPs: ["100.64.99.13"], OS: "windows", Online: false },
            "echo":    { HostName: "echo",    DNSName: "echo.example.ts.net.",    TailscaleIPs: ["100.64.99.14"], OS: "android", Online: true  },
            "foxtrot": { HostName: "foxtrot", DNSName: "foxtrot.example.ts.net.", TailscaleIPs: ["100.64.99.15"], OS: "iOS",     Online: true  },
            "golf":    { HostName: "golf",    DNSName: "golf.example.ts.net.",    TailscaleIPs: ["100.64.99.16"], OS: "linux",   Online: false }
        }
    })

    function refresh() {
        if (Plasmoid.configuration.simulationMode) {
            root.parseStatus(root.fixtureStatus);
            root.lastError = "";
            return;
        }
        ds.run("tailscale status --json 2>&1");
    }

    function toggleConnection() {
        if (Plasmoid.configuration.simulationMode) {
            // En mode démo, on bascule juste BackendState localement.
            root.tsBackendState = tsRunning ? "Stopped" : "Running";
            if (!tsRunning) {
                root.tsPeers = [];
                root.tsIP = "";
            } else {
                root.parseStatus(root.fixtureStatus);
            }
            return;
        }
        var cmd = tsRunning ? "tailscale down" : "tailscale up";
        ds.run("pkexec " + cmd + " 2>&1");
    }

    Timer {
        interval: Plasmoid.configuration.pollIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Presse-papiers via TextEdit invisible (méthode standard QML).
    TextEdit {
        id: clipboardHelper
        visible: false
    }
    function copyToClipboard(text) {
        clipboardHelper.text = text;
        clipboardHelper.selectAll();
        clipboardHelper.copy();
    }

    compactRepresentation: MouseArea {
        id: compactMouse
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true

        onClicked: function (mouse) {
            if (mouse.button === Qt.MiddleButton) {
                root.toggleConnection();
            } else {
                root.expanded = !root.expanded;
            }
        }

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: compactMouse.containsMouse
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 24

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: Plasmoid.icon
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaExtras.Heading {
                        level: 3
                        text: "Tailscale"
                    }
                    PlasmaComponents.Label {
                        text: root.tsRunning
                            ? (root.tsHostname + " · " + root.tsIP)
                            : i18n("Disconnected")
                        elide: Text.ElideRight
                        opacity: 0.7
                        Layout.fillWidth: true
                        font: Kirigami.Theme.smallFont
                    }
                }

                PlasmaComponents.Button {
                    text: root.tsRunning ? i18n("Disconnect") : i18n("Connect")
                    icon.name: root.tsRunning ? "network-disconnect" : "network-connect"
                    onClicked: root.toggleConnection()
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                text: i18n("Tailnet machines") + " (" + root.tsPeers.length + ")"
                font.bold: true
                visible: root.tsPeers.length > 0
            }

            PlasmaComponents.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                visible: root.tsPeers.length > 0

                ListView {
                    id: peerList
                    model: root.tsPeers
                    spacing: 0
                    clip: true

                    delegate: Rectangle {
                        width: peerList.width
                        height: peerRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                        color: peerMouse.containsMouse
                            ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                      Kirigami.Theme.highlightColor.g,
                                      Kirigami.Theme.highlightColor.b, 0.15)
                            : "transparent"

                        MouseArea {
                            id: peerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.copyToClipboard(modelData.ip)
                        }

                        RowLayout {
                            id: peerRow
                            anchors.fill: parent
                            anchors.leftMargin: Kirigami.Units.smallSpacing
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.smallSpacing

                            // pastille online/offline
                            Rectangle {
                                width: Kirigami.Units.smallSpacing * 1.5
                                height: width
                                radius: width / 2
                                color: modelData.online ? "#2ecc71" : "#95a5a6"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: modelData.hostname
                                    elide: Text.ElideRight
                                }
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: modelData.ip
                                    opacity: 0.6
                                    font: Kirigami.Theme.smallFont
                                    elide: Text.ElideRight
                                }
                            }

                            PlasmaComponents.Label {
                                text: modelData.os
                                opacity: 0.5
                                font: Kirigami.Theme.smallFont
                                visible: modelData.os !== ""
                            }
                        }
                    }
                }
            }

            // Empty / error state
            PlasmaExtras.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Kirigami.Units.largeSpacing
                visible: root.tsPeers.length === 0
                iconName: root.tsRunning ? "network-vpn" : "network-disconnect"
                text: root.tsRunning
                    ? i18n("No peers in the tailnet")
                    : i18n("Tailscale is disabled")
                explanation: root.tsRunning
                    ? ""
                    : (root.lastError !== "" ? root.lastError : i18n("Enable the connection to see machines"))
            }
        }
    }
}
