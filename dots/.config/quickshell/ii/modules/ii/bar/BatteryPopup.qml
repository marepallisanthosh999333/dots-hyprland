import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    clampToScreen: true

    component ResourceItem: RowLayout {
        id: resourceItem
        required property string icon
        required property string label
        required property string value
        spacing: 4

        MaterialSymbol {
            text: resourceItem.icon
            color: Appearance.colors.colOnSurfaceVariant
            iconSize: Appearance.font.pixelSize.large
        }
        StyledText {
            text: resourceItem.label
            color: Appearance.colors.colOnSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            visible: resourceItem.value !== ""
            color: Appearance.colors.colOnSurfaceVariant
            text: resourceItem.value
        }
    }

    component ResourceCard: Rectangle {
        id: card
        required property string icon
        required property string label
        required property int shapeType
        required property color accentColor
        required property color onAccentColor
        default property alias content: innerContent.children

        color: Appearance.colors.colSurfaceContainerHigh
        radius: Appearance.rounding.large
        Layout.minimumWidth: 220
        Layout.preferredWidth: 240
        implicitWidth: cardLayout.implicitWidth + 32
        implicitHeight: cardLayout.implicitHeight + 32

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                spacing: 12
                MaterialShape {
                    shape: card.shapeType
                    implicitSize: 36
                    color: card.accentColor

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: card.icon
                        iconSize: Appearance.font.pixelSize.normal
                        color: card.onAccentColor
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: card.label
                    font.family: Appearance.font.family.title
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnSurface
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 2
                color: Appearance.colors.colSurfaceContainerHighest
                radius: 1
            }

            ColumnLayout {
                id: innerContent
                spacing: 4
            }
            
            Item { Layout.fillHeight: true }
        }
    }

    ResourceCard {
        anchors.centerIn: parent
        icon: Battery.isCharging ? "battery_charging_full" : "battery_std"
        label: {
            let pct = Math.round(Battery.percentage * 100);
            if (pct >= 100 || Battery.chargeState == 4) return Translation.tr("Fully charged");
            if (pct <= 1) { // Handle bug where backend is faulty showing 1%
                if (Battery.chargeState == 1) return Translation.tr("Charging");
                if (Battery.chargeState == 2) return Translation.tr("Discharging");
                return Translation.tr("Battery");
            }
            return Translation.tr("Battery") + ` (${pct}%)`;
        }
        shapeType: MaterialShape.Shape.Cookie6Sided
        accentColor: Appearance.colors.colPrimaryContainer
        onAccentColor: Appearance.colors.colOnPrimaryContainer

        ResourceItem {
            visible: {
                let timeValue = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
                let power = Battery.energyRate;
                return !(Battery.chargeState == 4 || timeValue <= 0 || power <= 0.01);
            }
            icon: "schedule"
            label: Battery.isCharging ? Translation.tr("Time to full:") : Translation.tr("Time to empty:")
            value: {
                function formatTime(seconds) {
                    var h = Math.floor(seconds / 3600);
                    var m = Math.floor((seconds % 3600) / 60);
                    if (h > 0) return `${h}h, ${m}m`;
                    return `${m}m`;
                }
                return Battery.isCharging ? formatTime(Battery.timeToFull) : formatTime(Battery.timeToEmpty);
            }
        }

        ResourceItem {
            visible: !(Battery.chargeState != 4 && Battery.energyRate == 0)
            icon: "bolt"
            label: {
                if (Battery.chargeState == 4) return Translation.tr("Status:");
                if (Battery.chargeState == 1) return Translation.tr("Charging:");
                return Translation.tr("Discharging:");
            }
            value: {
                if (Battery.chargeState == 4) return Translation.tr("Full");
                return `${Battery.energyRate.toFixed(2)}W`;
            }
        }

        ResourceItem {
            icon: "heart_check"
            label: Translation.tr("Health:")
            value: `${(Battery.health).toFixed(1)}%`
        }
    }
}
