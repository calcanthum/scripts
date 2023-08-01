<#
.SYNOPSIS
This script authenticates to a Microsoft 365 tenant, retrieves a list of all site collections and drives, 
and searches for a specific folder in each site's default document library and each drive.

.DESCRIPTION
The script uses the OAuth 2.0 Client Credentials Grant flow to authenticate to the tenant, using the client ID, 
tenant ID, and client secret specified at the start of the script. The user is prompted to enter the name of 
the folder to search for.

The script retrieves a list of all site collections in the tenant and then, for each site, sends a GET request 
to the Microsoft Graph API to search the site's default document library for the folder. If the folder is found, 
its name, path, and web URL are printed to the console.

The script also retrieves a list of all drives in the tenant (which essentially means all OneDrive for Business 
sites) and, for each drive, sends a GET request to the Microsoft Graph API to search the drive for the folder. 
If the folder is found, its name, path, and web URL are printed to the console.

.INPUTS
Client ID, Tenant ID, Client Secret, and the name of the folder to search for.

.OUTPUTS
Name, Path, and URL of the found folders.

.EXAMPLE
PS C:\> .\TenantFolderSearch.ps1

.NOTES
The script requires that the tenant's Azure AD application (represented by the client ID) has 
been granted the appropriate permissions on the Microsoft Graph API.
#>

# Application (client) ID, tenant ID, and client secret
$clientId = "client-id-here"
$tenantId = "tenant-id-here"
$clientSecret = "client-secret-here"

# Construct URI for token
$tokenUri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

# Construct the body for the Active Directory Authentication request
$body = @{
    client_id     = $clientId
    scope         = "https://graph.microsoft.com/.default"
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}

# Request the token
$response = Invoke-RestMethod -Method Post -Uri $tokenUri -ContentType "application/x-www-form-urlencoded" -Body $body

# If the request was successful, response should have an access_token property
if ($response.access_token) {
    $accessToken = $response.access_token
} else {
    throw "Authentication failed."
}

# END AUTHENTICATION LOGIC

# Set common headers
$headers = @{
    Authorization = "Bearer $accessToken"
    Accept        = "application/json"
}

# Prompt the user for the folder name
$folderName = Read-Host -Prompt 'Enter the name of the folder you want to search for'

# Get all sites in your organization
$apiUriSites = "https://graph.microsoft.com/v1.0/sites"
$responseSites = Invoke-RestMethod -Method Get -Uri $apiUriSites -Headers $headers

# Iterate through each site and perform a search in the default document library
foreach ($site in $responseSites.value) {
    $siteId = $site.id
    $apiUriSharePoint = "https://graph.microsoft.com/v1.0/sites/$siteId/drive/root/search(q='$folderName')"

    # Send the GET request for each site
    $responseSharePoint = Invoke-RestMethod -Method Get -Uri $apiUriSharePoint -Headers $headers

    # Output results
    foreach ($item in $responseSharePoint.value) {
        if ($item.folder -and $item.name -eq $folderName) {
            $path = $item.parentReference.path -replace "/drive/root:", ""
            Write-Output ("Name: " + $item.name)
            Write-Output ("Path: " + $path)
            Write-Output ("URL: " + $item.webUrl)
            Write-Output ("-----")
        }
    }
}

# Get all drives in your organization
$apiUriDrives = "https://graph.microsoft.com/v1.0/drives"
$responseDrives = Invoke-RestMethod -Method Get -Uri $apiUriDrives -Headers $headers

# Iterate through each drive and perform a search
foreach ($drive in $responseDrives.value) {
    $driveId = $drive.id
    $apiUriOneDrive = "https://graph.microsoft.com/v1.0/drives/$driveId/root/search(q='$folderName')"

    # Send the GET request for each drive in OneDrive
    $responseOneDrive = Invoke-RestMethod -Method Get -Uri $apiUriOneDrive -Headers $headers

    # Output results
    foreach ($item in $responseOneDrive.value) {
        if ($item.folder -and $item.name -eq $folderName) {
            $path = $item.parentReference.path -replace "/drive/root:", ""
            Write-Output ("Name: " + $item.name)
            Write-Output ("Path: " + $path)
            Write-Output ("URL: " + $item.webUrl)
            Write-Output ("-----")
        }
    }
}
