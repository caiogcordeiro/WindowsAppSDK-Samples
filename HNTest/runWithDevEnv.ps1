# Initialize Developer Command Prompt environment and run build script
$vsDevCmdPath = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat"

if (-not (Test-Path $vsDevCmdPath)) {
    Write-Error "VsDevCmd.bat not found at: $vsDevCmdPath"
    Write-Host "Please ensure Visual Studio is installed."
    exit 1
}

Write-Host "Initializing Developer Command Prompt environment..." -ForegroundColor Green

# Create a temporary batch file that sets up the environment and runs the PowerShell script
$tempBatchFile = Join-Path $env:TEMP "runBuildWithDevEnv.bat"
$batchContent = @"
@echo off
call "$vsDevCmdPath"
if errorlevel 1 (
    echo Failed to initialize Developer Command Prompt environment
    exit /b 1
)
cd /d "$PWD"
echo Environment PATH includes:
echo %PATH% | findstr /i nuget
echo.
powershell -ExecutionPolicy Bypass -Command "& { `$env:PATH = `$env:PATH; & '.\buildAllSolutions.ps1' }"
"@

$batchContent | Out-File -FilePath $tempBatchFile -Encoding ASCII

Write-Host "Running build script with Developer Command Prompt environment..." -ForegroundColor Yellow

# Execute the temporary batch file
& cmd /c $tempBatchFile

# Clean up
Remove-Item $tempBatchFile -ErrorAction SilentlyContinue

Write-Host "Build process completed!" -ForegroundColor Green
