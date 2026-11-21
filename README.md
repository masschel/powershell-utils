# powershell-utils
Repo containing small Powershell utilities for various purposes.

## Remove-MacFiles.ps1

Removes macOS metadata files from a directory and its subdirectories:

- `.DS_Store` files.
- AppleDouble files beginning with `._`, but only when the corresponding
  path without the `._` prefix exists in the same directory. Orphaned
  AppleDouble files are left untouched.

Preview the files that would be removed:

```powershell
.\Remove-MacFiles.ps1 -Directory 'C:\path\to\directory' -WhatIf
```

Remove the files:

```powershell
.\Remove-MacFiles.ps1 -Directory 'C:\path\to\directory'
```

The script prints each path before attempting to delete it. Deletion errors
are suppressed, so a printed path does not guarantee successful removal.
Use `-Confirm` to request confirmation for each deletion. The required
`-Directory` parameter is treated as a literal path.
