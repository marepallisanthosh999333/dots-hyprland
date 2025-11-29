pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
    id: root
    property real memoryTotal: 1
    property real memoryFree: 0
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    // === CUSTOM MODIFICATION START: CPU Frequency and Temperature Support ===
    property double cpuFrequency: 0
    property double cpuTemperature: 0
    // === CUSTOM MODIFICATION END: CPU Frequency and Temperature Support ===
    property var previousCpuStats

    // === UPSTREAM: History tracking properties ===
    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []
    // === END UPSTREAM ===

    // === CUSTOM MODIFICATION START: Intel GPU Properties ===
    property bool iGpuAvailable: true
    property double iGpuUsage: 0
    property double iGpuVramUsage: 0
    property double iGpuTemperature: 0
    property double iGpuVramUsedGB: 0    
    property double iGpuVramTotalGB: 0
    // === CUSTOM MODIFICATION END: Intel GPU Properties ===

    // === CUSTOM MODIFICATION START: Network Speed Properties ===
    property string networkInterface: ""
    property double networkDownloadSpeed: 0  // bytes per second
    property double networkUploadSpeed: 0    // bytes per second
    property double networkTotalSpeed: 0     // bytes per second
    // === CUSTOM MODIFICATION END: Network Speed Properties ===

    // === CUSTOM MODIFICATION START: Fan Monitoring Properties ===
    property int fanCount: 0
    property double fanActivity: 0         // Average fan activity percentage
    property double fanTemperature: 0      // Average fan temperature
    property double fanMaxActivity: 0      // Peak fan activity
    // === CUSTOM MODIFICATION END: Fan Monitoring Properties ===

    // === CUSTOM MODIFICATION START: Disk Monitoring Properties ===
    property var diskPartitions: []  // Array of {name, used, size, usage} objects
    property string mainDiskDevice: ""
    // === CUSTOM MODIFICATION END: Disk Monitoring Properties ===

    // === UPSTREAM: History helper functions ===
    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
    }
    // === END UPSTREAM ===

    Timer {
        interval: 1
        running: true 
        repeat: true
        onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()
            // === CUSTOM MODIFICATION START: Add CPU info file ===
            fileCpuinfo.reload()
            // === CUSTOM MODIFICATION END: Add CPU info file ===

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }

            // === CUSTOM MODIFICATION START: CPU Frequency Parsing ===
            // Parse CPU frequency
            const cpuInfo = fileCpuinfo.text()
            const cpuCoreFrequencies = cpuInfo.match(/cpu MHz\s+:\s+(\d+\.\d+)/g)
            if (cpuCoreFrequencies) {
                const frequencies = cpuCoreFrequencies.map(x => Number(x.match(/(\d+\.\d+)/)[1]))
                const cpuCoreFrequencyAvg = frequencies.reduce((a, b) => a + b, 0) / frequencies.length
                cpuFrequency = cpuCoreFrequencyAvg / 1000
            }
            // === CUSTOM MODIFICATION END: CPU Frequency Parsing ===

            // === CUSTOM MODIFICATION START: Process CPU temperature ===
            tempProc.running = true
            // === CUSTOM MODIFICATION END: Process CPU temperature ===

            // === CUSTOM MODIFICATION START: Process Intel GPU info ===
            if(iGpuAvailable){
                iGpuinfoProc.running = true
            }
            // === CUSTOM MODIFICATION END: Process Intel GPU info ===

            // === CUSTOM MODIFICATION START: Process Network speed info ===
            networkSpeedProc.running = true
            // === CUSTOM MODIFICATION END: Process Network speed info ===

            // === CUSTOM MODIFICATION START: Process Fan info ===
            fanInfoProc.running = true
            // === CUSTOM MODIFICATION END: Process Fan info ===

            // === CUSTOM MODIFICATION START: Process Disk info ===
            diskInfoProc.running = true
            // === CUSTOM MODIFICATION END: Process Disk info ===

            // === UPSTREAM: Update history tracking ===
            root.updateHistories()
            // === END UPSTREAM ===

            interval = Config.options?.resources?.updateInterval ?? 3000
        }
    }

    FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }
    // === CUSTOM MODIFICATION START: Add CPU info file ===
    FileView { id: fileCpuinfo; path: "/proc/cpuinfo" }
    // === CUSTOM MODIFICATION END: Add CPU info file ===

    // === UPSTREAM: CPU max frequency detection ===
    Process {
        id: findCpuMaxFreqProc
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }
    // === END UPSTREAM ===

    // === CUSTOM MODIFICATION START: CPU Temperature Process ===
    Process {
        id: tempProc
        command: [
            "/bin/bash",
            "-c",
            "paste <(cat /sys/class/thermal/thermal_zone*/type) <(cat /sys/class/thermal/thermal_zone*/temp) | grep x86_pkg_temp | awk '{print $2}'"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const temp = parseInt(this.text.trim())
                cpuTemperature = isNaN(temp) ? 0 : temp / 1000
            }
        }
    }
    // === CUSTOM MODIFICATION END: CPU Temperature Process ===

    // === CUSTOM MODIFICATION START: Intel GPU Monitoring Process ===
    Process {
        id: iGpuinfoProc
        command: ["bash", "-c", `${Directories.scriptPath}/gpu/get_igpuinfo.sh`.replace(/file:\/\//, "")]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                iGpuAvailable = this.text.indexOf("Intel GPU tools not found") === -1
                if(iGpuAvailable){
                    iGpuUsage = this.text.match(/\s+Usage\s*:\s*(\d+)/)?.[1] / 100 ?? 0
                    const vramLine = this.text.match(/\s+VRAM\s*:\s*(\d+(?:\.\d+)?)\/(\d+(?:\.\d+)?)\s*GB/)
                    iGpuVramUsedGB = Number(vramLine?.[1] ?? 0)
                    iGpuVramTotalGB = Number(vramLine?.[2] ?? 0)
                    iGpuVramUsage = iGpuVramTotalGB > 0 ? (iGpuVramUsedGB / iGpuVramTotalGB) : 0;
                    iGpuTemperature = this.text.match(/\s+Temp\s*:\s*(\d+(?:\.\d+)?)/)?.[1] ?? 0 
                }
            }
        }
    }
    // === CUSTOM MODIFICATION END: Intel GPU Monitoring Process ===

    // === CUSTOM MODIFICATION START: Network Speed Monitoring Process ===
    Process {
        id: networkSpeedProc
        command: ["bash", "-c", `${Directories.scriptPath}/network/get_networkspeed.sh`.replace(/file:\/\//, "")]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const interfaceLine = this.text.match(/Interface:\s*(\w+)/)
                networkInterface = interfaceLine?.[1] ?? ""
                
                const downloadLine = this.text.match(/Download:\s*(\d+)\s*B\/s/)
                networkDownloadSpeed = Number(downloadLine?.[1] ?? 0)
                
                const uploadLine = this.text.match(/Upload:\s*(\d+)\s*B\/s/)
                networkUploadSpeed = Number(uploadLine?.[1] ?? 0)
                
                const totalLine = this.text.match(/Total:\s*(\d+)\s*B\/s/)
                networkTotalSpeed = Number(totalLine?.[1] ?? 0)
            }
        }
    }
    // === CUSTOM MODIFICATION END: Network Speed Monitoring Process ===

    // === CUSTOM MODIFICATION START: Fan Monitoring Process ===
    Process {
        id: fanInfoProc
        command: ["bash", "-c", `${Directories.scriptPath}/system/get_faninfo_thermal.sh`.replace(/file:\/\//, "")]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const countLine = this.text.match(/Fan Count:\s*(\d+)/)
                fanCount = Number(countLine?.[1] ?? 0)
                
                const activityLine = this.text.match(/Fan Activity:\s*(\d+(?:\.\d+)?)%/)
                fanActivity = Number(activityLine?.[1] ?? 0) / 100
                
                const tempLine = this.text.match(/Fan Temperature:\s*(\d+(?:\.\d+)?)°C/)
                fanTemperature = Number(tempLine?.[1] ?? 0)
                
                const maxActivityLine = this.text.match(/Max Activity:\s*(\d+(?:\.\d+)?)%/)
                fanMaxActivity = Number(maxActivityLine?.[1] ?? 0) / 100
            }
        }
    }
    // === CUSTOM MODIFICATION END: Fan Monitoring Process ===

    // === CUSTOM MODIFICATION START: Disk Monitoring Process ===
    Process {
        id: diskInfoProc
        command: ["bash", "-c", `${Directories.scriptPath}/system/get_diskinfo.sh`.replace(/file:\/\//, "")]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split('\n')
                let partitions = []
                
                for (const line of lines) {
                    if (line.startsWith('Partition:')) {
                        const parts = line.split(':')
                        if (parts.length >= 5) {
                            partitions.push({
                                name: parts[1],
                                used: parts[2],
                                size: parts[3],
                                usage: Number(parts[4])
                            })
                        }
                    } else if (line.startsWith('MainDisk:')) {
                        mainDiskDevice = line.split(':')[1] || ""
                    }
                }
                
                diskPartitions = partitions
            }
        }
    }
    // === CUSTOM MODIFICATION END: Disk Monitoring Process ===
}
