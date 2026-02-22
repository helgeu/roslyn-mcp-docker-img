# Roslyn MCP Server Docker Image
# Wraps RoslynMcp.Server for C# code analysis and refactoring via MCP
# Built from fork with Roslyn 5.0.0 for C# 13 support

FROM mcr.microsoft.com/dotnet/sdk:9.0

LABEL org.opencontainers.image.title="Roslyn MCP Server"
LABEL org.opencontainers.image.description="Docker image wrapping RoslynMcp.Server for C# code analysis"
LABEL org.opencontainers.image.source="https://github.com/helgeu/RoslynMcpServer"
LABEL org.opencontainers.image.licenses="MIT"

# Clone fork with Roslyn 5.0.0 (C# 13 support) and build from source
ARG ROSLYN_MCP_REPO=https://github.com/helgeu/RoslynMcpServer.git
ARG ROSLYN_MCP_REF=master
ARG CACHEBUST=1
RUN git clone --depth 1 --branch "$ROSLYN_MCP_REF" "$ROSLYN_MCP_REPO" /src && \
    dotnet pack /src/src/RoslynMcp.Server/RoslynMcp.Server.csproj -c Release -o /packages && \
    dotnet tool install -g RoslynMcp.Server --add-source /packages && \
    rm -rf /src /packages

# Add dotnet tools to PATH
ENV PATH="$PATH:/root/.dotnet/tools"

# MCP servers use stdio transport
# Tool binary name is lowercase: roslyn-mcp
ENTRYPOINT ["roslyn-mcp"]
