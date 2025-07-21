# C++ Project Package Cleanup Script

This script cleans up C++ Windows App SDK projects by removing unnecessary NuGet packages and keeping only the essential ones.

## What it does

### 1. Updates `packages.config`
Removes unnecessary packages and keeps only:
- `Microsoft.WindowsAppSDK.Foundation`
- `Microsoft.Windows.SDK.BuildTools`
- `Microsoft.Windows.SDK.BuildTools.MSIX`
- `Microsoft.WindowsAppSDK.Base`
- `Microsoft.WindowsAppSDK.InteractiveExperiences`

### 2. Removes packages folder
Deletes the local `packages` folder to force a clean restore.

### 3. Cleans up `.vcxproj` files
Removes `<Error>` conditions and `<Import>` statements related to removed packages.

## Usage

```powershell
# Preview changes (What-If mode)
.\Cleanup-CppProject.ps1 -WhatIf

# Apply changes to default project
.\Cleanup-CppProject.ps1

# Apply changes to specific project
.\Cleanup-CppProject.ps1 -ProjectPath "..\..\Samples\AppLifecycle\Activation\cpp\cpp-console-unpackaged"

# Example: Clean up a different project
.\Cleanup-CppProject.ps1 -ProjectPath "..\..\Samples\PhotoEditor\cpp-winui" -WhatIf
```

## Safety Features

- **Backup files**: Creates `.backup` files for all modified files
- **What-If mode**: Preview changes before applying them
- **Error handling**: Comprehensive error checking and reporting

## Packages Removed

The script removes these packages if found:
- Microsoft.WindowsAppSDK (main package)
- Microsoft.Web.WebView2
- Microsoft.WindowsAppSDK.AI
- Microsoft.WindowsAppSDK.DWrite
- Microsoft.WindowsAppSDK.Packages
- Microsoft.WindowsAppSDK.ML
- Microsoft.WindowsAppSDK.Runtime
- Microsoft.WindowsAppSDK.Widgets
- Microsoft.WindowsAppSDK.WinUI

## Packages Kept

These essential packages are preserved:
- Microsoft.WindowsAppSDK.Foundation
- Microsoft.Windows.SDK.BuildTools
- Microsoft.Windows.SDK.BuildTools.MSIX
- Microsoft.WindowsAppSDK.Base
- Microsoft.WindowsAppSDK.InteractiveExperiences

Any other packages (like Microsoft.Windows.CppWinRT) are also preserved.

## After running the script

1. Run `nuget restore` to download only the essential packages
2. Build the project to verify everything works
3. If issues occur, restore from `.backup` files

## Example Output

```
=== C++ Project Package Cleanup Script ===
Project Path: ..\..\Samples\AppLifecycle\Activation\cpp\cpp-console-unpackaged

Processing packages.config:
  - Will remove: Microsoft.WindowsAppSDK
  - Will remove: Microsoft.Web.WebView2
  + Will keep: Microsoft.WindowsAppSDK.Foundation
  + Will keep: Microsoft.Windows.SDK.BuildTools

Processing vcxproj:
  - Will remove 14 error condition(s) for removed packages
  - Will remove 7 import statement(s) for removed packages

✅ Project cleanup completed successfully!
```

## Troubleshooting

### If the script fails:
1. Check if the project path exists
2. Ensure you have write permissions
3. Close Visual Studio before running the script

### If build fails after cleanup:
1. Run `nuget restore` in the project directory
2. Check if any required packages were accidentally removed
3. Restore from `.backup` files if needed

### To restore backup files:
```powershell
# Restore packages.config
Copy-Item "packages.config.backup" "packages.config" -Force

# Restore vcxproj file
Copy-Item "ProjectName.vcxproj.backup" "ProjectName.vcxproj" -Force
```
