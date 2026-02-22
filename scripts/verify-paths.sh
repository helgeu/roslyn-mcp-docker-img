#!/usr/bin/env bash
set -euo pipefail

# Verify that paths are correctly configured for roslyn-mcp
# Checks that code and NuGet paths exist and are accessible

SCRIPT_NAME="$(basename "$0")"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME <code-path> [nuget-path]

Verify paths are correctly set up for roslyn-mcp Docker image.

Arguments:
  code-path    Path to your code directory
  nuget-path   NuGet packages path (default: ~/.nuget/packages)

Checks:
  - Paths exist and are readable
  - Paths are absolute (required for Docker volume mounts)
  - NuGet packages directory has expected structure
  - Sample .sln file can be found (optional)

Examples:
  $SCRIPT_NAME ~/git
  $SCRIPT_NAME ~/projects ~/.nuget/packages
EOF
}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

ok() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }

CODE_PATH="${1:-}"
NUGET_PATH="${2:-$HOME/.nuget/packages}"

if [[ -z "$CODE_PATH" ]] || [[ "$CODE_PATH" == "-h" ]] || [[ "$CODE_PATH" == "--help" ]]; then
    usage
    exit 0
fi

echo "Verifying roslyn-mcp path configuration..."
echo ""

ERRORS=0

# Check code path
echo "Code path: $CODE_PATH"
if [[ ! -d "$CODE_PATH" ]]; then
    fail "Directory does not exist"
    ((ERRORS++))
elif [[ ! -r "$CODE_PATH" ]]; then
    fail "Directory is not readable"
    ((ERRORS++))
else
    # Resolve to absolute
    ABS_CODE_PATH="$(cd "$CODE_PATH" && pwd)"
    if [[ "$CODE_PATH" != "$ABS_CODE_PATH" ]]; then
        warn "Relative path detected, will use: $ABS_CODE_PATH"
    fi
    ok "Directory exists and is readable"

    # Check for .sln files
    SLN_COUNT=$(find "$CODE_PATH" -maxdepth 3 -name "*.sln" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$SLN_COUNT" -gt 0 ]]; then
        ok "Found $SLN_COUNT .sln file(s)"
    else
        warn "No .sln files found in top 3 levels (Roslyn needs a solution file)"
    fi
fi
echo ""

# Check NuGet path
echo "NuGet path: $NUGET_PATH"
if [[ ! -d "$NUGET_PATH" ]]; then
    fail "Directory does not exist"
    echo "  Run 'dotnet restore' on a project to populate the NuGet cache"
    ((ERRORS++))
elif [[ ! -r "$NUGET_PATH" ]]; then
    fail "Directory is not readable"
    ((ERRORS++))
else
    ABS_NUGET_PATH="$(cd "$NUGET_PATH" && pwd)"
    if [[ "$NUGET_PATH" != "$ABS_NUGET_PATH" ]]; then
        warn "Relative path detected, will use: $ABS_NUGET_PATH"
    fi
    ok "Directory exists and is readable"

    # Check for package structure
    PKG_COUNT=$(find "$NUGET_PATH" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$PKG_COUNT" -gt 10 ]]; then
        ok "Contains $((PKG_COUNT - 1)) packages"
    elif [[ "$PKG_COUNT" -gt 1 ]]; then
        warn "Only $((PKG_COUNT - 1)) packages found"
    else
        warn "NuGet cache appears empty"
    fi
fi
echo ""

# Test Docker
echo "Docker:"
if ! command -v docker &>/dev/null; then
    fail "Docker not found in PATH"
    ((ERRORS++))
elif ! docker info &>/dev/null; then
    fail "Docker daemon not running"
    ((ERRORS++))
else
    ok "Docker is available"

    # Check if image exists
    if docker image inspect ghcr.io/helgeu/roslyn-mcp-docker-img:latest &>/dev/null; then
        ok "roslyn-mcp image is pulled"
    else
        warn "Image not pulled yet (will be pulled on first use)"
    fi
fi
echo ""

# Summary
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo ""
    echo "Generate your config with:"
    echo "  ./scripts/generate-config.sh ${ABS_CODE_PATH:-$CODE_PATH}"
    exit 0
else
    echo -e "${RED}$ERRORS error(s) found${NC}"
    exit 1
fi
