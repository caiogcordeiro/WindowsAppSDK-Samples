# C++ Project Package Cleanup Script - Batch Mode
param(
    [string]$ProjectPath = "",
    [switch]$WhatIf = $false,
    [switch]$ProcessAllCppSolutions = $false,
    [string]$FeatureAreaSolutionsFile = "..\featureAreaSolutions.json"
)

Write-Host "=== C++ Project Package Cleanup Script - Batch Mode ===" -ForegroundColor Green
if ($ProcessAllCppSolutions) {
    Write-Host "Mode: Process All C++ Solutions" -ForegroundColor Cyan
    Write-Host "Feature Area Solutions File: $FeatureAreaSolutionsFile"
} else {
    Write-Host "Mode: Single Project" -ForegroundColor Cyan
    Write-Host "Project Path: $ProjectPath"
}
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

# Function to load and filter C++ solutions
function Get-CppSolutions {
    param([string]$FeatureAreaSolutionsFile)
    
    if (!(Test-Path $FeatureAreaSolutionsFile)) {
        Write-Error "Feature area solutions file not found: $FeatureAreaSolutionsFile"
        return @()
    }
    
    Write-Host "Loading feature area solutions from: $FeatureAreaSolutionsFile" -ForegroundColor Yellow
    
    try {
        $featureAreas = Get-Content $FeatureAreaSolutionsFile | ConvertFrom-Json
        $cppSolutions = @()
        
        foreach ($featureArea in $featureAreas) {
            foreach ($solution in $featureArea.solutionFiles) {
                # Identify C++ solutions by path patterns
                if ($solution.relativePath -match "cpp-|\\cpp\\|\\native\\|-cpp\\") {
                    $cppSolution = [PSCustomObject]@{
                        FeatureArea = $featureArea.featureArea
                        SolutionPath = $solution.relativePath
                        FullPath = $featureArea.fullPath
                        SolutionName = Split-Path $solution.relativePath -Leaf
                    }
                    $cppSolutions += $cppSolution
                }
            }
        }
        
        Write-Host "Found $($cppSolutions.Count) C++ solutions out of $(($featureAreas | ForEach-Object { $_.solutionFiles.Count } | Measure-Object -Sum).Sum) total solutions" -ForegroundColor Green
        return $cppSolutions
        
    } catch {
        Write-Error "Failed to load feature area solutions: $($_.Exception.Message)"
        return @()
    }
}

# Function to find project directories for a solution
function Get-ProjectDirectoriesFromSolution {
    param(
        [string]$SolutionPath,
        [string]$FeatureAreaPath
    )
    
    $solutionDir = Join-Path $FeatureAreaPath (Split-Path $SolutionPath -Parent)
    $projectDirs = @()
    
    if (Test-Path $solutionDir) {
        # Look for project directories containing .vcxproj files (primary requirement)
        $projectDirs += Get-ChildItem $solutionDir -Directory | Where-Object { 
            (Get-ChildItem $_.FullName -Filter "*.vcxproj" -ErrorAction SilentlyContinue)
        } | ForEach-Object { $_.FullName }
        
        # Also check if the solution directory itself contains .vcxproj files
        if (Get-ChildItem $solutionDir -Filter "*.vcxproj" -ErrorAction SilentlyContinue) {
            $projectDirs += $solutionDir
        }
        
        # If no .vcxproj files found, but packages.config exists, still include it
        # (in case the .vcxproj file is in a different location or has different structure)
        if ($projectDirs.Count -eq 0) {
            $projectDirs += Get-ChildItem $solutionDir -Directory | Where-Object { 
                (Get-ChildItem $_.FullName -Filter "packages.config" -ErrorAction SilentlyContinue)
            } | ForEach-Object { $_.FullName }
            
            if ((Get-ChildItem $solutionDir -Filter "packages.config" -ErrorAction SilentlyContinue)) {
                $projectDirs += $solutionDir
            }
        }
        
        # Remove duplicates
        $projectDirs = $projectDirs | Sort-Object -Unique
    }
    
    return $projectDirs
}

function Update-PackagesConfig {
    param(
        [string]$PackagesConfigPath,
        [switch]$WhatIf
    )
    
    if (!(Test-Path $PackagesConfigPath)) {
        Write-Host "packages.config not found at: $PackagesConfigPath" -ForegroundColor Gray
        Write-Host "  This is normal for projects that don't use NuGet packages" -ForegroundColor Gray
        return $true  # Not an error - just nothing to do
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
    param(
        [string]$ProjectPath,
        [switch]$WhatIf
    )
    
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
    param(
        [string]$VcxprojPath,
        [switch]$WhatIf
    )
    
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
    param(
        [string]$ProjectPath,
        [switch]$WhatIf
    )
    
    if (!(Test-Path $ProjectPath)) {
        return [PSCustomObject]@{
            Success = $false
            ErrorMessage = "Project path not found: $ProjectPath"
        }
    }
    
    Write-Host "Processing C++ project: $ProjectPath" -ForegroundColor Magenta
    Write-Host ""
    
    try {
        # Step 1: Update packages.config (only if it exists)
        $packagesConfigPath = Join-Path $ProjectPath "packages.config"
        $step1Success = $true  # Default to success in case packages.config doesn't exist
        
        if (Test-Path $packagesConfigPath) {
            $step1Success = Update-PackagesConfig -PackagesConfigPath $packagesConfigPath -WhatIf:$WhatIf
        } else {
            Write-Host "No packages.config found - skipping package cleanup (this is normal for some projects)" -ForegroundColor Gray
        }
        Write-Host ""
        
        # Step 2: Remove packages folder (always attempt this)
        Remove-PackagesFolder -ProjectPath $ProjectPath -WhatIf:$WhatIf
        Write-Host ""
        
        # Step 3: Update .vcxproj files (always attempt this - this is the critical part for all C++ projects)
        $vcxprojFiles = Get-ChildItem $ProjectPath -Filter "*.vcxproj" -Recurse
        $step3Success = $true
        
        if ($vcxprojFiles.Count -eq 0) {
            Write-Warning "No .vcxproj files found in: $ProjectPath"
            Write-Host "  This might not be a C++ project directory" -ForegroundColor Yellow
        } else {
            foreach ($vcxprojFile in $vcxprojFiles) {
                $result = Update-VcxprojFile -VcxprojPath $vcxprojFile.FullName -WhatIf:$WhatIf
                $step3Success = $step3Success -and $result
                Write-Host ""
            }
        }
        
        $overallSuccess = $step1Success -and $step3Success
        
        return [PSCustomObject]@{
            Success = $overallSuccess
            ErrorMessage = if ($overallSuccess) { "" } else { "Some steps failed during processing" }
        }
        
    } catch {
        return [PSCustomObject]@{
            Success = $false
            ErrorMessage = $_.Exception.Message
        }
    }
}

# Main processing logic
try {
    if ($ProcessAllCppSolutions) {
        Write-Host "Starting batch processing of all C++ solutions..." -ForegroundColor Cyan
        
        # Load C++ solutions from JSON file
        $cppSolutions = Get-CppSolutions -FeatureAreaSolutionsFile $FeatureAreaSolutionsFile
        
        if ($cppSolutions.Count -eq 0) {
            Write-Warning "No C++ solutions found in $FeatureAreaSolutionsFile"
            exit 0
        }
        
        $totalProcessed = 0
        $totalSkipped = 0
        $totalErrors = 0
        
        foreach ($solution in $cppSolutions) {
            Write-Host "`n" + "="*80 -ForegroundColor Cyan
            Write-Host "Processing Solution: $($solution.SolutionName)" -ForegroundColor Cyan
            Write-Host "Feature Area: $($solution.FeatureArea)" -ForegroundColor Gray
            Write-Host "Solution Path: $($solution.SolutionPath)" -ForegroundColor Gray
            Write-Host "="*80 -ForegroundColor Cyan
            
            try {
                # Find project directories for this solution
                $projectDirs = Get-ProjectDirectoriesFromSolution -SolutionPath $solution.SolutionPath -FeatureAreaPath $solution.FullPath
                
                if ($projectDirs.Count -eq 0) {
                    Write-Warning "No project directories found for solution: $($solution.SolutionName)"
                    Write-Host "  Solution directory checked: $solutionDir" -ForegroundColor Red
                    $totalSkipped++
                    continue
                }
                
                Write-Host "Found $($projectDirs.Count) project directories:" -ForegroundColor Yellow
                foreach ($dir in $projectDirs) {
                    Write-Host "  - $dir" -ForegroundColor Gray
                }
                
                # Process each project directory
                foreach ($projectDir in $projectDirs) {
                    $projectName = Split-Path $projectDir -Leaf
                    Write-Host "`nProcessing project: $projectName" -ForegroundColor Green
                    
                    $result = Process-CppProject -ProjectPath $projectDir -WhatIf:$WhatIf
                    
                    if ($result.Success) {
                        $totalProcessed++
                        Write-Host "✓ Successfully processed: $projectName" -ForegroundColor Green
                    } else {
                        $totalErrors++
                        Write-Warning "✗ Failed to process: $projectName - $($result.ErrorMessage)"
                    }
                }
                
            } catch {
                Write-Error "Error processing solution $($solution.SolutionName): $($_.Exception.Message)"
                $totalErrors++
            }
        }
        
        # Summary
        Write-Host "`n" + "="*80 -ForegroundColor Cyan
        Write-Host "BATCH PROCESSING SUMMARY" -ForegroundColor Cyan
        Write-Host "="*80 -ForegroundColor Cyan
        Write-Host "Total C++ Solutions Found: $($cppSolutions.Count)" -ForegroundColor White
        Write-Host "Total Projects Processed: $totalProcessed" -ForegroundColor Green
        Write-Host "Total Projects Skipped: $totalSkipped" -ForegroundColor Yellow
        Write-Host "Total Errors: $totalErrors" -ForegroundColor Red
        Write-Host "Packages to keep: $($PackagesToKeep -join ', ')" -ForegroundColor Green
        Write-Host "Packages to remove: $($PackagesToRemove -join ', ')" -ForegroundColor Red
        Write-Host "="*80 -ForegroundColor Cyan
        
        if ($WhatIf) {
            Write-Host "`nNOTE: This was a simulation run (WhatIf mode). No actual changes were made." -ForegroundColor Yellow
            Write-Host "Run the script without -WhatIf to apply changes." -ForegroundColor Yellow
        }
        
    } else {
        # Single project mode
        Write-Host "Processing single project: $ProjectPath" -ForegroundColor Cyan
        
        if (!(Test-Path $ProjectPath)) {
            Write-Error "Project path not found: $ProjectPath"
            exit 1
        }
        
        $result = Process-CppProject -ProjectPath $ProjectPath -WhatIf:$WhatIf
        
        if ($result.Success) {
            Write-Host "`n=== Summary ===" -ForegroundColor Green
            Write-Host "Packages to keep: $($PackagesToKeep -join ', ')" -ForegroundColor Green
            Write-Host "Packages to remove: $($PackagesToRemove -join ', ')" -ForegroundColor Red
            Write-Host "✓ Project processing completed successfully!" -ForegroundColor Green
            
            if ($WhatIf) {
                Write-Host "`nNOTE: This was a simulation run (WhatIf mode). No actual changes were made." -ForegroundColor Yellow
                Write-Host "Run the script without -WhatIf to apply changes." -ForegroundColor Yellow
            } else {
                Write-Host "Backup files (.backup) created for safety." -ForegroundColor Blue
            }
        } else {
            Write-Error "Project processing failed: $($result.ErrorMessage)"
            exit 1
        }
    }
    
} catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
