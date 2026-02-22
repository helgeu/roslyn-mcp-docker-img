#!/usr/bin/env bash
set -euo pipefail

# Diagnose NuGet package resolution issues in roslyn-mcp Docker container
# Run this if you're seeing CS1503/CS8618 errors that don't appear in dotnet build

SCRIPT_NAME="$(basename "$0")"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME <solution-path> [nuget-path]

Diagnose NuGet package resolution issues in the roslyn-mcp Docker container.

Arguments:
  solution-path    Path to your .sln file
  nuget-path       NuGet packages path (default: ~/.nuget/packages)

This script checks:
  1. NuGet packages are readable from inside the container
  2. Package paths match between host and container
  3. Sample packages can be inspected
  4. Roslyn can load the solution

Examples:
  $SCRIPT_NAME ~/git/myproject/MyProject.sln
  $SCRIPT_NAME /path/to/Solution.sln ~/.nuget/packages
EOF
}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${CYAN}ℹ${NC} $1"; }

SOLUTION_PATH="${1:-}"
NUGET_PATH="${2:-$HOME/.nuget/packages}"

if [[ -z "$SOLUTION_PATH" ]] || [[ "$SOLUTION_PATH" == "-h" ]] || [[ "$SOLUTION_PATH" == "--help" ]]; then
    usage
    exit 0
fi

# Resolve paths
if [[ ! -f "$SOLUTION_PATH" ]]; then
    fail "Solution file not found: $SOLUTION_PATH"
    exit 1
fi
SOLUTION_PATH="$(cd "$(dirname "$SOLUTION_PATH")" && pwd)/$(basename "$SOLUTION_PATH")"
SOLUTION_DIR="$(dirname "$SOLUTION_PATH")"

if [[ ! -d "$NUGET_PATH" ]]; then
    fail "NuGet path not found: $NUGET_PATH"
    exit 1
fi
NUGET_PATH="$(cd "$NUGET_PATH" && pwd)"

IMAGE="ghcr.io/helgeu/roslyn-mcp-docker-img:latest"

echo -e "${CYAN}Diagnosing roslyn-mcp NuGet resolution${NC}"
echo "Solution: $SOLUTION_PATH"
echo "NuGet:    $NUGET_PATH"
echo ""

# Check 1: Can container see the solution?
echo "1. Checking solution visibility in container..."
if docker run --rm \
    -v "$SOLUTION_DIR:$SOLUTION_DIR:ro" \
    -v "$NUGET_PATH:$NUGET_PATH:ro" \
    --entrypoint /bin/bash \
    "$IMAGE" \
    -c "test -f '$SOLUTION_PATH'" 2>/dev/null; then
    ok "Solution file visible in container"
else
    fail "Solution file NOT visible in container"
    echo "   Check your volume mount paths"
    exit 1
fi

# Check 2: Can container read NuGet packages?
echo ""
echo "2. Checking NuGet packages visibility..."
PKG_COUNT=$(docker run --rm \
    -v "$SOLUTION_DIR:$SOLUTION_DIR:ro" \
    -v "$NUGET_PATH:$NUGET_PATH:ro" \
    --entrypoint /bin/bash \
    "$IMAGE" \
    -c "ls -1 '$NUGET_PATH' 2>/dev/null | wc -l" 2>/dev/null || echo "0")

if [[ "$PKG_COUNT" -gt 0 ]]; then
    ok "Container can see $PKG_COUNT packages in NuGet cache"
else
    fail "Container cannot read NuGet packages"
    echo "   Check permissions on $NUGET_PATH"
    exit 1
fi

# Check 3: Sample a specific package
echo ""
echo "3. Checking package structure..."
SAMPLE_PKG=$(docker run --rm \
    -v "$SOLUTION_DIR:$SOLUTION_DIR:ro" \
    -v "$NUGET_PATH:$NUGET_PATH:ro" \
    --entrypoint /bin/bash \
    "$IMAGE" \
    -c "ls -1 '$NUGET_PATH' | head -1" 2>/dev/null || echo "")

if [[ -n "$SAMPLE_PKG" ]]; then
    info "Sampling package: $SAMPLE_PKG"

    # Check if package has lib folder with DLLs
    DLL_COUNT=$(docker run --rm \
        -v "$SOLUTION_DIR:$SOLUTION_DIR:ro" \
        -v "$NUGET_PATH:$NUGET_PATH:ro" \
        --entrypoint /bin/bash \
        "$IMAGE" \
        -c "find '$NUGET_PATH/$SAMPLE_PKG' -name '*.dll' 2>/dev/null | wc -l" 2>/dev/null || echo "0")

    if [[ "$DLL_COUNT" -gt 0 ]]; then
        ok "Package contains $DLL_COUNT DLL(s)"
    else
        warn "Package has no DLLs (might be a meta-package)"
    fi
fi

# Check 4: Parse a csproj to find package references
echo ""
echo "4. Checking project package references..."
CSPROJ=$(find "$SOLUTION_DIR" -name "*.csproj" -type f | head -1)
if [[ -n "$CSPROJ" ]]; then
    info "Checking: $(basename "$CSPROJ")"

    # Extract PackageReference entries
    PKG_REFS=$(grep -oP 'Include="\K[^"]+' "$CSPROJ" 2>/dev/null | head -5 || true)

    if [[ -n "$PKG_REFS" ]]; then
        echo "   Found package references:"
        while IFS= read -r pkg; do
            PKG_LOWER=$(echo "$pkg" | tr '[:upper:]' '[:lower:]')
            if [[ -d "$NUGET_PATH/$PKG_LOWER" ]]; then
                ok "   $pkg → found in cache"
            else
                warn "   $pkg → NOT in cache (run 'dotnet restore')"
            fi
        done <<< "$PKG_REFS"
    fi
fi

# Check 5: Test Roslyn MCP get-diagnostics
echo ""
echo "5. Testing Roslyn MCP diagnostics..."
info "Sending get_diagnostics request (this may take a moment)..."

DIAG_RESULT=$(cat <<EOF | docker run -i --rm \
    -v "$SOLUTION_DIR:$SOLUTION_DIR" \
    -v "$NUGET_PATH:$NUGET_PATH:ro" \
    "$IMAGE" 2>&1 | grep -v "notifications/message" | tail -1
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"diagnose","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_diagnostics","arguments":{"solutionPath":"$SOLUTION_PATH"}}}
EOF
)

if echo "$DIAG_RESULT" | grep -q '"error"'; then
    fail "Roslyn MCP returned an error"
    echo "$DIAG_RESULT" | head -c 500
else
    # Count errors in result
    ERROR_COUNT=$(echo "$DIAG_RESULT" | grep -o '"severity":"Error"' | wc -l | tr -d ' ' || echo "0")
    WARN_COUNT=$(echo "$DIAG_RESULT" | grep -o '"severity":"Warning"' | wc -l | tr -d ' ' || echo "0")

    if [[ "$ERROR_COUNT" -gt 0 ]]; then
        warn "Roslyn reports $ERROR_COUNT error(s), $WARN_COUNT warning(s)"
        echo ""
        echo "   If 'dotnet build' shows 0 errors but Roslyn shows errors,"
        echo "   this indicates NuGet package resolution issues."
        echo ""
        echo "   Common errors that indicate this problem:"
        echo "   - CS1503: Argument type mismatch (package method signatures not resolved)"
        echo "   - CS8618: Non-nullable property not initialized (EF Core annotations missing)"
        echo "   - CS0246: Type or namespace not found"
    else
        ok "Roslyn reports $ERROR_COUNT errors, $WARN_COUNT warnings"
    fi
fi

echo ""
echo -e "${CYAN}Diagnosis complete${NC}"
echo ""
echo "If you're seeing phantom errors, possible causes:"
echo "  1. NuGet packages need restore: run 'dotnet restore' on the solution"
echo "  2. Package version mismatch: clear cache and restore"
echo "  3. Transitive dependencies: some packages may not be fully cached"
echo "  4. SDK version: container uses .NET 9.0, project may target different version"
echo ""
echo "To clear and restore NuGet cache:"
echo "  dotnet nuget locals all --clear"
echo "  dotnet restore $SOLUTION_PATH"
