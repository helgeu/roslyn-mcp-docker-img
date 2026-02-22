<#
.SYNOPSIS
    Verify paths are correctly configured for roslyn-mcp.

.DESCRIPTION
    Checks that code and NuGet paths exist, are accessible, and Docker is available.

.PARAMETER CodePath
    Path to your code directory

.PARAMETER NuGetPath
    NuGet packages path (default: auto-detect)

.EXAMPLE
    .\verify-paths.ps1 -CodePath C:\git

.EXAMPLE
    .\verify-paths.ps1 -CodePath D:\projects -NuGetPath C:\Users\me\.nuget\packages
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$CodePath,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$NuGetPath
)

# Auto-detect home directory (works on Windows and macOS/Linux)
$homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
if (-not $NuGetPath) {
    $NuGetPath = Join-Path $homeDir ".nuget/packages"
}

$ErrorActionPreference = "Continue"
$errors = 0

function Write-Ok { param([string]$Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
function Write-Fail { param([string]$Message) Write-Host "  [FAIL] $Message" -ForegroundColor Red; $script:errors++ }

Write-Host "Verifying roslyn-mcp path configuration..." -ForegroundColor Cyan
Write-Host ""

# Check code path
Write-Host "Code path: $CodePath" -ForegroundColor White
if (-not (Test-Path $CodePath -PathType Container)) {
    Write-Fail "Directory does not exist"
}
else {
    $absCodePath = (Resolve-Path $CodePath).Path
    if ($CodePath -ne $absCodePath) {
        Write-Warn "Relative path detected, will use: $absCodePath"
    }
    Write-Ok "Directory exists and is readable"

    # Check for .sln files
    $slnFiles = Get-ChildItem -Path $CodePath -Filter "*.sln" -Recurse -Depth 3 -ErrorAction SilentlyContinue
    $slnCount = ($slnFiles | Measure-Object).Count
    if ($slnCount -gt 0) {
        Write-Ok "Found $slnCount .sln file(s)"
    }
    else {
        Write-Warn "No .sln files found in top 3 levels (Roslyn needs a solution file)"
    }
}
Write-Host ""

# Check NuGet path
Write-Host "NuGet path: $NuGetPath" -ForegroundColor White
if (-not (Test-Path $NuGetPath -PathType Container)) {
    Write-Fail "Directory does not exist"
    Write-Host "    Run 'dotnet restore' on a project to populate the NuGet cache" -ForegroundColor Gray
}
else {
    $absNuGetPath = (Resolve-Path $NuGetPath).Path
    if ($NuGetPath -ne $absNuGetPath) {
        Write-Warn "Relative path detected, will use: $absNuGetPath"
    }
    Write-Ok "Directory exists and is readable"

    # Check for package structure
    $pkgCount = (Get-ChildItem -Path $NuGetPath -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($pkgCount -gt 10) {
        Write-Ok "Contains $pkgCount packages"
    }
    elseif ($pkgCount -gt 0) {
        Write-Warn "Only $pkgCount packages found"
    }
    else {
        Write-Warn "NuGet cache appears empty"
    }
}
Write-Host ""

# Check Docker
Write-Host "Docker:" -ForegroundColor White
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Fail "Docker not found in PATH"
}
else {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Docker daemon not running"
    }
    else {
        Write-Ok "Docker is available"

        # Check if image exists
        $imageCheck = docker image inspect ghcr.io/helgeu/roslyn-mcp-docker-img:latest 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "roslyn-mcp image is pulled"
        }
        else {
            Write-Warn "Image not pulled yet (will be pulled on first use)"
        }
    }
}
Write-Host ""

# Summary
if ($errors -eq 0) {
    Write-Host "All checks passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Generate your config with:" -ForegroundColor Yellow
    Write-Host "  .\scripts\generate-config.ps1 -CodePath `"$absCodePath`"" -ForegroundColor White
    exit 0
}
else {
    Write-Host "$errors error(s) found" -ForegroundColor Red
    exit 1
}
