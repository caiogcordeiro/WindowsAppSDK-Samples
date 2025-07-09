# Convert feature area list to file paths
param(
    [string]$InputFile = "featureAreaList.txt",
    [string]$OutputFile = "featureAreaPaths.json",
    [string]$SamplesBasePath = "q:\code_WASDK\WindowsAppSDK-Samples\Samples"
)

# Check if input file exists
if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

# Read the feature area list
$featureLines = Get-Content $InputFile

# Process each line and convert to file path
$convertedPaths = @()

foreach ($line in $featureLines) {
    # Skip empty lines
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }
    
    # Extract the feature name (remove leading "- '" and trailing "'")
    $feature = $line.Trim()
    if ($feature.StartsWith("- '") -and $feature.EndsWith("'")) {
        $feature = $feature.Substring(3, $feature.Length - 4)
    }
    
    # Apply the conversion rules
    $tempFeature = $feature.Replace("--", "TEMPHYPHEN")
    $tempFeature = $tempFeature.Replace("-", "\")
    $finalPath = $tempFeature.Replace("TEMPHYPHEN", "-")
    
    # Combine with base path
    $fullPath = Join-Path $SamplesBasePath $finalPath
    
    # Add to results
    $convertedPaths += @{
        "original" = $feature
        "converted" = $finalPath
        "fullPath" = $fullPath
    }
    
    Write-Host "Converted: '$feature' -> '$finalPath'"
}

# Write results to output file
$outputPath = Join-Path (Get-Location) $OutputFile
$jsonOutput = $convertedPaths | ForEach-Object {
    @{
        "featureArea" = $_.original
        "relativePath" = $_.converted
        "fullPath" = $_.fullPath
    }
}

# Convert entire array to JSON and write to file
$jsonOutput | ConvertTo-Json -Depth 3 | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host "`nConversion completed!"
Write-Host "Processed $($convertedPaths.Count) feature areas"
Write-Host "Output written to: $outputPath"

# Display some examples
Write-Host "`nExamples of conversions:"
$convertedPaths | Select-Object -First 5 | ForEach-Object {
    Write-Host "  '$($_.original)' -> '$($_.converted)'"
}
