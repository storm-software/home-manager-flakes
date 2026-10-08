{ lib, pkgs, ... }:

{
  programs.mcp = {
    enable = true;
    servers = {
      github = {
        type = "http";
        url = "https://api.githubcopilot.com/mcp/";
        headers = {
          "X-MCP-Insiders" = "true";
        };
      };

      context7 = {
        url = "https://mcp.context7.com/mcp";
        headers.CONTEXT7_API_KEY = "$CONTEXT7_API_KEY";
      };

      # Store binaries rather than `npx`: resolving the npm package on every
      # launch overran Claude Code's 30s MCP connect timeout.
      playwright = {
        command = lib.getExe pkgs.playwright-mcp;
      };

      firecrawl = {
        command = lib.getExe pkgs.firecrawl-mcp;
        env.FIRECRAWL_API_KEY = "$FIRECRAWL_API_KEY";
      };

      deepwiki = {
        url = "https://mcp.deepwiki.com/mcp";
      };
    };
  };
}
