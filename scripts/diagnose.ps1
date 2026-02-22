<#
.SYNOPSIS
    Diagnose NuGet package resolution issues in roslyn-mcp Docker container.

.DESCRIPTION
    Run this if you're seeing CS1503/CS8618 errors that don't appear in dotnet build.
    These phantom errors indicate Roslyn can't resolve NuGet package types correctly.

.PARAMETER SolutionPath
    Path to your .sln file

.PARAMETER NuGetPath
    NuGet packages path (default: auto-detect)

.EXAMPLE
    .\diagnose.ps1 -SolutionPath C:\git\MyProject\MyProject.sln

.EXAMPLE
    .\diagnose.ps1 -SolutionPath ~/git/myproject/MyProject.sln
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SolutionPath,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$NuGetPath
)

$ErrorActionPreference = "Stop"

# Auto-detect home directory
$homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
if (-not $NuGetPath) {
    $NuGetPath = Join-Path $homeDir ".nuget/packages"
}

function Write-Ok { param([string]$Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
function Write-Fail { param([string]$Message) Write-Host "  [FAIL] $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host "  [INFO] $Message" -ForegroundColor Cyan }

# Validate paths
if (-not (Test-Path $SolutionPath -PathType Leaf)) {
    Write-Fail "Solution file not found: $SolutionPath"
    exit 1
}
$SolutionPath = (Resolve-Path $SolutionPath).Path
$SolutionDir = Split-Path $SolutionPath -Parent

if (-not (Test-Path $NuGetPath -PathType Container)) {
    Write-Fail "NuGet path not found: $NuGetPath"
    exit 1
}
$NuGetPath = (Resolve-Path $NuGetPath).Path

$Image = "ghcr.io/helgeu/roslyn-mcp-docker-img:latest"

Write-Host "Diagnosing roslyn-mcp NuGet resolution" -ForegroundColor Cyan
Write-Host "Solution: $SolutionPath"
Write-Host "NuGet:    $NuGetPath"
Write-Host ""

# Check 1: Can container see the solution?
Write-Host "1. Checking solution visibility in container..."
$testResult = docker run --rm `
    -v "${SolutionDir}:${SolutionDir}:ro" `
    -v "${NuGetPath}:${NuGetPath}:ro" `
    --entrypoint /bin/bash `
    $Image `
    -c "test -f '$SolutionPath' && echo 'found'" 2>&1

if ($testResult -match "found") {
    Write-Ok "Solution file visible in container"
} else {
    Write-Fail "Solution file NOT visible in container"
    Write-Host "   Check your volume mount paths" -ForegroundColor Gray
    exit 1
}

# Check 2: Can container read NuGet packages?
Write-Host ""
Write-Host "2. Checking NuGet packages visibility..."
$pkgCount = docker run --rm `
    -v "${SolutionDir}:${SolutionDir}:ro" `
    -v "${NuGetPath}:${NuGetPath}:ro" `
    --entrypoint /bin/bash `
    $Image `
    -c "ls -1 '$NuGetPath' 2>/dev/null | wc -l" 2>&1

$pkgCount = [int]($pkgCount -replace '\D', '')
if ($pkgCount -gt 0) {
    Write-Ok "Container can see $pkgCount packages in NuGet cache"
} else {
    Write-Fail "Container cannot read NuGet packages"
    Write-Host "   Check permissions on $NuGetPath" -ForegroundColor Gray
    exit 1
}

# Check 3: Check project package references
Write-Host ""
Write-Host "3. Checking project package references..."
$csprojFiles = Get-ChildItem -Path $SolutionDir -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if ($csprojFiles) {
    Write-Info "Checking: $($csprojFiles.Name)"
    $content = Get-Content $csprojFiles.FullName -Raw
    $pkgRefs = [regex]::Matches($content, 'Include="([^"]+)"') | Select-Object -First 5

    if ($pkgRefs.Count -gt 0) {
        Write-Host "   Found package references:"
        foreach ($match in $pkgRefs) {
            $pkg = $match.Groups[1].Value
            $pkgLower = $pkg.ToLower()
            $pkgPath = Join-Path $NuGetPath $pkgLower
            if (Test-Path $pkgPath) {
                Write-Ok "   $pkg -> found in cache"
            } else {
                Write-Warn "   $pkg -> NOT in cache (run 'dotnet restore')"
            }
        }
    }
}

# Check 4: Test Roslyn MCP diagnostics
Write-Host ""
Write-Host "4. Testing Roslyn MCP diagnostics..."
Write-Info "Sending get_diagnostics request (this may take a moment)..."

$mcpInput = @"
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"diagnose","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_diagnostics","arguments":{"solutionPath":"$SolutionPath"}}}
"@

$diagResult = $mcpInput | docker run -i --rm `
    -v "${SolutionDir}:${SolutionDir}" `
    -v "${NuGetPath}:${NuGetPath}:ro" `
    $Image 2>&1 | Select-String -NotMatch "notifications/message" | Select-Object -Last 1

$resultStr = $diagResult.ToString()
if ($resultStr -match '"error"') {
    Write-Fail "Roslyn MCP returned an error"
    Write-Host $resultStr.Substring(0, [Math]::Min(500, $resultStr.Length))
} else {
    $errorCount = ([regex]::Matches($resultStr, '"severity":"Error"')).Count
    $warnCount = ([regex]::Matches($resultStr, '"severity":"Warning"')).Count

    if ($errorCount -gt 0) {
        Write-Warn "Roslyn reports $errorCount error(s), $warnCount warning(s)"
        Write-Host ""
        Write-Host "   If 'dotnet build' shows 0 errors but Roslyn shows errors," -ForegroundColor Gray
        Write-Host "   this indicates NuGet package resolution issues." -ForegroundColor Gray
        Write-Host ""
        Write-Host "   Common errors that indicate this problem:" -ForegroundColor Gray
        Write-Host "   - CS1503: Argument type mismatch (package method signatures not resolved)" -ForegroundColor Gray
        Write-Host "   - CS8618: Non-nullable property not initialized (EF Core annotations missing)" -ForegroundColor Gray
        Write-Host "   - CS0246: Type or namespace not found" -ForegroundColor Gray
    } else {
        Write-Ok "Roslyn reports $errorCount errors, $warnCount warnings"
    }
}

Write-Host ""
Write-Host "Diagnosis complete" -ForegroundColor Cyan
Write-Host ""
Write-Host "If you're seeing phantom errors, possible causes:" -ForegroundColor Yellow
Write-Host "  1. NuGet packages need restore: run 'dotnet restore' on the solution"
Write-Host "  2. Package version mismatch: clear cache and restore"
Write-Host "  3. Transitive dependencies: some packages may not be fully cached"
Write-Host "  4. SDK version: container uses .NET 9.0, project may target different version"
Write-Host ""
Write-Host "To clear and restore NuGet cache:"
Write-Host "  dotnet nuget locals all --clear"
Write-Host "  dotnet restore `"$SolutionPath`""
