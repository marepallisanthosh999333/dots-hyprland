import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool alwaysShowAllResources: false
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: true

    RowLayout {
        id: rowLayout

        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Resource {
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            warningThreshold: Config.options.bar.resources.memoryWarningThreshold
        }

        Resource {
            iconName: "swap_horiz"
            percentage: ResourceUsage.swapUsedPercentage
            shown: (Config.options.bar.resources.alwaysShowSwap && percentage > 0) || 
                (MprisController.activePlayer?.trackTitle == null) ||
                root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.swapWarningThreshold
        }

        Resource {
            iconName: "planner_review"
            percentage: ResourceUsage.cpuUsage
            shown: Config.options.bar.resources.alwaysShowCpu || 
                !(MprisController.activePlayer?.trackTitle?.length > 0) ||
                root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.cpuWarningThreshold
        }

        // === CUSTOM MODIFICATION START: Intel GPU Resource Display ===
        Resource {
            iconName: "empty_dashboard"
            percentage: ResourceUsage.iGpuUsage
            shown: (Config.options.bar.resources.alwaysShowGpu || 
                !(MprisController.activePlayer?.trackTitle?.length > 0) ||
                root.alwaysShowAllResources) && ResourceUsage.iGpuAvailable && (Config.options.bar.resources.gpuLayout == 1)
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.gpuWarningThreshold
        }
        // === CUSTOM MODIFICATION END: Intel GPU Resource Display ===

        // === CUSTOM MODIFICATION START: Network Speed Resource Display ===
        Resource {
            iconName: "network_check"
            // Cast to int percentage with safety check (100% = 50MB/s total)
            percentage: Math.round((ResourceUsage.networkTotalSpeed || 0) / (50 * 1024 * 1024) * 100)
            shown: Config.options.bar.networkSpeed.enable && (
                !(MprisController.activePlayer?.trackTitle?.length > 0) ||
                root.alwaysShowAllResources
            )
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: 95 // Only warn at 95% (very high usage)
        }
        // === CUSTOM MODIFICATION END: Network Speed Resource Display ===

    }

    ResourcesPopup {
        hoverTarget: root
    }
}
