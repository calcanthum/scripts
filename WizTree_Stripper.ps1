# This script is used to filter out individual files from a WizTree export
# providing a view of the folder sizes only. It works by reading a CSV file,
# filtering out rows where both 'Files' and 'Folders' columns are equal to 0,
# and writing the filtered data to a new CSV file.

# Import the CSV file
$data = Import-Csv -Path ".\wiztree.csv"

# Filter the data
$filteredData = $data | Where-Object { $_.'Files' -ne 0 -or $_.'Folders' -ne 0 }

# Export the filtered data to a new CSV file
$filteredData | Export-Csv -Path ".\wiztree_folders.csv" -NoTypeInformation
