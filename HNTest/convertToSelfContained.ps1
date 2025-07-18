# Convert All Projects to Self-Contained Deployment
param(
    [string]$AnalysisFile = "bothCSharpAndCppAnalysis.json",
    [switch]$WhatIf = $false,
    [switch]$Backup = $true
)

Write-Host "=== Converting All Projects to Self-Contained Deployment ===" -ForegroundColor Cyan
Write-Host "Reading analysis data from: $AnalysisFile"

if ($WhatIf) {
    Write-Host "🔍 WHAT-IF MODE: No changes will be made, only showing what would be modified" -ForegroundColor Yellow
}

# Read the analysis results
try {
    $analysisData = Get-Content -Path $AnalysisFile -Raw | ConvertFrom-Json
    Write-Host "Loaded analysis data with $($analysisData.solutions.Count) solutions" -ForegroundColor Green
} catch {
    Write-Error "Failed to read or parse analysis file: $_"
    exit 1
}

# Initialize counters
$totalProjectsProcessed = 0
$csharpProjectsModified = 0
$cppProjectsModified = 0
$alreadySelfContained = 0
$errors = 0

# Function to backup a file
function Backup-ProjectFile {
    param([string]$FilePath)
    
    if (-not $Backup) { return }
    
    $backupPath = "$FilePath.backup"
    if (-not (Test-Path $backupPath)) {
        Copy-Item $FilePath $backupPath -Force
        Write-Host "      📦 Backup created: $backupPath" -ForegroundColor Blue
    }
}

# Function to modify C# project file
function Convert-CSharpProject {
    param(
        [string]$ProjectPath,
        $ProjectInfo
    )
    
    if (-not (Test-Path $ProjectPath)) {
        Write-Host "      ❌ File not found: $ProjectPath" -ForegroundColor Red
        return $false
    }
    
    # Skip if already self-contained
    if ($ProjectInfo.deploymentType -eq "Self-Contained") {
        Write-Host "      ✅ Already Self-Contained: $($ProjectInfo.projectName)" -ForegroundColor Green
        $script:alreadySelfContained++
        return $true
    }
    
    try {
        $projectContent = Get-Content -Path $ProjectPath -Raw
        $projectXml = [xml]$projectContent
        
        # Find the first PropertyGroup that doesn't have a Condition
        $propertyGroup = $projectXml.Project.PropertyGroup | Where-Object { -not $_.Condition } | Select-Object -First 1
        
        if (-not $propertyGroup) {
            # Create a new PropertyGroup if none exists
            $propertyGroup = $projectXml.CreateElement("PropertyGroup")
            $projectXml.Project.AppendChild($propertyGroup) | Out-Null
        }
        
        # Check if WindowsAppSDKSelfContained already exists
        $existingProperty = $propertyGroup.WindowsAppSDKSelfContained
        if ($existingProperty) {
            $existingProperty.InnerText = "true"
        } else {
            # Add WindowsAppSDKSelfContained property
            $selfContainedElement = $projectXml.CreateElement("WindowsAppSDKSelfContained")
            $selfContainedElement.InnerText = "true"
            $propertyGroup.AppendChild($selfContainedElement) | Out-Null
        }
        
        if (-not $WhatIf) {
            Backup-ProjectFile -FilePath $ProjectPath
            
            # Save the modified XML
            $settings = New-Object System.Xml.XmlWriterSettings
            $settings.Indent = $true
            $settings.IndentChars = "  "
            $settings.NewLineChars = "`r`n"
            $settings.Encoding = [System.Text.Encoding]::UTF8
            
            $writer = [System.Xml.XmlWriter]::Create($ProjectPath, $settings)
            $projectXml.Save($writer)
            $writer.Close()
        }
        
        Write-Host "      🚀 Modified C# project: $($ProjectInfo.projectName)" -ForegroundColor Green
        $script:csharpProjectsModified++
        return $true
        
    } catch {
        Write-Host "      ❌ Failed to modify C# project: $($ProjectInfo.projectName) - $_" -ForegroundColor Red
        $script:errors++
        return $false
    }
}

# Function to modify C++ project file
function Convert-CppProject {
    param(
        [string]$ProjectPath,
        $ProjectInfo
    )
    
    if (-not (Test-Path $ProjectPath)) {
        Write-Host "      ❌ File not found: $ProjectPath" -ForegroundColor Red
        return $false
    }
    
    # Skip if already self-contained
    if ($ProjectInfo.deploymentType -eq "Self-Contained") {
        Write-Host "      ✅ Already Self-Contained: $($ProjectInfo.projectName)" -ForegroundColor Green
        $script:alreadySelfContained++
        return $true
    }
    
    try {
        $projectContent = Get-Content -Path $ProjectPath -Raw
        $projectXml = [xml]$projectContent
        
        # Find PropertyGroups - typically we want to add to the global one (without Condition)
        $propertyGroup = $projectXml.Project.PropertyGroup | Where-Object { -not $_.Condition } | Select-Object -First 1
        
        if (-not $propertyGroup) {
            # Create a new PropertyGroup if none exists
            $propertyGroup = $projectXml.CreateElement("PropertyGroup")
            $projectXml.Project.AppendChild($propertyGroup) | Out-Null
        }
        
        # Check if WindowsAppSDKSelfContained already exists
        $existingProperty = $propertyGroup.WindowsAppSDKSelfContained
        if ($existingProperty) {
            $existingProperty.InnerText = "true"
        } else {
            # Add WindowsAppSDKSelfContained property
            $selfContainedElement = $projectXml.CreateElement("WindowsAppSDKSelfContained")
            $selfContainedElement.InnerText = "true"
            $propertyGroup.AppendChild($selfContainedElement) | Out-Null
        }
        
        if (-not $WhatIf) {
            Backup-ProjectFile -FilePath $ProjectPath
            
            # Save the modified XML
            $settings = New-Object System.Xml.XmlWriterSettings
            $settings.Indent = $true
            $settings.IndentChars = "  "
            $settings.NewLineChars = "`r`n"
            $settings.Encoding = [System.Text.Encoding]::UTF8
            
            $writer = [System.Xml.XmlWriter]::Create($ProjectPath, $settings)
            $projectXml.Save($writer)
            $writer.Close()
        }
        
        Write-Host "      🚀 Modified C++ project: $($ProjectInfo.projectName)" -ForegroundColor Green
        $script:cppProjectsModified++
        return $true
        
    } catch {
        Write-Host "      ❌ Failed to modify C++ project: $($ProjectInfo.projectName) - $_" -ForegroundColor Red
        $script:errors++
        return $false
    }
}

# Process all solutions and their projects
Write-Host "Processing solutions and projects..." -ForegroundColor Yellow
Write-Host ""

foreach ($solution in $analysisData.solutions) {
    Write-Host "Processing Solution: $($solution.solutionName)" -ForegroundColor Magenta
    Write-Host "  Feature Area: $($solution.featureArea)"
    Write-Host "  Path: $($solution.relativePath)"
    
    $solutionModified = $false
    
    # Process C# projects
    if ($solution.csharpFrameworkDependentProjects.Count -gt 0 -or $solution.csharpSelfContainedProjects.Count -gt 0) {
        Write-Host "  📝 Processing C# Projects:" -ForegroundColor Cyan
        
        # Process framework-dependent C# projects
        foreach ($project in $solution.csharpFrameworkDependentProjects) {
            $totalProjectsProcessed++
            $result = Convert-CSharpProject -ProjectPath $project.fullPath -ProjectInfo $project
            if ($result) { $solutionModified = $true }
        }
        
        # Process already self-contained C# projects (just count them)
        foreach ($project in $solution.csharpSelfContainedProjects) {
            $totalProjectsProcessed++
            Write-Host "      ✅ Already Self-Contained: $($project.projectName)" -ForegroundColor Green
            $alreadySelfContained++
        }
    }
    
    # Process C++ projects
    if ($solution.cppFrameworkDependentProjects.Count -gt 0 -or $solution.cppSelfContainedProjects.Count -gt 0) {
        Write-Host "  🔧 Processing C++ Projects:" -ForegroundColor Cyan
        
        # Process framework-dependent C++ projects
        foreach ($project in $solution.cppFrameworkDependentProjects) {
            $totalProjectsProcessed++
            $result = Convert-CppProject -ProjectPath $project.fullPath -ProjectInfo $project
            if ($result) { $solutionModified = $true }
        }
        
        # Process already self-contained C++ projects (just count them)
        foreach ($project in $solution.cppSelfContainedProjects) {
            $totalProjectsProcessed++
            Write-Host "      ✅ Already Self-Contained: $($project.projectName)" -ForegroundColor Green
            $alreadySelfContained++
        }
    }
    
    if ($solutionModified) {
        Write-Host "  ✅ Solution modified successfully" -ForegroundColor Green
    } else {
        Write-Host "  ℹ️ No changes needed for this solution" -ForegroundColor Gray
    }
    
    Write-Host ""
}

# Summary
Write-Host "=== CONVERSION SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total solutions processed: $($analysisData.solutions.Count)"
Write-Host "Total projects processed: $totalProjectsProcessed"
Write-Host ""
Write-Host "Projects Modified:" -ForegroundColor Yellow
Write-Host "🔷 C# projects converted: $csharpProjectsModified" -ForegroundColor Green
Write-Host "🔶 C++ projects converted: $cppProjectsModified" -ForegroundColor Green
Write-Host "✅ Already self-contained: $alreadySelfContained" -ForegroundColor Blue
Write-Host "❌ Errors encountered: $errors" -ForegroundColor Red
Write-Host ""

$totalModified = $csharpProjectsModified + $cppProjectsModified
if ($WhatIf) {
    Write-Host "🔍 WHAT-IF MODE: $totalModified projects would be modified" -ForegroundColor Yellow
    Write-Host "Run without -WhatIf to apply changes" -ForegroundColor Yellow
} else {
    Write-Host "🚀 CONVERSION COMPLETE: $totalModified projects converted to self-contained" -ForegroundColor Green
    if ($Backup) {
        Write-Host "📦 Backup files created with .backup extension" -ForegroundColor Blue
    }
}

if ($errors -gt 0) {
    Write-Host "⚠️ $errors errors encountered during conversion" -ForegroundColor Red
}

Write-Host "=== SCRIPT COMPLETE ===" -ForegroundColor Cyan
