import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    // Helper function to format KB to GB
    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    // === CUSTOM MODIFICATION START: Network Speed Formatting Helper ===
    // Helper function to format network speed
    function formatNetworkSpeed(bytesPerSecond) {
        if (bytesPerSecond < 1024) {
            return bytesPerSecond.toFixed(0) + " B/s";
        } else if (bytesPerSecond < 1024 * 1024) {
            return (bytesPerSecond / 1024).toFixed(1) + " KB/s";
        } else if (bytesPerSecond < 1024 * 1024 * 1024) {
            return (bytesPerSecond / (1024 * 1024)).toFixed(1) + " MB/s";
        } else {
            return (bytesPerSecond / (1024 * 1024 * 1024)).toFixed(1) + " GB/s";
        }
    }
    // === CUSTOM MODIFICATION END: Network Speed Formatting Helper ===

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

    component ResourceHeaderItem: Row {
        id: headerItem
        required property var icon
        required property var label
        spacing: 5

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            fill: 0
            font.weight: Font.Medium
            text: headerItem.icon
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnSurfaceVariant
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: headerItem.label
            font {
                weight: Font.Medium
                pixelSize: Appearance.font.pixelSize.normal
            }
            color: Appearance.colors.colOnSurfaceVariant
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 12

        Column {
            anchors.top: parent.top
            spacing: 8

            ResourceHeaderItem {
                icon: "memory"
                label: "RAM"
            }
            Column {
                spacing: 4
                ResourceItem {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatKB(ResourceUsage.memoryUsed)
                }
                ResourceItem {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: root.formatKB(ResourceUsage.memoryFree)
                }
                ResourceItem {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatKB(ResourceUsage.memoryTotal)
                }
            }
        }

        Column {
            visible: ResourceUsage.swapTotal > 0
            anchors.top: parent.top
            spacing: 8

            ResourceHeaderItem {
                icon: "swap_horiz"
                label: "Swap"
            }
            Column {
                spacing: 4
                ResourceItem {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatKB(ResourceUsage.swapUsed)
                }
                ResourceItem {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: root.formatKB(ResourceUsage.swapFree)
                }
                ResourceItem {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatKB(ResourceUsage.swapTotal)
                }
            }
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            ResourceHeaderItem {
                icon: "planner_review"
                label: "CPU"
            }
            Column {
                spacing: 4
                ResourceItem {
                    icon: "bolt"
                    label: Translation.tr("Load:")
                    value: (ResourceUsage.cpuUsage > 0.8 ? Translation.tr("High") : ResourceUsage.cpuUsage > 0.4 ? Translation.tr("Medium") : Translation.tr("Low")) + ` (${Math.round(ResourceUsage.cpuUsage * 100)}%)`
                }
                // === CUSTOM MODIFICATION START: CPU Frequency Display ===
                ResourceItem {
                    icon: "planner_review"
                    label: Translation.tr("Freq:")
                    value: `${Math.round(ResourceUsage.cpuFrequency * 100) / 100} GHz`
                }
                // === CUSTOM MODIFICATION END: CPU Frequency Display ===
                // === CUSTOM MODIFICATION START: CPU Temperature Display ===
                ResourceItem {
                    icon: "thermometer"
                    label: Translation.tr("Temp:")
                    value: `${Math.round(ResourceUsage.cpuTemperature)} °C`
                }
                // === CUSTOM MODIFICATION END: CPU Temperature Display ===
            }
        }

        // === CUSTOM MODIFICATION START: Intel GPU Column ===
        Column {
            visible: ResourceUsage.iGpuAvailable && (Config.options.bar.resources.gpuLayout == 1)
            anchors.top: parent.top
            spacing: 8

            ResourceHeaderItem {
                icon: "empty_dashboard"
                label: "Intel GPU"
            }
            Column {
                spacing: 4
                ResourceItem {
                    icon: "bolt"
                    label: Translation.tr("Load:")
                    value: (ResourceUsage.iGpuUsage > 0.8 ? Translation.tr("High") : ResourceUsage.iGpuUsage > 0.4 ? Translation.tr("Medium") : Translation.tr("Low")) + ` (${Math.round(ResourceUsage.iGpuUsage * 100)}%)`
                }
                ResourceItem {
                    icon: "clock_loader_60"
                    label: Translation.tr("VRAM:")
                    value: `${Math.round(ResourceUsage.iGpuVramUsedGB * 10) / 10} / ${Math.round(ResourceUsage.iGpuVramTotalGB * 10) / 10} GB`
                }
                ResourceItem {
                    icon: "thermometer"
                    label: Translation.tr("Temp:")
                    value: `${ResourceUsage.iGpuTemperature} °C`
                }
            }
        }
        // === CUSTOM MODIFICATION END: Intel GPU Column ===

        // === CUSTOM MODIFICATION START: Network Speed Column ===
        Column {
            visible: Config.options.bar.networkSpeed.enable
            anchors.top: parent.top
            spacing: 8

            ResourceHeaderItem {
                icon: "network_check"
                label: "Network"
            }
            Column {
                spacing: 4
                ResourceItem {
                    icon: "download"
                    label: Translation.tr("Download:")
                    value: formatNetworkSpeed(ResourceUsage.networkDownloadSpeed)
                }
                ResourceItem {
                    icon: "upload"
                    label: Translation.tr("Upload:")
                    value: formatNetworkSpeed(ResourceUsage.networkUploadSpeed)
                }
                ResourceItem {
                    icon: "network_check"
                    label: Translation.tr("Interface:")
                    value: ResourceUsage.networkInterface || "N/A"
                }
            }
        }
        // === CUSTOM MODIFICATION END: Network Speed Column ===

        // === CUSTOM MODIFICATION START: Fan Monitoring Column ===
        Column {
            visible: ResourceUsage.fanCount > 0
            anchors.top: parent.top
            spacing: 8

            ResourceHeaderItem {
                icon: "mode_fan"
                label: "Fans"
            }
            Column {
                spacing: 4
                ResourceItem {
                    icon: "bolt"
                    label: Translation.tr("Activity:")
                    value: (ResourceUsage.fanActivity > 0.8 ? Translation.tr("High") : ResourceUsage.fanActivity > 0.4 ? Translation.tr("Medium") : Translation.tr("Low")) + ` (${Math.round(ResourceUsage.fanActivity * 100)}%)`
                }
                ResourceItem {
                    icon: "trending_up"
                    label: Translation.tr("Peak:")
                    value: `${Math.round(ResourceUsage.fanMaxActivity * 100)}%`
                }
                ResourceItem {
                    icon: "device_thermostat"
                    label: Translation.tr("Count:")
                    value: `${ResourceUsage.fanCount} fans`
                }
                ResourceItem {
                    icon: "thermometer"
                    label: Translation.tr("Temp:")
                    value: `${Math.round(ResourceUsage.fanTemperature)} °C`
                }
            }
        }
        // === CUSTOM MODIFICATION END: Fan Monitoring Column ===

        // === CUSTOM MODIFICATION START: Disk Storage Column ===
        Column {
            anchors.top: parent.top
            spacing: 8
            ResourceHeaderItem {
                icon: "storage"
                label: "Storage"
            }

            Column {
                spacing: 4

                Repeater {
                    model: ResourceUsage.diskPartitions
                    delegate: ResourceItem {
                        required property var modelData
                        icon: (modelData.name === "Root") ? "home" : (modelData.name === "home") ? "folder" : (modelData.name === "boot") ? "settings" : "hard_drive"
                        label: modelData.name + ":"
                        value: modelData.used + "/" + modelData.size + " (" + modelData.usage + "%)"
                    }
                }

                ResourceItem {
                    icon: "device_thermostat"
                    label: Translation.tr("Device:")
                    value: ResourceUsage.mainDiskDevice || "N/A"
                }
            }
        }
        // === CUSTOM MODIFICATION END: Disk Storage Column ===
    }
}
