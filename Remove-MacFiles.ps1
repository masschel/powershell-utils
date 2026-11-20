# This script removes Mac-specific files from the user-provided directory
# and its subdirectories. Use -WhatIf to list files without deleting them.

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory=$true)]
    [string]$Directory
)

# Remove .DS_Store files
Get-ChildItem -LiteralPath $Directory -Recurse -Force -File -Filter ".DS_Store" | ForEach-Object {
    if ($PSCmdlet.ShouldProcess($_.FullName, "Remove .DS_Store file")) {
        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
    }
}

# Remove files starting with ._ when their corresponding normal file exists
Get-ChildItem -LiteralPath $Directory -Recurse -Force -File -Filter "._*" | ForEach-Object {
    $normalName = $_.Name.Substring(2)
    $normalFile = Join-Path $_.DirectoryName $normalName
    if ((Test-Path -LiteralPath $normalFile) -and
        $PSCmdlet.ShouldProcess($_.FullName, "Remove AppleDouble metadata file")) {
        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
    }
}