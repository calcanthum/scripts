# Script: Machine Upgrade Checker for ConnectWise Automate Agents
#
# Description:
#   - Assesses a Windows machine to determine if a hardware upgrade is needed.
#   - Specifically checks:
#       1. Type and size of system drive
#       2. RAM type and size
#   - Gathers machine manufacturer and serial number for verification.
#
# Outputs:
#   1. If upgrade needed: Returns '1' and writes details to C:\Windows\Temp\cw_machine_upgrade_info.txt
#   2. If no upgrade needed: Returns '0'
#
# Settings:
#   - $minRAMSizeGB: Minimum acceptable RAM size in GB.
#   - $upgradeFromMediaType: Type of media to trigger an upgrade (e.g., "HDD").
#   - $outputFilePath: File path for storing machine info if an upgrade is needed.
#   - $debugMode: If $true, debug information is saved.
#   - $debugFilePath: File path for storing debug info.

# settings
$minRAMSizeGB = 8
$upgradeFromMediaType = "HDD"
$outputFilePath = "C:\Windows\Temp\cw_machine_upgrade_info.txt"
$debugMode = $false
$debugFilePath = "C:\Windows\Temp\cw_machine_upgrade_debug.txt"

# Check if disk upgrade is needed
function Test-DiskUpgrade {
    param ([string]$diskInfo)
    $mediaType, $sizeGB, $health = $diskInfo -split ', '
    
    if ($mediaType -eq $upgradeFromMediaType -or $health -ne "OK") {
        return $true
    } else {
        return $false
    }
}

# Check if RAM upgrade is needed
function Test-RAMUpgrade {
    param ([int]$totalRamSize)
    
    if ($totalRamSize -lt $minRAMSizeGB) {
        return $true
    } else {
        return $false
    }
}

# debug function
function Set-DebugInfo {
    param ([string]$message)
    if ($debugMode) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $debugFilePath -Value "DEBUG ${timestamp}: $message"
    }
}

# c drive info and health
function Get-DiskInfo {
    $systemDiskPartition = Get-Partition | Where-Object { $_.DriveLetter -eq 'C' }
    $systemDisk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq $systemDiskPartition.DiskNumber }
    $sizeGB = [math]::Round($systemDisk.Size / 1GB)
    $healthStatus = $systemDisk.OperationalStatus

    if ($healthStatus -ne "OK") {
        Set-Host "Drive health is not OK. Status: $healthStatus"
        Set-DebugInfo "Drive health is not OK. Status: $healthStatus"
    }

    return "$($systemDisk.MediaType), ${sizeGB}GB, Health: $healthStatus"
}


# ram size, speed, form factor
function Get-RAMInfo {
    $memory = Get-WmiObject -Class Win32_PhysicalMemory
    $ramInfo = @()
    $ramSizeTotal = 0
    
    # mapping form factors
    $formFactorMap = @{
        8 = "DIMM";
        12 = "SODIMM"
    }
    
    foreach ($m in $memory) {
        $ramSizeGB = [math]::Round($m.Capacity / 1GB)
        $ramSizeTotal += $ramSizeGB
        $formFactor = $formFactorMap[$m.FormFactor] -or "Unknown Form Factor"
        $speed = $m.Speed

        # mapping speed to type
        $ddrType = switch ($speed) {
            { $_ -in 400..1066 } { "DDR2 (best guess)" }
            { $_ -in 800..2133 } { "DDR3 (best guess)" }
            { $_ -in 2133..4266 } { "DDR4 (best guess)" }
            { $_ -in 4800..10000 } { "DDR5 (best guess)" }
            default { "Unknown" }
        }

        $ramInfo += "Module $ramSizeGB GB $formFactor $ddrType $speed MHz"
    }
    
    return $ramInfo -join '; ', $ramSizeTotal
}

# machine manufacturer and serial
function Get-MachineInfo {
    $bios = Get-WmiObject -Class Win32_BIOS
    return "Manufacturer $($bios.Manufacturer); SerialNumber $($bios.SerialNumber)"
}

# debug file initialization
if ($debugMode -and (Test-Path $debugFilePath)) {
    Remove-Item -Path $debugFilePath
}
if ($debugMode) {
    New-Item -Path $debugFilePath -ItemType File
}

# Collect info
$diskInfo = Get-DiskInfo
$ramInfo, $totalRamSize = Get-RAMInfo
$machineInfo = Get-MachineInfo

# Check for upgrades
$upgradeNeeded = $false
$upgradeDetails = @()

# Disk upgrade check
if (Test-DiskUpgrade -diskInfo $diskInfo) {
    $upgradeNeeded = $true
    $upgradeDetails += "Disk_Needs_Upgrade: $diskInfo"
}

# RAM upgrade check
if (Test-RAMUpgrade -totalRamSize $totalRamSize) {
    $upgradeNeeded = $true
    $upgradeDetails += "RAM_Needs_Upgrade: $ramInfo"
}

# prepare output for the text file only if upgrade needed
if ($upgradeNeeded) {
    if (Test-Path $outputFilePath) {
        Remove-Item -Path $outputFilePath
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $upgradeStatus = 1
    
    # Modified the output format
    $outputInfo = @"
    Timestamp: $timestamp
    Upgrade Status: $upgradeStatus
    Machine Info: $machineInfo

    $(if ($diskInfo -match $upgradeFromMediaType -or $diskInfo -notmatch "Health: OK") {"Disk: $diskInfo (Needs Upgrade)"})
    $(if ($ramSizeTotal -lt $minRAMSizeGB) {"RAM: $ramInfo (Needs Upgrade)"})
"@
    Set-Content -Path $outputFilePath -Value $outputInfo
} else {
    $upgradeStatus = 0
}

# output 1 or 0 for ConnectWise Automate agent
[Console]::Write($upgradeStatus)
