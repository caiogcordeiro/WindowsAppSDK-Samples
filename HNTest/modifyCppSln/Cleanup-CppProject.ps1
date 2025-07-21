# C++ Project Package Cleanup Script
param(
    [string]$ProjectPath = "..\..\Samples\AppLifecycle\Activation\cpp\cpp-console-unpackaged",
    [switch]$WhatIf = $false
)

Write-Host "=== C++ Project Package Cleanup Script ===" -ForegroundColor Green
Write-Host "Project Path: $ProjectPath"
Write-Host "What-If Mode: $WhatIf"
Write-Host ""

# Define packages to keep
$PackagesToKeep = @(
    "Microsoft.WindowsAppSDK.Foundation",
    "Microsoft.Windows.SDK.BuildTools", 
    "Microsoft.Windows.SDK.BuildTools.MSIX",
    "Microsoft.WindowsAppSDK.Base",
    "Microsoft.WindowsAppSDK.InteractiveExperiences"
)

# Define packages to remove (all WindowsAppSDK related packages)
$PackagesToRemove = @(
    "Microsoft.WindowsAppSDK",
    "Microsoft.Web.WebView2",
    "Microsoft.WindowsAppSDK.AI",
    "Microsoft.WindowsAppSDK.DWrite", 
    "Microsoft.WindowsAppSDK.Packages",
    "Microsoft.WindowsAppSDK.ML",
    "Microsoft.WindowsAppSDK.Runtime",
    "Microsoft.WindowsAppSDK.Widgets",
    "Microsoft.WindowsAppSDK.WinUI"
)

function Update-PackagesConfig {
    param([string]$PackagesConfigPath)
    
    if (!(Test-Path $PackagesConfigPath)) {
        Write-Warning "packages.config not found at: $PackagesConfigPath"
        return $false
    }
    
    Write-Host "Processing packages.config: $PackagesConfigPath" -ForegroundColor Yellow
    
    # Load XML
    [xml]$packagesXml = Get-Content $PackagesConfigPath
    $originalCount = $packagesXml.packages.package.Count
    
    # Find packages to remove
    $packagesToRemoveFromXml = @()
    foreach ($package in $packagesXml.packages.package) {
        $packageId = $package.id
        
        # If package is in the remove list and NOT in the keep list
        if ($PackagesToRemove -contains $packageId -and $PackagesToKeep -notcontains $packageId) {
            $packagesToRemoveFromXml += $package
            Write-Host "  - Will remove: $packageId" -ForegroundColor Red
        } elseif ($PackagesToKeep -contains $packageId) {
            Write-Host "  + Will keep: $packageId" -ForegroundColor Green
        } else {
            Write-Host "  = Will keep (other): $packageId" -ForegroundColor Gray
        }
    }
    
    if ($packagesToRemoveFromXml.Count -eq 0) {
        Write-Host "  No packages to remove." -ForegroundColor Gray
        return $true
    }
    
    if (!$WhatIf) {
        # Create backup
        $backupPath = "$PackagesConfigPath.backup"
        Copy-Item $PackagesConfigPath $backupPath -Force
        Write-Host "  Created backup: $backupPath" -ForegroundColor Blue
        
        # Remove packages
        foreach ($package in $packagesToRemoveFromXml) {
            $packagesXml.packages.RemoveChild($package) | Out-Null
        }
        
        # Save modified XML (resolve to absolute path)
        $absolutePath = Resolve-Path $PackagesConfigPath
        $packagesXml.Save($absolutePath.Path)
        Write-Host "  Updated packages.config (removed $($packagesToRemoveFromXml.Count) packages)" -ForegroundColor Green
    } else {
        Write-Host "  [WHAT-IF] Would remove $($packagesToRemoveFromXml.Count) packages" -ForegroundColor Cyan
    }
    
    return $true
}

function Remove-PackagesFolder {
    param([string]$ProjectPath)
    
    # For projects like CppWinRtConsoleActivation, the packages folder is in the grandparent directory
    # Project structure: .../cpp-console-unpackaged/CppWinRtConsoleActivation/  
    # Packages folder: .../cpp-console-unpackaged/packages/
    
    $packagesFolders = @()
    
    # Check project directory
    $projectPackages = Join-Path $ProjectPath "packages"
    if (Test-Path $projectPackages) {
        $packagesFolders += $projectPackages
    }
    
    # Check parent directory (more common for C++ projects)
    $parentDir = Split-Path $ProjectPath -Parent
    $parentPackages = Join-Path $parentDir "packages"
    if (Test-Path $parentPackages) {
        $packagesFolders += $parentPackages
    }
    
    # Check grandparent directory (solution level)
    $grandParentDir = Split-Path $parentDir -Parent
    $grandParentPackages = Join-Path $grandParentDir "packages"
    if (Test-Path $grandParentPackages) {
        $packagesFolders += $grandParentPackages
    }
    
    if ($packagesFolders.Count -eq 0) {
        Write-Host "No packages folder found in project, parent, or grandparent directories" -ForegroundColor Gray
        return
    }
    
    foreach ($packagesFolder in $packagesFolders) {
        Write-Host "Found packages folder: $packagesFolder" -ForegroundColor Yellow
        
        if (!$WhatIf) {
            try {
                Remove-Item $packagesFolder -Recurse -Force -ErrorAction Stop
                Write-Host "  ✅ Deleted packages folder: $packagesFolder" -ForegroundColor Green
            } catch {
                Write-Host "  ❌ Failed to delete packages folder: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  [WHAT-IF] Would delete packages folder: $packagesFolder" -ForegroundColor Cyan
        }
    }
}

function Update-VcxprojFile {
    param([string]$VcxprojPath)
    
    if (!(Test-Path $VcxprojPath)) {
        Write-Warning "vcxproj file not found at: $VcxprojPath"
        return $false
    }
    
    Write-Host "Processing vcxproj: $VcxprojPath" -ForegroundColor Yellow
    
    # Read file content
    $content = Get-Content $VcxprojPath -Raw
    $originalContent = $content
    
    # Count and remove error conditions for packages we're removing
    $removedErrorCount = 0
    
    foreach ($packageToRemove in $PackagesToRemove) {
        # Find error conditions related to this package (exact match to avoid removing needed packages)
        $escapedPackage = [regex]::Escape($packageToRemove)
        # Use word boundary and version pattern to ensure exact package match
        $errorPattern = "<Error[^>]*Condition[^>]*\b$escapedPackage\.[0-9][^>]*>"
        $matches = [regex]::Matches($content, $errorPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        if ($matches.Count -gt 0) {
            Write-Host "  - Will remove $($matches.Count) error condition(s) for: $packageToRemove" -ForegroundColor Red
            $removedErrorCount += $matches.Count
            
            if (!$WhatIf) {
                # Remove the error conditions
                $content = [regex]::Replace($content, $errorPattern, "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            }
        }
    }
    
    # Also remove Import statements for removed packages
    $removedImportCount = 0
    foreach ($packageToRemove in $PackagesToRemove) {
        # Pattern to match Import statements (exact match to avoid removing needed packages)
        $escapedPackage = [regex]::Escape($packageToRemove)
        # Use word boundary and version pattern to ensure exact package match
        $importPattern = "<Import[^>]*\b$escapedPackage\.[0-9][^/>]*/?>"
        $matches = [regex]::Matches($content, $importPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        if ($matches.Count -gt 0) {
            Write-Host "  - Will remove $($matches.Count) import statement(s) for: $packageToRemove" -ForegroundColor Red
            $removedImportCount += $matches.Count
            
            if (!$WhatIf) {
                $content = [regex]::Replace($content, $importPattern, "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            }
        }
    }
    
    if ($removedErrorCount -eq 0 -and $removedImportCount -eq 0) {
        Write-Host "  No error conditions or imports to remove." -ForegroundColor Gray
        return $true
    }
    
    if (!$WhatIf) {
        # Create backup
        $backupPath = "$VcxprojPath.backup"
        Copy-Item $VcxprojPath $backupPath -Force
        Write-Host "  Created backup: $backupPath" -ForegroundColor Blue
        
        # Clean up extra empty lines
        $content = $content -replace "`r`n`r`n`r`n", "`r`n`r`n"
        
        # Save modified content
        Set-Content $VcxprojPath $content -NoNewline
        Write-Host "  Updated vcxproj (removed $removedErrorCount errors, $removedImportCount imports)" -ForegroundColor Green
    } else {
        Write-Host "  [WHAT-IF] Would remove $removedErrorCount error conditions and $removedImportCount import statements" -ForegroundColor Cyan
    }
    
    return $true
}

function Process-CppProject {
    param([string]$ProjectPath)
    
    if (!(Test-Path $ProjectPath)) {
        Write-Error "Project path not found: $ProjectPath"
        return $false
    }
    
    Write-Host "Processing C++ project: $ProjectPath" -ForegroundColor Magenta
    Write-Host ""
    
    # Step 1: Update packages.config
    $packagesConfigPath = Join-Path $ProjectPath "packages.config"
    $step1Success = Update-PackagesConfig -PackagesConfigPath $packagesConfigPath
    Write-Host ""
    
    # Step 2: Remove packages folder
    Remove-PackagesFolder -ProjectPath $ProjectPath
    Write-Host ""
    
    # Step 3: Update .vcxproj files
    $vcxprojFiles = Get-ChildItem $ProjectPath -Filter "*.vcxproj" -Recurse
    $step3Success = $true
    
    foreach ($vcxprojFile in $vcxprojFiles) {
        $result = Update-VcxprojFile -VcxprojPath $vcxprojFile.FullName
        $step3Success = $step3Success -and $result
        Write-Host ""
    }
    
    return $step1Success -and $step3Success
}

# Main execution
try {
    $success = Process-CppProject -ProjectPath $ProjectPath
    
    Write-Host "=== Summary ===" -ForegroundColor Green
    Write-Host "Packages to keep: $($PackagesToKeep -join ', ')" -ForegroundColor Green
    Write-Host "Packages to remove: $($PackagesToRemove -join ', ')" -ForegroundColor Red
    
    if ($WhatIf) {
        Write-Host ""
        Write-Host "This was a WHAT-IF run. No changes were made." -ForegroundColor Cyan
        Write-Host "Run without -WhatIf to apply changes." -ForegroundColor Cyan
    } elseif ($success) {
        Write-Host ""
        Write-Host "✅ Project cleanup completed successfully!" -ForegroundColor Green
        Write-Host "Backup files (.backup) created for safety." -ForegroundColor Blue
    } else {
        Write-Host ""
        Write-Host "❌ Some errors occurred during cleanup." -ForegroundColor Red
    }
} catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
