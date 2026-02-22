<#
.SYNOPSIS
    Generate MCP configuration for roslyn-mcp Docker image.

.DESCRIPTION
    Generates Claude Code MCP configuration with correct path mappings
    for the roslyn-mcp Docker image.

.PARAMETER CodePath
    Path to your code directory (e.g., C:\git, D:\projects)

.PARAMETER NuGetPath
    NuGet packages path (default: auto-detect from %USERPROFILE%\.nuget\packages)

.PARAMETER OutputFile
    Write config to file instead of stdout

.EXAMPLE
    .\generate-config.ps1 -CodePath C:\git

.EXAMPLE
    .\generate-config.ps1 -CodePath D:\projects -NuGetPath C:\Users\me\.nuget\packages

.EXAMPLE
    .\generate-config.ps1 -CodePath C:\git -OutputFile mcp-config.json
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$CodePath,

    [Parameter(Mandatory = $false)]
    [string]$NuGetPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile
)

$ErrorActionPreference = "Stop"

# Resolve code path to absolute
if (-not (Test-Path $CodePath -PathType Container)) {
    Write-Error "Code path does not exist: $CodePath"
    exit 1
}
$CodePath = (Resolve-Path $CodePath).Path

# Auto-detect home directory (works on Windows and macOS/Linux)
$homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }

# Auto-detect NuGet path if not specified
if (-not $NuGetPath) {
    $defaultNuGet = Join-Path $homeDir ".nuget/packages"
    if (Test-Path $defaultNuGet -PathType Container) {
        $NuGetPath = $defaultNuGet
    }
    elseif ($env:NUGET_PACKAGES -and (Test-Path $env:NUGET_PACKAGES -PathType Container)) {
        $NuGetPath = $env:NUGET_PACKAGES
    }
    else {
        Write-Error "Could not auto-detect NuGet packages path. Specify with -NuGetPath"
        exit 1
    }
}

# Resolve NuGet path to absolute
if (-not (Test-Path $NuGetPath -PathType Container)) {
    Write-Error "NuGet path does not exist: $NuGetPath"
    exit 1
}
$NuGetPath = (Resolve-Path $NuGetPath).Path

# Convert Windows paths to Docker-compatible format
# Docker on Windows can use either format, but forward slashes are safer in JSON
function ConvertTo-DockerPath {
    param([string]$Path)
    # Keep the path as-is for Windows Docker, but escape backslashes for JSON
    return $Path
}

$dockerCodePath = ConvertTo-DockerPath $CodePath
$dockerNuGetPath = ConvertTo-DockerPath $NuGetPath

# Generate config JSON
$config = @{
    roslyn = @{
        command = "docker"
        args    = @(
            "run", "-i", "--rm",
            "-v", "${dockerCodePath}:${dockerCodePath}",
            "-v", "${dockerNuGetPath}:${dockerNuGetPath}:ro",
            "ghcr.io/helgeu/roslyn-mcp-docker-img:latest"
        )
    }
} | ConvertTo-Json -Depth 10

# Output
if ($OutputFile) {
    $config | Out-File -FilePath $OutputFile -Encoding utf8
    Write-Host "Config written to: $OutputFile" -ForegroundColor Green
    Write-Host ""
    Write-Host "Add to Claude settings.json under 'mcpServers':" -ForegroundColor Yellow
    Write-Host $config
}
else {
    Write-Output $config
}
