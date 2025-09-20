# DWScript-MCP

Sample MCP (Model Context Protocol) server for [DWScript][(https://github.com/EricGrange/DWScript)

This project is a basic MCP server exposing the following demo tools:
- returning current local time
- returning a raw METAR using [aviationweather.gov API](https://aviationweather.gov/data/api/#)

Tested only with [LM Studio](https://lmstudio.ai/) so far

Usage:
* place mcp-server.dws wherever you want in your website, and the .pas units either alongside it or in your .lib directory
* add an entry in mcp.json of LM Studio like 

```
{
  "mcpServers": {
    "dwscript-mcp-server": {
      "url": "http://your-server:port/path/to/mcp-server.dws"
    }
  }
}
```