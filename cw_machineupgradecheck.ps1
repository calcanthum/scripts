# This script checks some basic machine info: system drive and RAM type/size in order to quote on upgrades/replacements.
# It also returns the manufacturer and serial number for manual verification.
# 
# It returns a 1 if an upgrade is indicated, with the details placed in a text file in the C Windows Temp folder.
# It returns a 0 if no upgrade is indicated.

# settings
$minRAMSizeGB = 8
$upgradeFromMediaType = "HDD"
$outputFilePath = "C:\Windows\Temp\cw_machine_upgrade_info.txt"
$debugMode = $true
$debugFilePath = "C:\Windows\Temp\cw_machine_upgrade_debug.txt"

# debug function
function Write-DebugInfo {
    param ([string]$message)
    if ($debugMode) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $debugFilePath -Value "DEBUG ${timestamp}: $message"
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

        # Speed-to-type mapping. Update as needed.
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

# collect info
Write-DebugInfo "Collecting disk information..."
$diskInfo = Get-DiskInfo

Write-DebugInfo "Collecting RAM information..."
$ramInfo, $ramSizeTotal = Get-RAMInfo

Write-DebugInfo "Collecting machine information..."
$machineInfo = Get-MachineInfo

# Check for upgrades
$upgradeNeeded = $false
$upgradeInfo = @()

# Check disk
if ($diskInfo -match $upgradeFromMediaType) {
    $upgradeNeeded = $true
    $upgradeInfo += "Disk: $diskInfo"
}

# Check RAM
if ($ramSizeTotal -lt $minRAMSizeGB) {
    $upgradeNeeded = $true
    $upgradeInfo += "RAM: $ramInfo"
}

# prepare output for the text file only if upgrade needed
if ($upgradeNeeded) {
    if (Test-Path $outputFilePath) {
        Remove-Item -Path $outputFilePath
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $upgradeStatus = 1
    $outputInfo = "$timestamp; $upgradeStatus; Machine Info: $machineInfo; " + ($upgradeInfo -join "; ")
    Set-Content -Path $outputFilePath -Value $outputInfo
} else {
    $upgradeStatus = 0
}

# output 1 or 0 for ConnectWise Automate agent
[Console]::Write($upgradeStatus)
