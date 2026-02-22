# Roslyn MCP Server Docker Image
# Wraps RoslynMcp.Server for C# code analysis and refactoring via MCP
# https://github.com/JoshuaRamirez/RoslynMcpServer

FROM mcr.microsoft.com/dotnet/sdk:9.0

LABEL org.opencontainers.image.title="Roslyn MCP Server"
LABEL org.opencontainers.image.description="Docker image wrapping RoslynMcp.Server for C# code analysis"
LABEL org.opencontainers.image.source="https://github.com/JoshuaRamirez/RoslynMcpServer"
LABEL org.opencontainers.image.licenses="MIT"

# Install RoslynMcp.Server as global dotnet tool
# Using specific version tag allows for reproducible builds
ARG ROSLYN_MCP_VERSION=latest
RUN if [ "$ROSLYN_MCP_VERSION" = "latest" ]; then \
        dotnet tool install -g RoslynMcp.Server; \
    else \
        dotnet tool install -g RoslynMcp.Server --version "$ROSLYN_MCP_VERSION"; \
    fi

# Add dotnet tools to PATH
ENV PATH="$PATH:/root/.dotnet/tools"

# MCP servers use stdio transport
# Tool binary name is lowercase: roslyn-mcp
ENTRYPOINT ["roslyn-mcp"]
