# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker image for running [RoslynMcp.Server](https://github.com/JoshuaRamirez/RoslynMcpServer) — a .NET tool providing 41 Roslyn-powered C# code analysis and refactoring tools via MCP (Model Context Protocol).

## Build Commands

```bash
# Build Docker image
docker build -t roslyn-mcp .

# Build with specific version
docker build --build-arg ROSLYN_MCP_VERSION=1.0.0 -t roslyn-mcp .

# Test MCP initialize response
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{}}}' | \
  docker run -i --rm roslyn-mcp

# Check upstream NuGet version
curl -s "https://api.nuget.org/v3-flatcontainer/roslynmcp.server/index.json" | jq -r '.versions | last'
```

## Architecture

```
Claude Code → stdio (JSON-RPC) → Docker Container → RoslynMcp.Server (.NET 9.0 SDK)
```

Key design decisions:
- **Path mapping**: Both code and NuGet paths must be identical on host and container (`-v /path:/path`)
- **NuGet path critical**: `.csproj` files reference packages at host paths, so NuGet must be mounted at same path (not `/root/.nuget/packages`)
- **Per-call solution**: Each MCP tool call includes `solutionPath` parameter; no persistent state
- **Multi-arch**: Builds for `linux/amd64,linux/arm64`

## Helper Scripts

```bash
# Generate MCP config with correct paths
./scripts/generate-config.sh ~/git

# Verify paths are set up correctly
./scripts/verify-paths.sh ~/git
```

## CI/CD

- `.github/workflows/build-and-push.yml` — Builds and pushes to ghcr.io on push/tag, checks NuGet daily for updates
- `.github/workflows/test.yml` — Validates Docker build and MCP response on PRs
