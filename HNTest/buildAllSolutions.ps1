# Build all feature area solutions with NuGet restore and MSBuild
param(
    [string]$InputFile = "featureAreaSolutions.json",
    [string]$OutputFile = "buildResults_Release_x64_modified_cpp.json",
    [string]$Configuration = "Release",
    [string]$Platform = "x64"
)

# Check if input file exists
if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

# Read the feature area solutions JSON
$featureAreas = Get-Content $InputFile | ConvertFrom-Json

# Initialize build results
$buildResults = @()
$totalSolutions = 0
$successfulBuilds = 0
$failedBuilds = 0

Write-Host "Starting build process for all feature area solutions..."
Write-Host "Configuration: $Configuration, Platform: $Platform, OutputFile: $OutputFile"
Write-Host ("=" * 80)

foreach ($featureArea in $featureAreas) {
    Write-Host "`nProcessing feature area: $($featureArea.featureArea)" -ForegroundColor Cyan
    Write-Host "Solution count: $($featureArea.solutionCount)"
    
    $featureResult = @{
        "featureArea" = $featureArea.featureArea
        "fullPath" = $featureArea.fullPath
        "solutionCount" = $featureArea.solutionCount
        "solutions" = @()
        "successCount" = 0
        "failCount" = 0
    }
    
    foreach ($solution in $featureArea.solutionFiles) {
        $totalSolutions++
        $solutionPath = Join-Path $featureArea.fullPath $solution.relativePath
        $solutionDir = Split-Path $solutionPath -Parent
        $solutionName = Split-Path $solutionPath -Leaf
        
        Write-Host "  Building: $($solution.relativePath)" -ForegroundColor Yellow
        
        $solutionResult = @{
            "relativePath" = $solution.relativePath
            "solutionName" = $solutionName
            "nugetRestoreSuccess" = $false
            "msbuildSuccess" = $false
            "buildDuration" = ""
        }
        
        $startTime = Get-Date
        
        try {
            # Check if solution file exists
            if (-not (Test-Path $solutionPath)) {
                throw "Solution file not found: $solutionPath"
            }
            
            # Change to solution directory
            Push-Location $solutionDir
            
            # Step 1: NuGet Restore (FORCE use nuget.exe)
            Write-Host "    Running NuGet restore..." -ForegroundColor Gray
            $nugetOutput = ""
            $nugetError = ""
            
            try {
                # Find nuget.exe in specific locations
                $nugetPaths = @(
                    "C:\tools\nuget.exe",
                    ".\nuget.exe",
                    "$env:USERPROFILE\nuget.exe",
                    "$env:USERPROFILE\Downloads\nuget.exe"
                )
                
                $nugetExe = $null
                foreach ($path in $nugetPaths) {
                    if (Test-Path $path) {
                        $nugetExe = $path
                        break
                    }
                }
                
                if ($nugetExe) {
                    Write-Host "    Using nuget.exe from: $nugetExe" -ForegroundColor Gray
                    $nugetResult = & $nugetExe restore $solutionName 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        $solutionResult.nugetRestoreSuccess = $true
                        Write-Host "    NuGet restore (nuget.exe): SUCCESS" -ForegroundColor Green
                    } else {
                        Write-Host "    NuGet restore (nuget.exe): FAILED, trying with NuGet.org source..." -ForegroundColor Yellow
                        # Try with explicit NuGet.org source
                        $nugetResult = & $nugetExe restore $solutionName -Source https://api.nuget.org/v3/index.json 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            $solutionResult.nugetRestoreSuccess = $true
                            Write-Host "    NuGet restore (with NuGet.org source): SUCCESS" -ForegroundColor Green
                        } else {
                            $solutionResult.nugetRestoreSuccess = $false
                            Write-Host "    NuGet restore (with NuGet.org source): FAILED" -ForegroundColor Red
                        }
                    }
                } else {
                    $solutionResult.nugetRestoreSuccess = $false
                    Write-Host "    NuGet restore: ERROR - nuget.exe not found in any of the expected locations" -ForegroundColor Red
                    Write-Host "    Expected locations: C:\tools\nuget.exe, .\nuget.exe, $env:USERPROFILE\nuget.exe, $env:USERPROFILE\Downloads\nuget.exe" -ForegroundColor Red
                    throw "nuget.exe not found"
                }
            } catch {
                $solutionResult.nugetRestoreSuccess = $false
                Write-Host "    NuGet restore: ERROR - $($_.Exception.Message)" -ForegroundColor Red
            }
            
            # Step 2: MSBuild
            Write-Host "    Running MSBuild..." -ForegroundColor Gray
            $msbuildOutput = ""
            $msbuildError = ""
            
            try {
                $msbuildResult = & msbuild $solutionName /p:Configuration=$Configuration /p:Platform=$Platform /verbosity:minimal 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $solutionResult.msbuildSuccess = $true
                    $featureResult.successCount++
                    $successfulBuilds++
                    Write-Host "    MSBuild: SUCCESS" -ForegroundColor Green
                } else {
                    $solutionResult.msbuildSuccess = $false
                    $featureResult.failCount++
                    $failedBuilds++
                    Write-Host "    MSBuild: FAILED" -ForegroundColor Red
                }
            } catch {
                $solutionResult.msbuildSuccess = $false
                $featureResult.failCount++
                $failedBuilds++
                Write-Host "    MSBuild: ERROR - $($_.Exception.Message)" -ForegroundColor Red
            }
            
        } catch {
            $solutionResult.nugetRestoreSuccess = $false
            $solutionResult.msbuildSuccess = $false
            $featureResult.failCount++
            $failedBuilds++
            Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
        } finally {
            Pop-Location
        }
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        $solutionResult.buildDuration = $duration.ToString("mm\:ss\.fff")
        
        $featureResult.solutions += $solutionResult
        
        Write-Host "    Duration: $($solutionResult.buildDuration)" -ForegroundColor Gray
    }
    
    $buildResults += $featureResult
    
    Write-Host "  Feature summary - Success: $($featureResult.successCount), Failed: $($featureResult.failCount)" -ForegroundColor Magenta
}

# Write results to output file - organized by feature area with status only
$outputPath = Join-Path (Get-Location) $OutputFile
# Convert to JSON with clean formatting (2-space indentation)
$jsonOutput = $buildResults | ConvertTo-Json -Depth 4
# Replace PowerShell's excessive indentation with clean 2-space indentation
$cleanJson = $jsonOutput -replace '    ', '  '
$cleanJson | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host ("`n" + "=" * 80)
Write-Host "BUILD SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 80)
Write-Host "Total solutions processed: $totalSolutions"
Write-Host "Successful builds: $successfulBuilds" -ForegroundColor Green
Write-Host "Failed builds: $failedBuilds" -ForegroundColor Red
Write-Host "Success rate: $(if ($totalSolutions -gt 0) { [math]::Round(($successfulBuilds / $totalSolutions) * 100, 2) } else { 0 })%"
Write-Host "Results saved to: $outputPath"

# Display failed builds summary
if ($failedBuilds -gt 0) {
    Write-Host "`nFAILED BUILDS:" -ForegroundColor Red
    foreach ($featureArea in $buildResults) {
        $failedSolutions = $featureArea.solutions | Where-Object { -not $_.msbuildSuccess }
        if ($failedSolutions.Count -gt 0) {
            Write-Host "  $($featureArea.featureArea):" -ForegroundColor Yellow
            foreach ($failed in $failedSolutions) {
                Write-Host "    - $($failed.relativePath)" -ForegroundColor Red
            }
        }
    }
}
