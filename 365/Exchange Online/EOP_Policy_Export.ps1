<#
.SYNOPSIS
A script to export a collection of policy configurations from Exchange Online to local XML files.

.DESCRIPTION
This script connects to an Exchange Online instance without showing the default connection banner.
It then retrieves the name of the current organization and uses this name to create an export
directory in the user's home directory. If the directory does not exist, it is created.
It then executes a list of Get-* commands associated with various policy types (anti-phishing, safe links, etc.),
exporting each policy's configuration to an XML file in the export directory.
Finally, it disconnects from the Exchange Online session without user confirmation.

.INPUTS
None. The script is self-contained and does not accept any inputs.

.OUTPUTS
XML files. For each policy type, an XML file is created in the user's home directory
under a subdirectory named after the current organization.

.EXAMPLE
PS C:\> .\ExportPolicies.ps1

This command runs the script and exports policy configurations to the user's home directory.

.NOTES
The script requires the ExchangeOnlineManagement module to be installed.
The script creates one XML file for each policy type in the predefined list.
The XML file includes the full configuration for that policy type.
#>

# Importing the Exchange Online Management module
Import-Module ExchangeOnlineManagement

# Establishing a connection to Exchange Online without showing the default connection banner
Connect-ExchangeOnline -ShowBanner:$false

# Retrieving the name of the current organization
$Organization = (Get-OrganizationConfig).Name

# Creating a directory path by joining the user's home directory and the name of the organization
$ExportDirectory = Join-Path -Path $HOME -ChildPath $Organization

# Checking if the export directory exists, if not, create it
if (!(Test-Path -Path $ExportDirectory)) {
    New-Item -ItemType Directory -Path $ExportDirectory | Out-Null
}

# Defining a hash table of policy types and their corresponding Get-* commands
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

# Iterating through each policy in the Policies hash table
foreach ($Policy in $Policies.GetEnumerator()) {
    # Store the command string associated with the current policy
    $Command = $Policy.Value
    # Create a file path for the export file by joining the export directory and the current policy name
    $Path = Join-Path -Path $ExportDirectory -ChildPath "$($Policy.Name).xml"
    # Execute the command, piping its output to an XML file
    Invoke-Expression -Command "$Command | Export-Clixml -Path `"$Path`""
}

# Disconnecting the Exchange Online session without asking for user confirmation
Disconnect-ExchangeOnline -Confirm:$false
