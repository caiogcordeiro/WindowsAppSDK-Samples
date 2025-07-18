# Analyze Both C# and C++ Solutions from featureAreaSolutions.json
param(
    [string]$FeatureAreaSolutionsFile = "featureAreaSolutions.json",
    [string]$OutputFile = "bothCSharpAndCppAnalysis.json"
)

# Base path to samples
$SamplesPath = "q:\code_WASDK\WindowsAppSDK-Samples\Samples"

Write-Host "=== Analyzing Both C# and C++ Solutions from featureAreaSolutions.json ===" -ForegroundColor Cyan
Write-Host "Reading solution data from: $FeatureAreaSolutionsFile"

# Read the feature area paths JSON file to get the mapping
$featureAreaPathsFile = "featureAreaPaths.json"
$featureAreaPaths = @{}
try {
    $featureAreaPathsData = Get-Content -Path $featureAreaPathsFile -Raw | ConvertFrom-Json
    foreach ($pathData in $featureAreaPathsData) {
        $featureAreaPaths[$pathData.featureArea] = $pathData.relativePath
    }
    Write-Host "Loaded path mappings for $($featureAreaPathsData.Count) feature areas" -ForegroundColor Green
} catch {
    Write-Error "Failed to read or parse feature area paths JSON file: $_"
    exit 1
}

# Read the feature area solutions JSON file
try {
    $featureAreaData = Get-Content -Path $FeatureAreaSolutionsFile -Raw | ConvertFrom-Json
    Write-Host "Loaded data for $($featureAreaData.Count) feature areas" -ForegroundColor Green
} catch {
    Write-Error "Failed to read or parse JSON file: $_"
    exit 1
}

# Initialize counters
$totalSolutions = 0
$csharpSolutions = 0
$cppSolutions = 0
$selfContainedSolutions = 0
$frameworkDependentSolutions = 0
$mixedSolutions = 0
$unknownSolutions = 0
$totalSelfContainedProjects = 0
$totalFrameworkDependentProjects = 0
$totalUnknownProjects = 0
$solutionResults = @()

Write-Host "Processing solutions to find C# and C++ solutions..." -ForegroundColor Yellow
Write-Host ""

# Function to analyze a C# project file
function Analyze-CSharpProject {
    param(
        [string]$ProjectPath
    )
    
    if (-not (Test-Path $ProjectPath)) {
        return @{
            projectName = Split-Path $ProjectPath -LeafBase
            fullPath = $ProjectPath
            relativePath = $ProjectPath
            deploymentType = "Unknown"
            analysis = @("File not found")
            targetFramework = $null
            outputType = $null
            selfContained = $null
            windowsAppSDKSelfContained = $null
        }
    }
    
    try {
        $projectContent = Get-Content -Path $ProjectPath -Raw
        $projectXml = [xml]$projectContent
        
        # Extract basic project info
        $projectName = Split-Path $ProjectPath -LeafBase
        $targetFramework = $projectXml.Project.PropertyGroup.TargetFramework | Select-Object -First 1
        $outputType = $projectXml.Project.PropertyGroup.OutputType | Select-Object -First 1
        
        # Check for WindowsAppSDKSelfContained property
        $windowsAppSDKSelfContained = $projectXml.Project.PropertyGroup.WindowsAppSDKSelfContained | Select-Object -First 1
        
        # Check for .NET SelfContained property
        $selfContained = $projectXml.Project.PropertyGroup.SelfContained | Select-Object -First 1
        
        # Determine deployment type based on analysis
        $deploymentType = "Framework-Dependent"  # Default assumption
        $analysis = @()
        
        if ($windowsAppSDKSelfContained -eq "true") {
            $deploymentType = "Self-Contained"
            $analysis += "WindowsAppSDKSelfContained=true"
        } elseif ($selfContained -eq "true") {
            $deploymentType = "Self-Contained"
            $analysis += "SelfContained=true"
        } else {
            $analysis += "Default: Framework-Dependent"
        }
        
        return @{
            projectName = $projectName
            fullPath = $ProjectPath
            relativePath = $ProjectPath
            deploymentType = $deploymentType
            analysis = $analysis
            targetFramework = $targetFramework
            outputType = $outputType
            selfContained = $selfContained
            windowsAppSDKSelfContained = $windowsAppSDKSelfContained
        }
    } catch {
        Write-Warning "Failed to parse project file: $ProjectPath - $_"
        return @{
            projectName = Split-Path $ProjectPath -LeafBase
            fullPath = $ProjectPath
            relativePath = $ProjectPath
            deploymentType = "Unknown"
            analysis = @("Parse error: $_")
            targetFramework = $null
            outputType = $null
            selfContained = $null
            windowsAppSDKSelfContained = $null
        }
    }
}

# Function to analyze a C++ project file
function Analyze-CppProject {
    param(
        [string]$ProjectPath
    )
    
    if (-not (Test-Path $ProjectPath)) {
        return @{
            projectName = Split-Path $ProjectPath -LeafBase
            fullPath = $ProjectPath
            relativePath = $ProjectPath
            deploymentType = "Unknown"
            analysis = @("File not found")
            configurationType = $null
            platformToolset = $null
            windowsAppSDKSelfContained = $null
        }
    }
    
    try {
        $projectContent = Get-Content -Path $ProjectPath -Raw
        $projectXml = [xml]$projectContent
        
        # Extract basic project info
        $projectName = Split-Path $ProjectPath -LeafBase
        
        # Get configuration type and platform toolset
        $configurationType = $projectXml.Project.PropertyGroup.ConfigurationType | Select-Object -First 1
        $platformToolset = $projectXml.Project.PropertyGroup.PlatformToolset | Select-Object -First 1
        
        # Check for WindowsAppSDKSelfContained property in C++ projects
        $windowsAppSDKSelfContained = $projectXml.Project.PropertyGroup.WindowsAppSDKSelfContained | Select-Object -First 1
        
        # For C++ projects, deployment type is typically determined by different factors
        $deploymentType = "Framework-Dependent"  # Default assumption for C++
        $analysis = @()
        
        if ($windowsAppSDKSelfContained -eq "true") {
            $deploymentType = "Self-Contained"
            $analysis += "WindowsAppSDKSelfContained=true"
        } else {
            $analysis += "Default: Framework-Dependent (C++)"
        }
        
        return @{
            projectName = $projectName
            fullPath = $ProjectPath
            relativePath = $ProjectPath
            deploymentType = $deploymentType
            analysis = $analysis
            configurationType = $configurationType
            platformToolset = $platformToolset
            windowsAppSDKSelfContained = $windowsAppSDKSelfContained
        }
    } catch {
        Write-Warning "Failed to parse C++ project file: $ProjectPath - $_"
        return @{
            projectName = Split-Path $ProjectPath -LeafBase
            fullPath = $ProjectPath
            relativePath = $ProjectPath
            deploymentType = "Unknown"
            analysis = @("Parse error: $_")
            configurationType = $null
            platformToolset = $null
            windowsAppSDKSelfContained = $null
        }
    }
}

# Process each feature area
foreach ($featureArea in $featureAreaData) {
    $featureAreaName = $featureArea.featureArea
    Write-Host "Processing Feature Area: $featureAreaName" -ForegroundColor Magenta
    
    # Get the mapped path for this feature area
    $mappedPath = $featureAreaPaths[$featureAreaName]
    if (-not $mappedPath) {
        Write-Warning "No path mapping found for feature area: $featureAreaName"
        continue
    }
    
    # Process each solution in the feature area
    foreach ($solution in $featureArea.solutionFiles) {
        $solutionPath = $solution.relativePath
        $fullSolutionPath = Join-Path $SamplesPath (Join-Path $mappedPath $solutionPath)
        
        Write-Host "  Processing: $(Split-Path $solutionPath -LeafBase)"
        Write-Host "    Path: $solutionPath"
        
        $totalSolutions++
        
        if (-not (Test-Path $fullSolutionPath)) {
            Write-Host "    ❌ Solution file not found: $fullSolutionPath" -ForegroundColor Red
            continue
        }
        
        # Read solution file to find project references
        $solutionContent = Get-Content -Path $fullSolutionPath -Raw
        
        # Find C# project files (.csproj)
        $csprojMatches = [regex]::Matches($solutionContent, '"([^"]*\.csproj)"')
        $csprojFiles = @()
        foreach ($match in $csprojMatches) {
            $csprojFiles += $match.Groups[1].Value
        }
        
        # Find C++ project files (.vcxproj)
        $vcxprojMatches = [regex]::Matches($solutionContent, '"([^"]*\.vcxproj)"')
        $vcxprojFiles = @()
        foreach ($match in $vcxprojMatches) {
            $vcxprojFiles += $match.Groups[1].Value
        }
        
        # Find Windows Application Packaging Project (.wapproj)
        $hasWapProj = $solutionContent -match '\.wapproj'
        
        $csprojCount = $csprojFiles.Count
        $vcxprojCount = $vcxprojFiles.Count
        $totalProjectCount = $csprojCount + $vcxprojCount
        
        if ($totalProjectCount -eq 0) {
            Write-Host "    ❌ No C# or C++ projects found in solution file" -ForegroundColor Red
            continue
        }
        
        Write-Host "    Found $csprojCount C# projects and $vcxprojCount C++ projects" -ForegroundColor Green
        if ($hasWapProj) {
            Write-Host "    📦 Has Windows Application Packaging Project" -ForegroundColor Blue
        }
        
        # Analyze C# projects
        $csharpProjects = @()
        $csharpSelfContainedProjects = @()
        $csharpFrameworkDependentProjects = @()
        $csharpUnknownProjects = @()
        
        foreach ($csprojFile in $csprojFiles) {
            $fullCsprojPath = Join-Path (Split-Path $fullSolutionPath -Parent) $csprojFile
            $fullCsprojPath = [System.IO.Path]::GetFullPath($fullCsprojPath)
            
            Write-Host "      Analyzing C#: $fullCsprojPath"
            $projectAnalysis = Analyze-CSharpProject -ProjectPath $fullCsprojPath
            $csharpProjects += $projectAnalysis
            
            switch ($projectAnalysis.deploymentType) {
                "Self-Contained" { 
                    $csharpSelfContainedProjects += $projectAnalysis
                    $totalSelfContainedProjects++
                    Write-Host "        🚀 Self-Contained: $($projectAnalysis.analysis -join ', ')" -ForegroundColor Green
                }
                "Framework-Dependent" { 
                    $csharpFrameworkDependentProjects += $projectAnalysis
                    $totalFrameworkDependentProjects++
                    Write-Host "        📱 Framework-Dependent: $($projectAnalysis.analysis -join ', ')" -ForegroundColor Yellow
                }
                default { 
                    $csharpUnknownProjects += $projectAnalysis
                    $totalUnknownProjects++
                    Write-Host "        ❓ Unknown: $($projectAnalysis.analysis -join ', ')" -ForegroundColor Red
                }
            }
        }
        
        # Analyze C++ projects
        $cppProjects = @()
        $cppSelfContainedProjects = @()
        $cppFrameworkDependentProjects = @()
        $cppUnknownProjects = @()
        
        foreach ($vcxprojFile in $vcxprojFiles) {
            $fullVcxprojPath = Join-Path (Split-Path $fullSolutionPath -Parent) $vcxprojFile
            $fullVcxprojPath = [System.IO.Path]::GetFullPath($fullVcxprojPath)
            
            Write-Host "      Analyzing C++: $fullVcxprojPath"
            $projectAnalysis = Analyze-CppProject -ProjectPath $fullVcxprojPath
            $cppProjects += $projectAnalysis
            
            switch ($projectAnalysis.deploymentType) {
                "Self-Contained" { 
                    $cppSelfContainedProjects += $projectAnalysis
                    $totalSelfContainedProjects++
                    Write-Host "        🚀 Self-Contained: $($projectAnalysis.analysis -join ', ')" -ForegroundColor Green
                }
                "Framework-Dependent" { 
                    $cppFrameworkDependentProjects += $projectAnalysis
                    $totalFrameworkDependentProjects++
                    Write-Host "        📱 Framework-Dependent: $($projectAnalysis.analysis -join ', ')" -ForegroundColor Yellow
                }
                default { 
                    $cppUnknownProjects += $projectAnalysis
                    $totalUnknownProjects++
                    Write-Host "        ❓ Unknown: $($projectAnalysis.analysis -join ', ')" -ForegroundColor Red
                }
            }
        }
        
        # Determine overall solution deployment type
        $solutionDeploymentType = "Unknown"
        if ($csharpSelfContainedProjects.Count -gt 0 -or $cppSelfContainedProjects.Count -gt 0) {
            if ($csharpFrameworkDependentProjects.Count -gt 0 -or $cppFrameworkDependentProjects.Count -gt 0) {
                $solutionDeploymentType = "Mixed"
            } else {
                $solutionDeploymentType = "Self-Contained"
            }
        } elseif ($csharpFrameworkDependentProjects.Count -gt 0 -or $cppFrameworkDependentProjects.Count -gt 0) {
            $solutionDeploymentType = "Framework-Dependent"
        }
        
        # Create solution result
        $solutionResult = @{
            solutionName = Split-Path $solutionPath -LeafBase
            fullPath = $fullSolutionPath.ToLower()
            relativePath = $solutionPath
            featureArea = $featureAreaName
            hasWapProj = $hasWapProj
            csprojCount = $csprojCount
            vcxprojCount = $vcxprojCount
            totalProjectCount = $totalProjectCount
            deploymentType = $solutionDeploymentType
            
            # C# projects
            csharpSelfContainedProjects = $csharpSelfContainedProjects
            csharpFrameworkDependentProjects = $csharpFrameworkDependentProjects
            csharpUnknownProjects = $csharpUnknownProjects
            
            # C++ projects
            cppSelfContainedProjects = $cppSelfContainedProjects
            cppFrameworkDependentProjects = $cppFrameworkDependentProjects
            cppUnknownProjects = $cppUnknownProjects
            
            # All projects combined
            allProjects = $csharpProjects + $cppProjects
        }
        
        $solutionResults += $solutionResult
        
        # Update counters
        if ($csprojCount -gt 0) {
            $csharpSolutions++
        }
        if ($vcxprojCount -gt 0) {
            $cppSolutions++
        }
        
        # Update solution type counters
        switch ($solutionDeploymentType) {
            "Self-Contained" { $selfContainedSolutions++ }
            "Framework-Dependent" { $frameworkDependentSolutions++ }
            "Mixed" { $mixedSolutions++ }
            default { $unknownSolutions++ }
        }
        
        Write-Host "    📊 Solution Type: $solutionDeploymentType" -ForegroundColor Cyan
        Write-Host "       C# - Self-Contained: $($csharpSelfContainedProjects.Count), Framework-Dependent: $($csharpFrameworkDependentProjects.Count), Unknown: $($csharpUnknownProjects.Count)"
        Write-Host "       C++ - Self-Contained: $($cppSelfContainedProjects.Count), Framework-Dependent: $($cppFrameworkDependentProjects.Count), Unknown: $($cppUnknownProjects.Count)"
        Write-Host ""
    }
}

# Calculate percentages
$percentageSelfContained = if ($totalSolutions -gt 0) { [math]::Round(($selfContainedSolutions / $totalSolutions) * 100, 2) } else { 0 }
$percentageFrameworkDependent = if ($totalSolutions -gt 0) { [math]::Round(($frameworkDependentSolutions / $totalSolutions) * 100, 2) } else { 0 }
$percentageMixed = if ($totalSolutions -gt 0) { [math]::Round(($mixedSolutions / $totalSolutions) * 100, 2) } else { 0 }
$percentageUnknown = if ($totalSolutions -gt 0) { [math]::Round(($unknownSolutions / $totalSolutions) * 100, 2) } else { 0 }

# Create summary object
$summary = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    totalSolutionsScanned = $totalSolutions
    totalCSharpSolutions = $csharpSolutions
    totalCppSolutions = $cppSolutions
    
    # Solution-level stats
    selfContainedSolutions = $selfContainedSolutions
    frameworkDependentSolutions = $frameworkDependentSolutions
    mixedSolutions = $mixedSolutions
    unknownSolutions = $unknownSolutions
    
    percentageSelfContained = $percentageSelfContained
    percentageFrameworkDependent = $percentageFrameworkDependent
    percentageMixed = $percentageMixed
    percentageUnknown = $percentageUnknown
    
    # Project-level stats
    totalSelfContainedProjects = $totalSelfContainedProjects
    totalFrameworkDependentProjects = $totalFrameworkDependentProjects
    totalUnknownProjects = $totalUnknownProjects
}

# Create final result object
$result = @{
    summary = $summary
    solutions = $solutionResults
}

# Save results to JSON file
$jsonResult = $result | ConvertTo-Json -Depth 10
$jsonResult | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host "=== ANALYSIS SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total solutions scanned: $totalSolutions"
Write-Host "C# solutions found: $csharpSolutions"
Write-Host "C++ solutions found: $cppSolutions"
Write-Host ""
Write-Host "Solution Deployment Types:" -ForegroundColor Yellow
Write-Host "🚀 Self-Contained Solutions: $selfContainedSolutions ($percentageSelfContained%)" -ForegroundColor Green
Write-Host "📱 Framework-Dependent Solutions: $frameworkDependentSolutions ($percentageFrameworkDependent%)" -ForegroundColor Yellow
Write-Host "🔀 Mixed Solutions: $mixedSolutions ($percentageMixed%)" -ForegroundColor Blue
Write-Host "❓ Unknown Solutions: $unknownSolutions ($percentageUnknown%)" -ForegroundColor Red
Write-Host ""
Write-Host "Total Projects:" -ForegroundColor Yellow
Write-Host "🚀 Self-Contained Projects: $totalSelfContainedProjects" -ForegroundColor Green
Write-Host "📱 Framework-Dependent Projects: $totalFrameworkDependentProjects" -ForegroundColor Yellow
Write-Host "❓ Unknown Projects: $totalUnknownProjects" -ForegroundColor Red
Write-Host ""
Write-Host "Results saved to: $((Get-Item $OutputFile).FullName)" -ForegroundColor Green
Write-Host "=== ANALYSIS COMPLETE ===" -ForegroundColor Cyan
