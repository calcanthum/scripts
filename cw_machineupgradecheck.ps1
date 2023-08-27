# This script checks some basic machine info, like system drive type and size, RAM type and size, and the battery status
# in order to quote on upgrades/replacements. It also returns the manufacturer and serial number for manual verification.
# It returns a 1 if an upgrade is indicated, with the details placed in a text file in the C Windows Temp folder.
# It returns a 0 if no upgrade is indicated.

# settings
$minRAMSizeGB = 8
$targetMediaType = "HDD"
$outputFilePath = "C:\Windows\Temp\cw_machine_upgrade_info.txt"
$debugMode = $false
$debugFilePath = "C:\Windows\Temp\cw_machine_upgrade_debug.txt"

# debug
function Write-DebugInfo {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($debugMode) {
        Add-Content -Path $debugFilePath -Value "$timestamp - $message"
    }
}

# c drive type and size
function Get-DiskInfo {
    $systemDiskPartition = Get-Partition | Where-Object { $_.DriveLetter -eq 'C' }
    $systemDisk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq $systemDiskPartition.DiskNumber }
    $sizeGB = [math]::Round($systemDisk.Size / 1GB)
    return "$($systemDisk.MediaType), ${sizeGB}GB"
}
# ram size, speed, form factor
function Get-RAMInfo {
    $memory = Get-WmiObject -Class Win32_PhysicalMemory
    $ramInfo = @()
    $moduleIndex = 1
    
    # map speed to type
    $ddrTypeMapping = @(
        @{Start=400; End=1066; Type="DDR2 (Guess)"},
        @{Start=800; End=2133; Type="DDR3 (Guess)"},
        @{Start=2133; End=4266; Type="DDR4 (Guess)"},
        @{Start=4800; End=10000; Type="DDR5 (Guess)"}
    )
    
    foreach ($m in $memory) {
        $speed = $m.Speed
        $ddrType = $ddrTypeMapping | Where-Object { $speed -ge $_.Start -and $speed -le $_.End } | Select-Object -ExpandProperty Type
        $ddrType = if ($ddrType) { $ddrType } else { "Unknown" }
        
        if ($m.FormFactor -eq 8) {
            $formFactor = "DIMM"
        } elseif ($m.FormFactor -eq 12) {
            $formFactor = "SODIMM"
        } else {
            $formFactor = "Unknown Form Factor"
        }

        $ramSizeGB = [math]::Round($m.Capacity / 1GB)
        
        $ramInfo += "Module ${moduleIndex}: $formFactor, $ddrType, ${ramSizeGB}GB, ${speed}MHz"
        $moduleIndex++
    }
    
    return $ramInfo -join '; '
}


# get battery info
function Get-BatteryInfo {
    $battery = Get-WmiObject -Class Win32_Battery
    if ($null -eq $battery) {
        return ""  # no battery, skip
    }
    $status = $battery.Status
    if ($status -ne "OK") {
        $charge = $battery.EstimatedChargeRemaining
        $runtime = $battery.EstimatedRunTime
        return "Battery: Status $status, Charge $charge%, Runtime $runtime min"
    }
    return ""
}

# machine manufacturer and serial
function Get-MachineInfo {
    $bios = Get-WmiObject -Class Win32_BIOS
    return "Manufacturer: $($bios.Manufacturer); SerialNumber: $($bios.SerialNumber)"
}

# debug initialization
if ($debugMode) {
    if (Test-Path $debugFilePath) {
        Remove-Item -Path $debugFilePath
    }
    New-Item -Path $debugFilePath -ItemType File
}

# collect info
Write-DebugInfo "DEBUG: Collecting disk information..."
$diskInfo = Get-DiskInfo
Write-DebugInfo "DEBUG: Disk Info: $diskInfo"

Write-DebugInfo "DEBUG: Collecting RAM information..."
$ramInfo = Get-RAMInfo
Write-DebugInfo "DEBUG: RAM Info: $ramInfo"

Write-DebugInfo "DEBUG: Collecting machine information..."
$machineInfo = Get-MachineInfo
Write-DebugInfo "DEBUG: Machine Info: $machineInfo"

Write-DebugInfo "DEBUG: Collecting battery information..."
$batteryInfo = Get-BatteryInfo
Write-DebugInfo "DEBUG: Battery Info: $batteryInfo"

# are upgrades needed?
$upgradeNeeded = $false
$upgradeInfo = @()

# check disk
if ($diskInfo -match $targetMediaType) {
    $upgradeNeeded = $true
    $upgradeInfo += "Disk: $diskInfo"
}

# check ram
$ramSizeTotal = 0
foreach ($item in ($ramInfo -split "; ")) {
    if ($item -match "(\d+)GB") {
        $ramSizeTotal += [int]$matches[1]
    }
}
if ($ramSizeTotal -lt $minRAMSizeGB) {
    $upgradeNeeded = $true
    $upgradeInfo += "RAM: $ramInfo"
}

# check battery
if ($batteryInfo -ne "") {
    $upgradeNeeded = $true
    $upgradeInfo += "Battery: $batteryInfo"
}

# prepare output
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$upgradeStatus = if ($upgradeNeeded) { 1 } else { 0 }
$outputInfo = "$timestamp; $upgradeStatus; Machine Info: $machineInfo; " + ($upgradeInfo -join "; ")

# write output
Set-Content -Path $outputFilePath -Value $outputInfo
