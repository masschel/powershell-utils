<#
.SYNOPSIS
Removes macOS metadata files from a directory and its subdirectories.

.DESCRIPTION
Removes .DS_Store files and AppleDouble files beginning with ._ when the
corresponding path without the ._ prefix exists in the same directory.
Orphaned AppleDouble files are left untouched.

Each path is printed before deletion is attempted. Deletion errors are
suppressed, so a printed path does not guarantee successful removal.
Use -WhatIf to preview removals or -Confirm to confirm each deletion.

.PARAMETER Directory
The directory to search recursively. This is treated as a literal path.

.EXAMPLE
.\Remove-MacFiles.ps1 -Directory 'C:\path\to\directory' -WhatIf

Lists files that would be removed without deleting them.

.EXAMPLE
.\Remove-MacFiles.ps1 -Directory 'C:\path\to\directory'

Removes matching metadata files.

.EXAMPLE
.\Remove-MacFiles.ps1 -Directory 'C:\path\to\directory' -Confirm

Requests confirmation before each deletion.
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory=$true)]
    [string]$Directory
)

# Remove .DS_Store files
Get-ChildItem -LiteralPath $Directory -Recurse -Force -File -Filter ".DS_Store" | ForEach-Object {
    if ($PSCmdlet.ShouldProcess($_.FullName, "Remove .DS_Store file")) {
        Write-Host "Deleting: $($_.FullName)"
        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
    }
}

# Remove files starting with ._ when their corresponding normal file exists
Get-ChildItem -LiteralPath $Directory -Recurse -Force -File -Filter "._*" | ForEach-Object {
    $normalName = $_.Name.Substring(2)
    $normalFile = Join-Path $_.DirectoryName $normalName
    if ((Test-Path -LiteralPath $normalFile) -and
        $PSCmdlet.ShouldProcess($_.FullName, "Remove AppleDouble metadata file")) {
        Write-Host "Deleting: $($_.FullName)"
        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
    }
}