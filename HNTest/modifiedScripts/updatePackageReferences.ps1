# Update PackageReference in .csproj files from Microsoft.WindowsAppSDK to Microsoft.WindowsAppSDK.Foundation
# This script reads the project counts per solution JSON and updates all associated .csproj files

param(
    [string]$ProjectCountsFile = "q:\code_WASDK\WindowsAppSDK-Samples\HNTest\modifiedScripts\projectCountsPerSolution.json",
    [string]$SamplesPath = "q:\code_WASDK\WindowsAppSDK-Samples\Samples"
)

Write-Host "=== Updating PackageReference in .csproj Files ===" -ForegroundColor Cyan
Write-Host "Reading project data from: $ProjectCountsFile" -ForegroundColor Gray

# Check if input file exists
if (-not (Test-Path $ProjectCountsFile)) {
    Write-Error "Project counts file not found: $ProjectCountsFile"
    exit 1
}

# Read the project counts JSON
try {
    $projectData = Get-Content -Path $ProjectCountsFile -Raw | ConvertFrom-Json
    Write-Host "Loaded data for $($projectData.solutions.Count) solutions" -ForegroundColor Green
} catch {
    Write-Error "Failed to read or parse JSON file: $_"
    exit 1
}

$totalProcessed = 0
$totalUpdated = 0
$totalErrors = 0
$notUpdatedFiles = @()

Write-Host "Processing solutions to find and update .csproj files..." -ForegroundColor Yellow
Write-Host ""

foreach ($solution in $projectData.solutions) {
    if ($solution.csprojCount -gt 0) {
        Write-Host "Processing: $($solution.solutionName) [$($solution.featureArea)]" -ForegroundColor Cyan
        Write-Host "  Path: $($solution.relativePath)" -ForegroundColor Gray
        Write-Host "  Expected C# projects: $($solution.csprojCount)" -ForegroundColor Gray
        
        # Get the solution directory
        $solutionPath = Join-Path $SamplesPath $solution.relativePath
        $solutionDir = Split-Path -Parent $solutionPath
        
        if (-not (Test-Path $solutionDir)) {
            Write-Warning "  Solution directory not found: $solutionDir"
            $totalErrors++
            continue
        }
        
        # Find all .csproj files in the solution directory and subdirectories
        $csprojFiles = Get-ChildItem -Path $solutionDir -Filter "*.csproj" -Recurse -File -ErrorAction SilentlyContinue
        
        if ($csprojFiles.Count -eq 0) {
            Write-Warning "  No .csproj files found in: $solutionDir"
            continue
        }
        
        Write-Host "  Found $($csprojFiles.Count) .csproj files:" -ForegroundColor White
        
        foreach ($csprojFile in $csprojFiles) {
            $relativeCsprojPath = $csprojFile.FullName.Replace($solutionDir, "").TrimStart('\')
            Write-Host "    Processing: $relativeCsprojPath" -ForegroundColor Yellow
            
            try {
                # Read the .csproj file content
                $content = Get-Content -Path $csprojFile.FullName -Raw
                $originalContent = $content
                $totalProcessed++
                
                # Check if it contains any Microsoft.WindowsAppSDK PackageReference
                if ($content -match 'PackageReference\s+Include="Microsoft\.WindowsAppSDK"[^>]*Version="[^"]*"') {
                    # Replace any Microsoft.WindowsAppSDK PackageReference (regardless of version)
                    $updatedContent = $content -replace 
                        'PackageReference\s+Include="Microsoft\.WindowsAppSDK"([^>]*)Version="[^"]*"',
                        'PackageReference Include="Microsoft.WindowsAppSDK.Foundation" Version="1.8.250507001-experimental"'
                    
                    # Write the updated content back to the file
                    Set-Content -Path $csprojFile.FullName -Value $updatedContent -Encoding UTF8
                    
                    Write-Host "      ✅ Updated PackageReference" -ForegroundColor Green
                    $totalUpdated++
                } else {
                    Write-Host "      ℹ️  No Microsoft.WindowsAppSDK PackageReference found" -ForegroundColor Gray
                    $notUpdatedFiles += $csprojFile.FullName
                }
                
            } catch {
                Write-Error "      ❌ Error processing file: $_"
                $totalErrors++
            }
        }
        
        Write-Host ""
    }
}

# Display summary
Write-Host "=== SUMMARY ===" -ForegroundColor Yellow
Write-Host "Total .csproj files processed: $totalProcessed" -ForegroundColor Cyan
Write-Host "Total files updated: $totalUpdated" -ForegroundColor Green
Write-Host "Total files not updated: $($notUpdatedFiles.Count)" -ForegroundColor Yellow
Write-Host "Total errors: $totalErrors" -ForegroundColor Red

if ($totalUpdated -gt 0) {
    Write-Host ""
    Write-Host "✅ Successfully updated PackageReference in $totalUpdated .csproj files" -ForegroundColor Green
    Write-Host "   From: Microsoft.WindowsAppSDK Version <any>" -ForegroundColor Gray
    Write-Host "   To:   Microsoft.WindowsAppSDK.Foundation Version 1.8.250507001-experimental" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "ℹ️  No files required updates" -ForegroundColor Yellow
}

if ($notUpdatedFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Files not updated (no Microsoft.WindowsAppSDK PackageReference found):" -ForegroundColor Yellow
    foreach ($file in $notUpdatedFiles) {
        $relativePath = $file.Replace($SamplesPath, "").TrimStart('\')
        Write-Host "  - $relativePath" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== UPDATE COMPLETE ===" -ForegroundColor Cyan
