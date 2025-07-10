# Count .vcxproj files using packages.config among the 82 solutions
param(
    [string]$ProjectCountsFile = "projectCountsPerSolution.json",
    [string]$OutputFile = "vcxprojPackagesConfigCount.json"
)

# Base path to samples
$SamplesPath = "q:\code_WASDK\WindowsAppSDK-Samples\Samples"

Write-Host "=== Counting .vcxproj Files Using packages.config ===" -ForegroundColor Cyan
Write-Host "Reading project data from: $ProjectCountsFile"

# Read the project counts JSON file
try {
    $projectData = Get-Content -Path $ProjectCountsFile -Raw | ConvertFrom-Json
    Write-Host "Loaded data for $($projectData.solutions.Count) solutions" -ForegroundColor Green
} catch {
    Write-Error "Failed to read or parse JSON file: $_"
    exit 1
}

# Initialize counters
$totalVcxprojFiles = 0
$vcxprojWithPackagesConfig = 0
$vcxprojWithoutPackagesConfig = 0
$notFoundFiles = @()
$solutionResults = @()

Write-Host "Processing solutions to find .vcxproj files and check for packages.config..." -ForegroundColor Yellow
Write-Host ""

foreach ($solution in $projectData.solutions) {
    if ($solution.vcxprojCount -gt 0) {
        Write-Host "Processing: $($solution.solutionName) [$($solution.featureArea)]" -ForegroundColor Cyan
        Write-Host "  Path: $($solution.relativePath)" -ForegroundColor Gray
        Write-Host "  Expected C++ projects: $($solution.vcxprojCount)" -ForegroundColor Gray
        
        # Get the solution directory
        $solutionPath = Join-Path $SamplesPath $solution.relativePath
        $solutionDir = Split-Path -Parent $solutionPath
        
        if (-not (Test-Path $solutionDir)) {
            Write-Warning "  Solution directory not found: $solutionDir"
            continue
        }
        
        # Find all .vcxproj files in the solution directory and subdirectories
        $vcxprojFiles = Get-ChildItem -Path $solutionDir -Recurse -Filter "*.vcxproj" -File
        
        $solutionResult = @{
            "solutionName" = $solution.solutionName
            "featureArea" = $solution.featureArea
            "relativePath" = $solution.relativePath
            "expectedVcxprojCount" = $solution.vcxprojCount
            "foundVcxprojCount" = $vcxprojFiles.Count
            "vcxprojFiles" = @()
            "withPackagesConfigCount" = 0
            "withoutPackagesConfigCount" = 0
        }
        
        Write-Host "  Found $($vcxprojFiles.Count) .vcxproj files:" -ForegroundColor Yellow
        
        foreach ($vcxprojFile in $vcxprojFiles) {
            $totalVcxprojFiles++
            $relativePath = $vcxprojFile.FullName.Replace($solutionDir, "").TrimStart('\')
            $vcxprojDir = Split-Path -Parent $vcxprojFile.FullName
            $packagesConfigPath = Join-Path $vcxprojDir "packages.config"
            
            $hasPackagesConfig = Test-Path $packagesConfigPath
            
            $vcxprojResult = @{
                "relativePath" = $relativePath
                "fullPath" = $vcxprojFile.FullName
                "hasPackagesConfig" = $hasPackagesConfig
                "packagesConfigPath" = if ($hasPackagesConfig) { $packagesConfigPath } else { $null }
            }
            
            if ($hasPackagesConfig) {
                $vcxprojWithPackagesConfig++
                $solutionResult.withPackagesConfigCount++
                Write-Host "    ✅ $relativePath (has packages.config)" -ForegroundColor Green
            } else {
                $vcxprojWithoutPackagesConfig++
                $solutionResult.withoutPackagesConfigCount++
                Write-Host "    ❌ $relativePath (no packages.config)" -ForegroundColor Red
            }
            
            $solutionResult.vcxprojFiles += $vcxprojResult
        }
        
        $solutionResults += $solutionResult
        Write-Host ""
    }
}

# Create summary
$summary = @{
    "timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "totalSolutions" = $projectData.solutions.Count
    "solutionsWithVcxproj" = ($solutionResults | Where-Object { $_.foundVcxprojCount -gt 0 }).Count
    "totalVcxprojFiles" = $totalVcxprojFiles
    "vcxprojWithPackagesConfig" = $vcxprojWithPackagesConfig
    "vcxprojWithoutPackagesConfig" = $vcxprojWithoutPackagesConfig
    "percentageWithPackagesConfig" = if ($totalVcxprojFiles -gt 0) { [math]::Round(($vcxprojWithPackagesConfig / $totalVcxprojFiles) * 100, 2) } else { 0 }
}

$output = @{
    "summary" = $summary
    "solutions" = $solutionResults
}

# Save results to JSON file
$outputPath = Join-Path (Get-Location) $OutputFile
$jsonOutput = $output | ConvertTo-Json -Depth 5
$cleanJson = $jsonOutput -replace '    ', '  '
$cleanJson | Out-File -FilePath $outputPath -Encoding UTF8

# Display summary
Write-Host "=== SUMMARY ===" -ForegroundColor Yellow
Write-Host "Total solutions processed: $($summary.totalSolutions)" -ForegroundColor Cyan
Write-Host "Solutions with .vcxproj files: $($summary.solutionsWithVcxproj)" -ForegroundColor Cyan
Write-Host "Total .vcxproj files found: $($summary.totalVcxprojFiles)" -ForegroundColor Cyan
Write-Host "✅ .vcxproj with packages.config: $($summary.vcxprojWithPackagesConfig)" -ForegroundColor Green
Write-Host "❌ .vcxproj without packages.config: $($summary.vcxprojWithoutPackagesConfig)" -ForegroundColor Red
Write-Host "Percentage using packages.config: $($summary.percentageWithPackagesConfig)%" -ForegroundColor Yellow

Write-Host ""
Write-Host "Results saved to: $outputPath" -ForegroundColor Magenta

if ($summary.vcxprojWithoutPackagesConfig -gt 0) {
    Write-Host ""
    Write-Host "Projects without packages.config:" -ForegroundColor Yellow
    foreach ($solution in $solutionResults) {
        $withoutPackagesConfig = $solution.vcxprojFiles | Where-Object { -not $_.hasPackagesConfig }
        if ($withoutPackagesConfig.Count -gt 0) {
            Write-Host "  $($solution.solutionName):" -ForegroundColor Cyan
            foreach ($project in $withoutPackagesConfig) {
                Write-Host "    - $($project.relativePath)" -ForegroundColor Gray
            }
        }
    }
}

Write-Host ""
Write-Host "=== COUNT COMPLETE ===" -ForegroundColor Cyan
