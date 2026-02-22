# Roslyn MCP Docker Image

Docker image wrapping [RoslynMcp.Server](https://github.com/JoshuaRamirez/RoslynMcpServer) for C# code analysis and refactoring via MCP.

## Quick Start

```bash
# Generate config for your paths
git clone https://github.com/helgeu/roslyn-mcp-docker-img.git
cd roslyn-mcp-docker-img
./scripts/generate-config.sh ~/git
```

This outputs the MCP config to add to `~/.claude/settings.json`.

## Setup Scripts

### Generate Configuration

```bash
./scripts/generate-config.sh <code-path> [options]

# Examples:
./scripts/generate-config.sh ~/git
./scripts/generate-config.sh ~/projects --nuget ~/.nuget/packages
./scripts/generate-config.sh ~/git --output mcp-config.json
```

### Verify Paths

```bash
./scripts/verify-paths.sh <code-path> [nuget-path]

# Example:
./scripts/verify-paths.sh ~/git
```

Checks:
- Paths exist and are readable
- NuGet cache is populated
- Docker is available
- Image is pulled

## Manual Configuration

Add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "roslyn": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-v", "/Users/yourname/git:/Users/yourname/git",
        "-v", "/Users/yourname/.nuget/packages:/Users/yourname/.nuget/packages:ro",
        "ghcr.io/helgeu/roslyn-mcp-docker-img:latest"
      ]
    }
  }
}
```

## Path Mapping (Critical)

**Both paths must be identical on host and container.** Roslyn reads `.csproj` files which contain absolute paths to NuGet packages. If paths don't match, Roslyn can't resolve types.

| Host Path | Container Path | Why |
|-----------|----------------|-----|
| `/Users/you/git` | `/Users/you/git` | Source files returned with correct paths |
| `/Users/you/.nuget/packages` | `/Users/you/.nuget/packages` | `.csproj` references packages at host path |

**Wrong:**
```bash
-v "$HOME/.nuget/packages:/root/.nuget/packages:ro"  # Different paths!
```

**Correct:**
```bash
-v "$HOME/.nuget/packages:$HOME/.nuget/packages:ro"  # Same path
```

## Available Tools (41 total)

- **Refactoring (19)**: rename_symbol, extract_method, extract_variable, move_type_to_file, etc.
- **Navigation (5)**: find_references, go_to_definition, search_symbols, get_symbol_info, get_type_hierarchy
- **Analysis (6)**: get_diagnostics, get_code_metrics, analyze_control_flow, analyze_data_flow, etc.
- **Generation (4)**: generate_constructor, generate_equals_hashcode, generate_overrides, generate_tostring
- **Conversion (7)**: convert_expression_body, convert_foreach_linq, convert_property, convert_to_async, etc.

## Building Locally

```bash
# Build with latest version
docker build -t roslyn-mcp .

# Build with specific version
docker build --build-arg ROSLYN_MCP_VERSION=1.0.0 -t roslyn-mcp .
```

## Testing

```bash
# Test MCP handshake
cat <<'EOF' | docker run -i --rm ghcr.io/helgeu/roslyn-mcp-docker-img:latest
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
EOF
```

## Automated Updates

GitHub Actions:
- Builds and pushes to ghcr.io on every commit to `main`
- Checks NuGet daily for upstream releases
- Auto-tags new versions

## GitHub CLI Commands

```bash
gh workflow list                                    # List workflows
gh run list --limit 5                               # Recent runs
gh workflow run "Build and Push Docker Image"      # Trigger build
gh run watch                                        # Watch running workflow

# Check upstream version
curl -s "https://api.nuget.org/v3-flatcontainer/roslynmcp.server/index.json" | jq -r '.versions | last'
```

## Available Tags

- `latest` - Latest build from main branch
- `x.y.z` - Specific upstream version (e.g., `0.3.1`)
- `main` - Latest commit on main branch

## License

MIT. The underlying RoslynMcp.Server is maintained by Joshua Ramirez.
