#!/usr/bin/env bash
set -euo pipefail

# Generate MCP configuration for roslyn-mcp Docker image
# Ensures paths are correctly mapped for Roslyn to find files and packages

SCRIPT_NAME="$(basename "$0")"

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <code-path>

Generate Claude Code MCP configuration for roslyn-mcp.

Arguments:
  code-path    Path to your code directory (e.g., ~/git, ~/projects)

Options:
  -n, --nuget PATH    NuGet packages path (default: auto-detect)
  -o, --output FILE   Write config to file instead of stdout
  -h, --help          Show this help

Examples:
  $SCRIPT_NAME ~/git
  $SCRIPT_NAME --nuget ~/.nuget/packages ~/projects
  $SCRIPT_NAME ~/git --output mcp-config.json

The generated config can be added to ~/.claude/settings.json under "mcpServers".
EOF
}

# Defaults
NUGET_PATH=""
OUTPUT_FILE=""
CODE_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--nuget)
            NUGET_PATH="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            CODE_PATH="$1"
            shift
            ;;
    esac
done

# Validate code path
if [[ -z "$CODE_PATH" ]]; then
    echo "Error: code-path is required" >&2
    usage >&2
    exit 1
fi

# Resolve to absolute path
CODE_PATH="$(cd "$CODE_PATH" 2>/dev/null && pwd)" || {
    echo "Error: code-path does not exist: $CODE_PATH" >&2
    exit 1
}

# Auto-detect NuGet path if not specified
if [[ -z "$NUGET_PATH" ]]; then
    # Check common locations
    if [[ -d "$HOME/.nuget/packages" ]]; then
        NUGET_PATH="$HOME/.nuget/packages"
    elif [[ -n "${NUGET_PACKAGES:-}" && -d "$NUGET_PACKAGES" ]]; then
        NUGET_PATH="$NUGET_PACKAGES"
    else
        echo "Error: Could not auto-detect NuGet packages path" >&2
        echo "Specify manually with --nuget PATH" >&2
        exit 1
    fi
fi

# Resolve NuGet path to absolute
NUGET_PATH="$(cd "$NUGET_PATH" 2>/dev/null && pwd)" || {
    echo "Error: NuGet path does not exist: $NUGET_PATH" >&2
    exit 1
}

# Verify paths don't contain characters that would break JSON
if [[ "$CODE_PATH" == *'"'* ]] || [[ "$NUGET_PATH" == *'"'* ]]; then
    echo "Error: Paths cannot contain double quotes" >&2
    exit 1
fi

# Generate config JSON
CONFIG=$(cat <<EOF
{
  "roslyn": {
    "command": "docker",
    "args": [
      "run", "-i", "--rm",
      "-v", "$CODE_PATH:$CODE_PATH",
      "-v", "$NUGET_PATH:$NUGET_PATH:ro",
      "ghcr.io/helgeu/roslyn-mcp-docker-img:latest"
    ]
  }
}
EOF
)

# Output
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$CONFIG" > "$OUTPUT_FILE"
    echo "Config written to: $OUTPUT_FILE" >&2
    echo "" >&2
    echo "Add to ~/.claude/settings.json under \"mcpServers\":" >&2
    echo "$CONFIG"
else
    echo "$CONFIG"
fi
