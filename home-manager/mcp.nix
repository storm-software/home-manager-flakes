{
  programs.mcp = {
    enable = true;
    servers = {
      "github/github-mcp-server" = {
        url = "https://api.githubcopilot.com/mcp/";
      };

      "upstash/context7" = {
        url = "https://mcp.context7.com/mcp";
        headers.CONTEXT7_API_KEY = "$CONTEXT7_API_KEY";
      };

      "io.github.github/github-mcp-server" = {
        url = "https://api.githubcopilot.com/mcp/";
      };

      "io.github.upstash/context7" = {
        command = "npx";
        args = [ "@upstash/context7-mcp@1.0.31" ];
        env.CONTEXT7_API_KEY = "$CONTEXT7_API_KEY";
      };

      "playwright" = {
        command = "npx";
        args = [
          "@playwright/mcp@latest"
        ];
      };

      "mcp-server-firecrawl" = {
        command = "npx";
        args = [ "-y" "firecrawl-mcp" ];
        env.FIRECRAWL_API_KEY = "$FIRECRAWL_API_KEY";
      };
    };
  };
}
