# Find all .sln files in feature area paths
param(
    [string]$InputFile = "featureAreaPaths.json",
    [string]$OutputFile = "featureAreaSolutions.json"
)

# Check if input file exists
if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

# Read the feature area paths JSON
$featureAreas = Get-Content $InputFile | ConvertFrom-Json

# Process each feature area to find .sln files
$results = @()

foreach ($feature in $featureAreas) {
    Write-Host "Processing feature area: $($feature.featureArea)"
    
    $featureResult = @{
        "featureArea" = $feature.featureArea
        "fullPath" = $feature.fullPath
        "solutionFiles" = @()
        "solutionCount" = 0
    }
    
    # Check if the path exists
    if (Test-Path $feature.fullPath) {
        # Find all .sln files recursively in this path
        $slnFiles = Get-ChildItem -Path $feature.fullPath -Filter "*.sln" -Recurse -ErrorAction SilentlyContinue
        
        foreach ($sln in $slnFiles) {
            # Calculate relative path properly by removing the feature area's full path
            # Use case-insensitive comparison to handle path case differences
            $featurePathLower = $feature.fullPath.ToLower()
            $slnPathLower = $sln.FullName.ToLower()
            
            if ($slnPathLower.StartsWith($featurePathLower)) {
                $relativePath = $sln.FullName.Substring($feature.fullPath.Length).TrimStart('\', '/')
            } else {
                $relativePath = $sln.FullName
            }
            
            $slnInfo = @{
                "relativePath" = $relativePath
            }
            
            $featureResult.solutionFiles += $slnInfo
        }
        
        $featureResult.solutionCount = $featureResult.solutionFiles.Count
        Write-Host "  Found $($featureResult.solutionCount) solution files"
    }
    else {
        Write-Host "  Path does not exist: $($feature.fullPath)" -ForegroundColor Yellow
    }
    
    $results += $featureResult
}

# Write results to output file
$outputPath = Join-Path (Get-Location) $OutputFile
$results | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host "`nScan completed!"
Write-Host "Processed $($featureAreas.Count) feature areas"
Write-Host "Total solution files found: $(($results | ForEach-Object { $_.solutionCount } | Measure-Object -Sum).Sum)"
Write-Host "Output written to: $outputPath"

# Display summary
Write-Host "`nSummary by feature area:"
$results | Where-Object { $_.solutionCount -gt 0 } | ForEach-Object {
    Write-Host "  $($_.featureArea): $($_.solutionCount) solution(s)"
}

Write-Host "`nFeature areas with no solutions:"
$results | Where-Object { $_.solutionCount -eq 0 } | ForEach-Object {
    Write-Host "  $($_.featureArea): No .sln files found" -ForegroundColor Yellow
}
