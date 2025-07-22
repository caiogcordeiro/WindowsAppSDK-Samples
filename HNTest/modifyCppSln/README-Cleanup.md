# C++ Project Cleanup Script

This PowerShell script automates the cleanup of C++ projects in the Windows App SDK samples, removing unnecessary NuGet packages and updating project files for self-contained deployment.

## Features

- **Batch Processing**: Process all 37 C++ solutions automatically
- **Single Project Mode**: Process individual projects
- **Safe Operation**: Creates backup files before making changes
- **What-If Mode**: Preview changes without applying them
- **Comprehensive Cleanup**: Updates packages.config, deletes packages folders, and cleans .vcxproj files

## Usage

### Batch Mode - Process All C++ Solutions
```powershell
# Preview changes for all 10 C++ solutions (What-If mode)
.\Cleanup-CppProject.ps1 -ProcessAllCppSolutions -WhatIf

# Apply changes to all 10 C++ solutions
.\Cleanup-CppProject.ps1 -ProcessAllCppSolutions

# Specify custom feature area solutions file
.\Cleanup-CppProject.ps1 -ProcessAllCppSolutions -FeatureAreaSolutionsFile "C:\path\to\featureAreaSolutions.json"
```

### Single Project Mode
```powershell
# Preview changes for a single project (What-If mode)
.\Cleanup-CppProject.ps1 -ProjectPath "Q:\code_WASDK\WindowsAppSDK-Samples\Samples\AppLifecycle\Instancing\cpp-console-unpackaged\CppWinRtConsoleActivation" -WhatIf

# Apply changes to a single project  
.\Cleanup-CppProject.ps1 -ProjectPath "Q:\code_WASDK\WindowsAppSDK-Samples\Samples\AppLifecycle\Instancing\cpp-console-unpackaged\CppWinRtConsoleActivation"
```

## Parameters

- **`-ProcessAllCppSolutions`**: Switch to enable batch processing of all C++ solutions
- **`-ProjectPath`**: Path to a specific project directory (required for single project mode)
- **`-FeatureAreaSolutionsFile`**: Path to the JSON file containing solution mappings (default: "../featureAreaSolutions.json")
- **`-WhatIf`**: Preview changes without applying them

## What the Script Does

### 1. Updates packages.config
- **Removes** unnecessary WindowsAppSDK packages:
  - Microsoft.WindowsAppSDK
  - Microsoft.Web.WebView2  
  - Microsoft.WindowsAppSDK.AI
  - Microsoft.WindowsAppSDK.DWrite
  - Microsoft.WindowsAppSDK.Packages
  - Microsoft.WindowsAppSDK.ML
  - Microsoft.WindowsAppSDK.Runtime
  - Microsoft.WindowsAppSDK.Widgets
  - Microsoft.WindowsAppSDK.WinUI

- **Keeps** essential packages:
  - Microsoft.Windows.CppWinRT
  - Microsoft.Windows.ImplementationLibrary
  - Microsoft.WindowsAppSDK.ProjectReunion
  - Win32Metadata
  - Microsoft.Windows.SDK.BuildTools
  - Microsoft.VCRTForwarders.140

### 2. Deletes packages folder
- Searches for packages folders in:
  - Project directory
  - Parent directory (solution level)
  - Grandparent directory (feature area level)
- Reports folder size before deletion
- Safely removes all found packages folders

### 3. Cleans .vcxproj files
- Removes `<Error>` conditions related to removed packages
- Removes `<Import>` statements for removed packages
- Uses precise regex patterns to avoid removing needed references
- Preserves essential MSBuild imports and conditions

## Batch Processing Details

When using `-ProcessAllCppSolutions`, the script:

1. **Loads C++ Solutions**: Parses the `featureAreaSolutions.json` file to identify C++ solutions
2. **Filters Solutions**: Identifies C++ solutions by path patterns (`cpp-`, `\cpp\`, `\native\`, `-cpp\`)
3. **Discovers Projects**: Finds project directories within each solution that contain packages.config or .vcxproj files
4. **Processes Projects**: Applies the cleanup process to each discovered project
5. **Reports Progress**: Provides detailed progress information and final summary

### Expected Results
- **37 C++ Solutions**: Identified from the total 82 solutions
- **Multiple Projects**: Each solution may contain multiple project directories
- **Comprehensive Cleanup**: All C++ projects will have packages cleaned up automatically

## Safety Features

- **Backup Files**: Creates `.backup` files before modifying any original files
- **What-If Mode**: Use `-WhatIf` to preview all changes before applying them
- **Error Handling**: Continues processing other projects if one fails
- **Detailed Logging**: Shows exactly what changes are being made
- **Progress Tracking**: Reports success/failure counts for batch operations

## Example Output

### Batch Processing Summary
```
================================================================================
BATCH PROCESSING SUMMARY
================================================================================
Total C++ Solutions Found: 37
Total Projects Processed: 89
Total Projects Skipped: 3
Total Errors: 0
Packages to keep: Microsoft.Windows.CppWinRT, Microsoft.Windows.ImplementationLibrary, ...
Packages to remove: Microsoft.WindowsAppSDK, Microsoft.Web.WebView2, ...
================================================================================
```

### Single Project Output
```
Processing C++ project: Q:\...\CppWinRtConsoleActivation

Processing packages.config: Q:\...\packages.config
  - Will remove: Microsoft.WindowsAppSDK
  - Will remove: Microsoft.Web.WebView2
  + Will keep: Microsoft.Windows.CppWinRT
  Created backup: Q:\...\packages.config.backup
  Updated packages.config (removed 7 packages)

Found packages folder: Q:\...\packages (Size: 203.3 MB)
  ✅ Deleted packages folder: Q:\...\packages

Processing vcxproj: Q:\...\CppWinRtConsoleActivation.vcxproj
  Created backup: Q:\...\CppWinRtConsoleActivation.vcxproj.backup
  Updated vcxproj (removed 3 errors, 2 imports)

✓ Project processing completed successfully!
```

## Notes

- Run the script from the `modifyCppSln` directory
- Backup files are created with `.backup` extension
- The script handles various project structures and solution layouts
- Use What-If mode first to verify the intended changes
- The featureAreaSolutions.json file should be in the parent directory by default
