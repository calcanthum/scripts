# Import the EXO V2 module
Import-Module ExchangeOnlineManagement

# Connect to Exchange Online
Connect-ExchangeOnline -ShowBanner:$false

# Get the name of the Organization
$Organization = (Get-OrganizationConfig).Name

# Define the directory to export to
$ExportDirectory = Join-Path -Path $HOME -ChildPath $Organization

# Ensure the directory exists
if (!(Test-Path -Path $ExportDirectory)) {
    New-Item -ItemType Directory -Path $ExportDirectory | Out-Null
}

# Define policies and their respective Get commands
$Policies = @{
    "AntiPhishPolicy" = "Get-AntiphishPolicy";
    "SafeLinksPolicy" = "Get-SafeLinksPolicy";
    "SafeAttachmentPolicy" = "Get-SafeAttachmentPolicy";
    "HostedContentFilterPolicy" = "Get-HostedContentFilterPolicy";
    "HostedOutboundSpamFilterPolicy" = "Get-HostedOutboundSpamFilterPolicy";
    "MalwareFilterPolicy" = "Get-MalwareFilterPolicy";
    "HostedContentFilterRule" = "Get-HostedContentFilterRule";
    "DkimSigningConfig" = "Get-DkimSigningConfig";
    "InboundConnector" = "Get-InboundConnector";
    "OutboundConnector" = "Get-OutboundConnector";
    "AcceptedDomain" = "Get-AcceptedDomain";
}

# Loop through each policy and export it
foreach ($Policy in $Policies.GetEnumerator()) {
    $Command = $Policy.Value
    $Path = Join-Path -Path $ExportDirectory -ChildPath "$($Policy.Name).xml"
    Invoke-Expression -Command "$Command | Export-Clixml -Path `"$Path`""
}

# Disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false
