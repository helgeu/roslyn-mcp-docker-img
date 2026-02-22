# Roslyn MCP Docker Image

Docker image wrapping [RoslynMcp.Server](https://github.com/JoshuaRamirez/RoslynMcpServer) for C# code analysis and refactoring via MCP.

## Quick Start

```bash
git clone https://github.com/helgeu/roslyn-mcp-docker-img.git
cd roslyn-mcp-docker-img

# Bash (macOS/Linux)
./scripts/generate-config.sh ~/git

# PowerShell (Windows)
.\scripts\generate-config.ps1 -CodePath C:\git
```

This outputs the MCP config to add to your Claude settings.

## Setup Scripts

Available in both Bash and PowerShell.

### Generate Configuration

**Bash (macOS/Linux):**
```bash
./scripts/generate-config.sh <code-path> [options]

# Examples:
./scripts/generate-config.sh ~/git
./scripts/generate-config.sh ~/projects --nuget ~/.nuget/packages
./scripts/generate-config.sh ~/git --output mcp-config.json
```

**PowerShell (Windows):**
```powershell
.\scripts\generate-config.ps1 -CodePath <path> [-NuGetPath <path>] [-OutputFile <path>]

# Examples:
.\scripts\generate-config.ps1 -CodePath C:\git
.\scripts\generate-config.ps1 -CodePath D:\projects -NuGetPath C:\Users\me\.nuget\packages
.\scripts\generate-config.ps1 -CodePath C:\git -OutputFile mcp-config.json
```

### Verify Paths

**Bash (macOS/Linux):**
```bash
./scripts/verify-paths.sh <code-path> [nuget-path]
./scripts/verify-paths.sh ~/git
```

**PowerShell (Windows):**
```powershell
.\scripts\verify-paths.ps1 -CodePath <path> [-NuGetPath <path>]
.\scripts\verify-paths.ps1 -CodePath C:\git
```

Checks:
- Paths exist and are readable
- NuGet cache is populated
- Docker is available
- Image is pulled

## Supported Clients

This MCP server works with any client that supports the MCP protocol:

| Client | Tested | Notes |
|--------|--------|-------|
| Claude Code | Yes | Full support |
| Claude Desktop | Yes | Full support |
| GitHub Copilot (VS Code) | Yes | See setup below |
| Other MCP clients | - | Same JSON config format |

## Manual Configuration

The JSON configuration is the same for all MCP clients. File locations differ by client — refer to your client's documentation for where to place the config.

**Claude Code/Desktop:** `~/.claude/settings.json` (macOS/Linux) or `%APPDATA%\Claude\settings.json` (Windows)

**GitHub Copilot (VS Code):** Add to your VS Code MCP settings. Refer to [GitHub Copilot MCP documentation](https://docs.github.com/en/copilot/using-github-copilot/using-extensions-to-integrate-external-tools-with-copilot-chat) for setup details.

**macOS/Linux:**
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

**Windows:**
```json
{
  "mcpServers": {
    "roslyn": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-v", "C:\\git:C:\\git",
        "-v", "C:\\Users\\yourname\\.nuget\\packages:C:\\Users\\yourname\\.nuget\\packages:ro",
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
