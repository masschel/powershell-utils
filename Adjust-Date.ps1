# Script to sort pictures by file name and extract their date from EXIF metadata

#-TargetDate "2002-01-01 00:00:00"

[CmdletBinding()]
param(
    [string]$FolderPath = $PSScriptRoot,
    [switch]$Recurse = $true,
    [datetime]$TargetDate = [datetime]::MinValue,
    [switch]$Apply = $false
)

# Suppress confirmation prompts and errors
$ConfirmPreference = 'None'
$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

# Load System.Drawing assembly for image processing
Add-Type -AssemblyName System.Drawing

# Define image file extensions to search for
$imageExtensions = @('*.jpg', '*.jpeg', '*.png', '*.bmp', '*.gif', '*.tiff', '*.webp')

# Function to extract date from picture EXIF metadata
function Get-ExifDate {
    [CmdletBinding()]
    param(
        [string]$FilePath
    )

    try {
        $image = [System.Drawing.Image]::FromFile($FilePath)

        # EXIF DateTaken property ID is 36867
        if ($image.PropertyIdList -contains 36867) {
            $exifData = $image.GetPropertyItem(36867)
            $dateString = [System.Text.Encoding]::ASCII.GetString($exifData.Value).Trim(@(0))

            # EXIF format is "yyyy:MM:dd HH:mm:ss"
            if ($dateString -match '(\d{4}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2}):(\d{2})') {
                $parsedDate = [datetime]::ParseExact($dateString, "yyyy:MM:dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
                $image.Dispose()
                return $parsedDate
            }
        }

        $image.Dispose()
    }
    catch {
        # No EXIF date available
    }

    return $null
}

# Function to write a date/time into a picture's EXIF metadata
function Set-ExifDate {
    [CmdletBinding()]
    param(
        [string]$FilePath,
        [datetime]$NewDate
    )

    try {
        $image = [System.Drawing.Image]::FromFile($FilePath)
        $dateBytes = [System.Text.Encoding]::ASCII.GetBytes($NewDate.ToString("yyyy:MM:dd HH:mm:ss") + "`0")

        # Update DateTaken (36867), DateDigitized (36868) and DateTime (306) when present
        foreach ($propId in @(36867, 36868, 306)) {
            if ($image.PropertyIdList -contains $propId) {
                $propItem = $image.GetPropertyItem($propId)
                $propItem.Value = $dateBytes
                $image.SetPropertyItem($propItem)
            }
        }

        # Save to a memory stream first since the file is locked while $image is open
        $memoryStream = New-Object System.IO.MemoryStream
        $image.Save($memoryStream, $image.RawFormat)
        $image.Dispose()

        [System.IO.File]::WriteAllBytes($FilePath, $memoryStream.ToArray())
        $memoryStream.Dispose()
        return $true
    }
    catch {
        if ($image) { $image.Dispose() }
        return $false
    }
}

# Get all picture files, sorted by name
Write-Host "Searching for pictures in: $FolderPath" -ForegroundColor Cyan

if ($Recurse) {
    $pictures = Get-ChildItem -Path $FolderPath -Recurse -Include $imageExtensions -ErrorAction SilentlyContinue
}
else {
    $pictures = Get-ChildItem -Path $FolderPath -Include $imageExtensions -ErrorAction SilentlyContinue
}

# Sort by name within each folder, rather than across all folders
$pictures = $pictures | Group-Object -Property DirectoryName | Sort-Object -Property Name | ForEach-Object { $_.Group | Sort-Object -Property Name }

Write-Host "Found $($pictures.Count) picture(s)" -ForegroundColor Green

# Extract EXIF date for each picture, in name order, proposing an adjusted date for files matching TargetDate
$results = @()
$previousDate = $null
$previousDirectory = $null

foreach ($picture in $pictures) {
    if ($picture.DirectoryName -ne $previousDirectory) {
        $previousDate = $null
        $previousDirectory = $picture.DirectoryName
    }

    $exifDate = Get-ExifDate -FilePath $picture.FullName
    $proposedDate = $exifDate

    # Files matching TargetDate get bumped one second past the previous alphabetical image
    if ($TargetDate -ne [datetime]::MinValue -and $exifDate -and $exifDate -eq $TargetDate -and $previousDate) {
        $proposedDate = $previousDate.AddSeconds(1)
    }

    $results += [PSCustomObject]@{
        FileName     = $picture.Name
        FullPath     = $picture.FullName
        ExifDate     = $exifDate
        ProposedDate = $proposedDate
    }

    if ($proposedDate) {
        $previousDate = $proposedDate
    }
}

# Display results
if ($results.Count -gt 0) {
    $results | Format-Table -AutoSize -Property @(
        @{Label="File Name"; Expression={$_.FileName}},
        @{Label="EXIF Date"; Expression={ if ($_.ExifDate) { $_.ExifDate.ToString('yyyy-MM-dd HH:mm:ss') } else { "N/A" } }},
        @{Label="Proposed Date"; Expression={ if ($_.ProposedDate) { $_.ProposedDate.ToString('yyyy-MM-dd HH:mm:ss') } else { "N/A" } }}
    )
}
else {
    Write-Host "No pictures found." -ForegroundColor Yellow
}

# Count files whose proposed date differs from their current EXIF date
$filesToUpdate = $results | Where-Object { $_.ProposedDate -ne $_.ExifDate }
Write-Host "`n$($filesToUpdate.Count) file(s) need updating." -ForegroundColor Cyan

if ($Apply) {
    $updatedCount = 0
    foreach ($file in $filesToUpdate) {
        if (Set-ExifDate -FilePath $file.FullPath -NewDate $file.ProposedDate) {
            $updatedCount++
            Write-Host "  [OK] $($file.FileName) -> $($file.ProposedDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
        }
        else {
            Write-Host "  [ERROR] Failed to update $($file.FileName)" -ForegroundColor Red
        }
    }
    Write-Host "`nUpdated $updatedCount/$($filesToUpdate.Count) file(s)." -ForegroundColor Cyan
}
elseif ($filesToUpdate.Count -gt 0) {
    Write-Host "Use -Apply switch to write the proposed dates into the files' EXIF metadata." -ForegroundColor Yellow
}

return $results
