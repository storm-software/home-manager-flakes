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

      playwright = {
        command = "npx";
        args = [
          "@playwright/mcp@latest"
        ];
      };

      firecrawl = {
        command = "npx";
        args = [
          "-y"
          "firecrawl-mcp"
        ];
        env.FIRECRAWL_API_KEY = "$FIRECRAWL_API_KEY";
      };

      deepwiki = {
        url = "https://mcp.deepwiki.com/mcp";
      };
    };
  };
}
