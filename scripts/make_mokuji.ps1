# Define the base path for the docs folder
$docsPath = "docs"
$outputFile = "docs/index.md"

# Initialize an empty array to store the TOC entries
$tocEntries = @()

# Function to recursively generate the TOC
function Generate-Toc {
    param (
        [string]$currentPath,
        [string]$relativePath = ""
    )
    
    # Get all markdown files and directories in the current path
    $items = Get-ChildItem -Path $currentPath -Force | Sort-Object { $_.PSIsContainer } -Descending

    foreach ($item in $items) {
        if ($item.PSIsContainer) {
            # If it's a directory, add the directory name to the TOC
            $dirName = $item.Name
            $tocEntries += "`n### $dirName`n"
            Generate-Toc -currentPath $item.FullName -relativePath (Join-Path $relativePath $dirName)
        } elseif ($item.Extension -eq ".md" -and $item.Name -ne "index.md") {
            # If it's a markdown file, add a link to the file in the TOC
            $fileName = $item.Name
            $fileLink = Join-Path $relativePath $fileName -Resolve
            $fileLink = $fileLink -replace '\\', '/'
            $tocEntries += "* [$fileName]($fileLink)"
        }
    }
}

# Generate the TOC starting from the docs folder
Generate-Toc -currentPath $docsPath

# Output the TOC to the index.md file
Set-Content -Path $outputFile -Value $tocEntries -Force

Write-Host "Table of contents generated and saved to $outputFile"
