<#
.SYNOPSIS
This script connects to Exchange Online, gets the configuration of various policies, and exports the configurations to XML files.

.DESCRIPTION
The script imports the Exchange Online Management module and connects to Exchange Online without showing the banner. 
It retrieves the name of the organization and defines a directory in the user's home folder where the policy configurations 
will be exported to. If this directory doesn't exist, the script creates it.

The script defines a hash table of policies and their corresponding "Get" commands. It then loops through each policy, retrieves 
the policy using the respective command, and exports it to an XML file in the previously defined directory. 

The file name is the name of the policy. After all the policy configurations have been exported, the script disconnects 
from Exchange Online.

.INPUTS
No inputs. The script retrieves the necessary information internally.

.OUTPUTS
XML files representing the configuration of various policies. The files are saved in a directory under the user's home folder.

.EXAMPLE
PS C:\> .\ExportPolicyConfigs.ps1

.NOTES
The script requires that the Exchange Online Management module is installed and that the user has the necessary permissions 
to retrieve the policy configurations.
#>

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
