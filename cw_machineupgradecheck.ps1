# User-configurable settings
$minRAMSizeGB = 8
$targetMediaType = "HDD"
$outputFilePath = "C:\Windows\Temp\cw_machine_upgrade_info.txt"
$debugMode = $false
$debugFilePath = "C:\Windows\Temp\cw_machine_upgrade_debug.txt"

function Write-DebugInfo {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($debugMode) {
        Add-Content -Path $debugFilePath -Value "$timestamp - $message"
    }
}

# Function to determine disk type and size of system disk (C:)
function Get-DiskInfo {
    $systemDiskPartition = Get-Partition | Where-Object { $_.DriveLetter -eq 'C' }
    $systemDisk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq $systemDiskPartition.DiskNumber }
    $sizeGB = [math]::Round($systemDisk.Size / 1GB)
    return "$($systemDisk.MediaType), ${sizeGB}GB"
}

# Function to check RAM size, form factor, and speed
function Get-RAMInfo {
    $memory = Get-WmiObject -Class Win32_PhysicalMemory
    $ramInfo = @()
    $moduleIndex = 1
    foreach ($m in $memory) {
        $speed = $m.Speed
        $ddrType = ""
        if ($speed -ge 400 -and $speed -le 1066) { $ddrType = "DDR2 (Guess)" }
        elseif ($speed -ge 800 -and $speed -le 2133) { $ddrType = "DDR3 (Guess)" }
        elseif ($speed -ge 2133 -and $speed -le 4266) { $ddrType = "DDR4 (Guess)" }
        elseif ($speed -ge 4800) { $ddrType = "DDR5 (Guess)" }
        else { $ddrType = "Unknown" }
        
        $formFactor = if ($m.FormFactor -eq 8) {"DIMM"} else {"SODIMM"}
        $ramSizeGB = [math]::Round($m.Capacity / 1GB)
        
        $ramInfo += "Module ${moduleIndex}: $formFactor, $ddrType, ${ramSizeGB}GB, ${speed}MHz"
        $moduleIndex++
    }
    return $ramInfo -join '; '
}

# Function to get machine manufacturer and serial number
function Get-MachineInfo {
    $bios = Get-WmiObject -Class Win32_BIOS
    return "Manufacturer: $($bios.Manufacturer); SerialNumber: $($bios.SerialNumber)"
}

# Initialize debug file if debugMode is true
if ($debugMode) {
    if (Test-Path $debugFilePath) {
        Remove-Item -Path $debugFilePath
    }
    New-Item -Path $debugFilePath -ItemType File
}


# Collect info
Write-DebugInfo "DEBUG: Collecting disk information..."
$diskInfo = Get-DiskInfo
Write-DebugInfo "DEBUG: Disk Info: $diskInfo"

Write-DebugInfo "DEBUG: Collecting RAM information..."
$ramInfo = Get-RAMInfo
Write-DebugInfo "DEBUG: RAM Info: $ramInfo"

Write-DebugInfo "DEBUG: Collecting machine information..."
$machineInfo = Get-MachineInfo
Write-DebugInfo "DEBUG: Machine Info: $machineInfo"

# Check if upgrades are needed
$upgradeNeeded = $false
$upgradeInfo = @()

# Check Disk
if ($diskInfo -match $targetMediaType) {
    $upgradeNeeded = $true
    $upgradeInfo += "Disk: $diskInfo"
}

# Check RAM
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

# Prepare output with timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if ($upgradeNeeded) {
    $outputInfo = "$timestamp; 1; Machine Info: $machineInfo; " + ($upgradeInfo -join "; ")
    Set-Content -Path $outputFilePath -Value $outputInfo
} else {
    if (Test-Path $outputFilePath) {
        Remove-Item -Path $outputFilePath
    }
}
