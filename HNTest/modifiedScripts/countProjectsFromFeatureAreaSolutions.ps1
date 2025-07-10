# Count .csproj and .vcxproj files per solution based on featureAreaSolutions.json
# This script reads the existing solution data and counts project files for each solution

param(
    [string]$InputFile = "q:\code_WASDK\WindowsAppSDK-Samples\HNTest\featureAreaSolutions.json",
    [string]$OutputFile = "q:\code_WASDK\WindowsAppSDK-Samples\HNTest\modifiedScripts\projectCountsPerSolution.json"
)

Write-Host "=== Project Counter Based on Feature Area Solutions ===" -ForegroundColor Cyan
Write-Host "Reading solution data from: $InputFile" -ForegroundColor Gray

# Check if input file exists
if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

# Ensure output directory exists
$outputDir = Split-Path -Path $OutputFile -Parent
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force
}

# Read the feature area solutions JSON
try {
    $featureAreaData = Get-Content -Path $InputFile -Raw | ConvertFrom-Json
    Write-Host "Loaded data for $($featureAreaData.Count) feature areas" -ForegroundColor Green
} catch {
    Write-Error "Failed to read or parse JSON file: $_"
    exit 1
}

$results = @()
$totalSolutions = 0
$totalCsproj = 0
$totalVcxproj = 0

Write-Host "Analyzing project files for each solution..." -ForegroundColor Yellow

foreach ($featureArea in $featureAreaData) {
    $featureName = $featureArea.featureArea
    $basePath = $featureArea.fullPath
    
    Write-Host "Processing feature area: $featureName" -ForegroundColor Cyan
    
    foreach ($solution in $featureArea.solutionFiles) {
        $solutionPath = Join-Path $basePath $solution.relativePath
        $solutionName = Split-Path -Leaf $solutionPath
        $solutionDir = Split-Path -Parent $solutionPath
        
        # Check if solution file exists
        if (-not (Test-Path $solutionPath)) {
            Write-Warning "Solution file not found: $solutionPath"
            continue
        }
        
        # Count .csproj files in the solution directory and subdirectories
        $csprojFiles = Get-ChildItem -Path $solutionDir -Filter "*.csproj" -Recurse -File -ErrorAction SilentlyContinue
        $csprojCount = if ($csprojFiles) { $csprojFiles.Count } else { 0 }
        
        # Count .vcxproj files in the solution directory and subdirectories
        $vcxprojFiles = Get-ChildItem -Path $solutionDir -Filter "*.vcxproj" -Recurse -File -ErrorAction SilentlyContinue
        $vcxprojCount = if ($vcxprojFiles) { $vcxprojFiles.Count } else { 0 }
        
        $totalProjectCount = $csprojCount + $vcxprojCount
        
        # Create relative path from Samples folder
        $samplesPath = "q:\code_WASDK\WindowsAppSDK-Samples\Samples"
        $relativePath = $solutionPath.Replace($samplesPath, "").TrimStart('\')
        
        $result = [PSCustomObject]@{
            solutionName = $solutionName
            relativePath = $relativePath
            featureArea = $featureName
            csprojCount = $csprojCount
            vcxprojCount = $vcxprojCount
            totalProjectCount = $totalProjectCount
        }
        
        $results += $result
        $totalSolutions++
        $totalCsproj += $csprojCount
        $totalVcxproj += $vcxprojCount
        
        Write-Host "  $solutionName - C#: $csprojCount, C++: $vcxprojCount, Total: $totalProjectCount" -ForegroundColor White
    }
}

# Sort results by feature area and solution name
$results = $results | Sort-Object featureArea, solutionName

# Create output object
$output = [PSCustomObject]@{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    summary = [PSCustomObject]@{
        totalSolutions = $totalSolutions
        totalCsprojFiles = $totalCsproj
        totalVcxprojFiles = $totalVcxproj
        totalProjectFiles = $totalCsproj + $totalVcxproj
    }
    solutions = $results
}

# Save to JSON file
try {
    $output | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host ""
    Write-Host "Report saved to: $OutputFile" -ForegroundColor Green
} catch {
    Write-Error "Failed to save report: $_"
    exit 1
}

# Display summary
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Yellow
Write-Host "Total Solutions: $totalSolutions" -ForegroundColor Cyan
Write-Host "Total C# Projects: $totalCsproj" -ForegroundColor Green
Write-Host "Total C++ Projects: $totalVcxproj" -ForegroundColor Blue
Write-Host "Total Projects: $($totalCsproj + $totalVcxproj)" -ForegroundColor Magenta

# Display feature area summary
Write-Host ""
Write-Host "=== FEATURE AREA SUMMARY ===" -ForegroundColor Yellow
$featureGroups = $results | Group-Object featureArea
foreach ($group in $featureGroups | Sort-Object Name) {
    $featureCsproj = ($group.Group | Measure-Object csprojCount -Sum).Sum
    $featureVcxproj = ($group.Group | Measure-Object vcxprojCount -Sum).Sum
    $featureTotal = $featureCsproj + $featureVcxproj
    $solutionCount = $group.Count
    
    Write-Host "📁 $($group.Name): $solutionCount solutions, $featureTotal projects ($featureCsproj C#, $featureVcxproj C++)" -ForegroundColor Magenta
}

Write-Host ""
Write-Host "=== ANALYSIS COMPLETE ===" -ForegroundColor Cyan
