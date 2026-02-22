# Roslyn MCP Docker Image

Docker image wrapping [RoslynMcp.Server](https://github.com/JoshuaRamirez/RoslynMcpServer) for C# code analysis and refactoring via MCP.

## Quick Start

```bash
docker pull ghcr.io/helgeu/roslyn-mcp-docker-img:latest

docker run -i --rm \
  -v "/path/to/your/code:/path/to/your/code" \
  -v "$HOME/.nuget/packages:/root/.nuget/packages:ro" \
  ghcr.io/helgeu/roslyn-mcp-docker-img:latest
```

**Important**: Mount your code at the **same path** inside the container so Roslyn returns usable file locations.

## Available Tools (41 total)

- **Refactoring (19)**: rename-symbol, extract-method, extract-variable, move-type-to-file, convert-to-static, etc.
- **Navigation (5)**: find-references, go-to-definition, search-symbols, get-symbol-info, list-members
- **Analysis (6)**: get-diagnostics, get-complexity, analyze-dependencies, etc.
- **Generation (4)**: generate-constructor, generate-interface, etc.
- **Conversion (7)**: convert-to-expression-body, convert-to-block-body, etc.

## Usage with Claude Code / Claude Desktop

Add to your MCP configuration (`~/.claude/settings.json`):

```json
{
  "mcpServers": {
    "roslyn": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-v", "/Users/yourname/git:/Users/yourname/git",
        "-v", "/Users/yourname/.nuget/packages:/root/.nuget/packages:ro",
        "ghcr.io/helgeu/roslyn-mcp-docker-img:latest"
      ]
    }
  }
}
```

## Path Mapping

Docker paths must match host paths for Roslyn to return usable file locations:
- Host: `/Users/yourname/git/myproject/Foo.cs`
- Container: `/Users/yourname/git/myproject/Foo.cs`

Achieved with: `-v "/Users/yourname/git:/Users/yourname/git"`

## Volume Mounts

| Host Path | Container Path | Access | Purpose |
|-----------|----------------|--------|---------|
| Your code directory | Same path | rw | Source code, solutions |
| `~/.nuget/packages` | `/root/.nuget/packages` | ro | NuGet package cache |

NuGet cache is read-only — Roslyn only reads package DLLs for type info.

## Building Locally

```bash
# Build with latest version
docker build -t roslyn-mcp .

# Build with specific version
docker build --build-arg ROSLYN_MCP_VERSION=1.0.0 -t roslyn-mcp .

# Using docker-compose
docker-compose build
```

## Automated Updates

This repository uses GitHub Actions to:
- Build and push images on every commit to `main`
- Check daily for new upstream releases on NuGet
- Automatically tag and build new versions when upstream updates

## Managing Workflows with GitHub CLI

```bash
# List workflows and their status
gh workflow list

# List recent workflow runs
gh run list --limit 5

# Manually trigger a build
gh workflow run "Build and Push Docker Image"

# Trigger build with specific version
gh workflow run "Build and Push Docker Image" -f roslyn_mcp_version=1.0.0

# Watch a running workflow
gh run watch

# View logs from the latest run
gh run view --log

# Check upstream NuGet package version
curl -s "https://api.nuget.org/v3-flatcontainer/roslynmcp.server/index.json" | jq -r '.versions | last'
```

## Available Tags

- `latest` - Latest build from main branch
- `x.y.z` - Specific upstream version
- `main` - Latest commit on main branch

## License

This Docker wrapper is provided under MIT license. The underlying RoslynMcp.Server is maintained by Joshua Ramirez under their license terms.
