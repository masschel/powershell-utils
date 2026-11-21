# Script to find all pictures in a folder and subfolders, and extract their dates

[CmdletBinding()]
param(
    [string]$FolderPath = $PSScriptRoot,
    [switch]$Recurse = $true,
    [switch]$CopyToRenamed = $false
)

# Suppress confirmation prompts and errors
$ConfirmPreference = 'None'
$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

# Load System.Drawing assembly for image processing
Add-Type -AssemblyName System.Drawing

# Define image file extensions to search for
$imageExtensions = @('*.jpg', '*.jpeg', '*.png', '*.bmp', '*.gif', '*.tiff', '*.webp')

# Function to extract date from picture metadata
function Get-PictureDate {
    [CmdletBinding()]
    param(
        [string]$FilePath
    )
    
    $file = Get-Item $FilePath -ErrorAction SilentlyContinue
     
    try {
        # Try using .NET to read EXIF data
        $image = [System.Drawing.Image]::FromFile($FilePath)
        
        # EXIF DateTaken property ID is 36867
        if ($image.PropertyIdList -contains 36867) {
            $exifData = $image.GetPropertyItem(36867)
            $dateString = [System.Text.Encoding]::ASCII.GetString($exifData.Value).Trim(@(0))
            
            # EXIF format is "yyyy:MM:dd HH:mm:ss"
            if ($dateString -match '(\d{4}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2}):(\d{2})') {
                $parsedDate = [datetime]::ParseExact($dateString, "yyyy:MM:dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
                $image.Dispose()
                return @{
                    Date = $parsedDate
                    Source = "EXIF Metadata"
                }
            }
        }
        
        $image.Dispose()
    }
    catch {
        # If .NET approach fails, continue to fallback
    }
    
    # Fallback to file modification date
    return @{
        Date = $file.LastWriteTime
        Source = "File LastWriteTime"
    }
}

# Get all picture files
Write-Host "Searching for pictures in: $FolderPath" -ForegroundColor Cyan

if ($Recurse) {
    $pictures = Get-ChildItem -Path $FolderPath -Recurse -Include $imageExtensions -ErrorAction SilentlyContinue
    $allFiles = Get-ChildItem -Path $FolderPath -Recurse -File -ErrorAction SilentlyContinue
}
else {
    $pictures = Get-ChildItem -Path $FolderPath -Include $imageExtensions -ErrorAction SilentlyContinue
    $allFiles = Get-ChildItem -Path $FolderPath -File -ErrorAction SilentlyContinue
}

Write-Host "Found $($pictures.Count) picture(s)" -ForegroundColor Green

# Find files that are NOT pictures
$notIncluded = $allFiles | Where-Object { $_.FullName -notin $pictures.FullName }

if ($notIncluded.Count -gt 0) {
    Write-Host "`nFiles NOT included ($($notIncluded.Count)):" -ForegroundColor Yellow
    $notIncluded | Select-Object -Property @{Label="File Name"; Expression={$_.Name}}, @{Label="Size (KB)"; Expression={[math]::Round($_.Length / 1KB, 2)}} | Format-Table -AutoSize
}
else {
    Write-Host "All files are recognized picture files." -ForegroundColor Green
}

# Extract date from each picture and display results
$results = @()

foreach ($picture in $pictures) {
    $dateInfo = Get-PictureDate -FilePath $picture.FullName
    $pictureDate = $dateInfo.Date
    $dateSource = $dateInfo.Source
    
    # Format the date string as IMG_yyyymmdd_HHmmss
    $formattedDateString = $pictureDate.ToString("'IMG_'yyyyMMdd'_'HHmmss")
    
    # Get file extension
    $fileExtension = $picture.Extension
    
    # Create the new filename
    $newFileName = $formattedDateString + $fileExtension
    
    $result = [PSCustomObject]@{
        FileName       = $picture.Name
        FullPath       = $picture.FullName
        FileSize       = $picture.Length
        DateExtracted  = $pictureDate
        DateModified   = $picture.LastWriteTime
        FormattedName  = $newFileName
        DateString     = $formattedDateString
        DateSource     = $dateSource
    }
    
    $results += $result
}

# Display results
if ($results.Count -gt 0) {
    $results | Format-Table -AutoSize -Property @(
        @{Label="Original Name"; Expression={$_.FileName}},
        @{Label="Formatted Name"; Expression={$_.FormattedName}},
        @{Label="Date Extracted"; Expression={$_.DateExtracted.ToString('yyyy-MM-dd HH:mm:ss')}},
        @{Label="Source"; Expression={$_.DateSource}},
        @{Label="File Size (KB)"; Expression={[math]::Round($_.FileSize / 1KB, 2)}}
    )
}
else {
    Write-Host "No pictures found." -ForegroundColor Yellow
}

# Check for duplicate new names
$duplicates = $results | Group-Object -Property FormattedName | Where-Object { $_.Count -gt 1 }

if ($duplicates.Count -gt 0) {
    Write-Host "`nDuplicate formatted names found:" -ForegroundColor Red
    foreach ($dup in $duplicates) {
        Write-Host "`n  $($dup.Name) ($($dup.Count) files)" -ForegroundColor Red
        $dup.Group | Select-Object -Property @{Label="Subfolder"; Expression={$_.FullPath.Substring($FolderPath.Length).TrimStart('\') -replace '\\[^\\]*$'}}, @{Label="Original Name"; Expression={$_.FileName}}, @{Label="Date Extracted"; Expression={$_.DateExtracted.ToString('yyyy-MM-dd HH:mm:ss')}}, @{Label="Source"; Expression={$_.DateSource}} | Format-Table -AutoSize
    }
}
else {
    Write-Host "`nNo duplicate formatted names found." -ForegroundColor Green
    
    if ($CopyToRenamed) {
        # Create the Renamed folder
        $renamedFolder = Join-Path $FolderPath "Renamed"
        if (-not (Test-Path $renamedFolder)) {
            New-Item -ItemType Directory -Path $renamedFolder -Force -Confirm:$false | Out-Null
            Write-Host "Created folder: $renamedFolder" -ForegroundColor Cyan
        }
        
        # Copy all pictures with new names
        Write-Host "`nCopying pictures with new names..." -ForegroundColor Cyan
        $copyCount = 0
        foreach ($file in $results) {
            $sourceFile = $file.FullPath
            $destinationFile = Join-Path $renamedFolder $file.FormattedName
            
            try {
                Copy-Item -Path $sourceFile -Destination $destinationFile -Force -Confirm:$false
                $copyCount++
                Write-Host "  [OK] $($file.FileName) -> $($file.FormattedName)" -ForegroundColor Green
            }
            catch {
                Write-Host "  [ERROR] Failed to copy $($file.FileName): $_" -ForegroundColor Red
            }
        }
        
        Write-Host "`nCopied $copyCount/$($results.Count) pictures successfully." -ForegroundColor Cyan
    }
    else {
        Write-Host "Use -CopyToRenamed switch to copy files to the 'Renamed' folder." -ForegroundColor Yellow
    }
}

# Export results to CSV for further processing
$csvPath = Join-Path $FolderPath "PictureMetadata.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "Metadata exported to: $csvPath" -ForegroundColor Cyan
