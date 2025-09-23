unit Networking.MCP;

interface

uses System.Net, Networking.JSONRPC;

type
   TMCPTool = static class
      class function Description : String; virtual; abstract;
      class function InputSchema : JSONVariant; virtual; abstract;
      class function Call(params : JSONVariant) : JSONVariant; virtual; abstract;
      
      class function CreateError(const message : String) : JSONVariant;
   end;
   TMCPToolClass = class of TMCPTool;

   MCPServer = static class
   private
      class var Tools : array [String] of TMCPToolClass;

   public
      class var ServerName : String := 'DWScript MCP Server';
   
      class procedure RegisterTool(const name : String; const tool : TMCPToolClass);

      class function ProcessInitialize(requestId : String; params : JSONVariant) : String;
      class function ProcessListTools(requestId : String; params : JSONVariant) : String;
      class function ProcessCallTool(requestId : String; params : JSONVariant) : String;

      class function ProcessMCPRequest(sessionId, requestBody: String): String;

      class procedure ProcessWebRequest;

   end;

implementation

// CreateError
//
class function TMCPTool.CreateError(const message : String) : JSONVariant;
begin
   Result := JSON.Serialize(record
      content := [
         record
            'type' := 'text';
            text := 'Error: ' + message;
         end
      ];
      isError := True;
   end);
end;

// RegisterTool
//
class procedure MCPServer.RegisterTool(const name : String; const tool: TMCPToolClass);
begin
   Tools[name] := tool;
end;

// ProcessInitialize
//
class function MCPServer.ProcessInitialize(requestId: String; params: JSONVariant): String;
begin
   Result := JSONRPC.CreateSuccess(
      requestId,
      JSON.Serialize(record
         protocolVersion := '2024-11-05';
         serverInfo := record
            name := ServerName;
            version := '1.0.0';
         end;
         capabilities := record
            tools := JSON.NewObject;
         end;
      end)
   );
end;

// ProcessListTools
//
class function MCPServer.ProcessListTools(requestId: String; params: JSONVariant): String;
begin
   var list : array of JSONVariant;
   for var name in Tools.Keys do begin
      var tool := Tools[name];
      list.Add(JSON.Serialize(record
         name := name;
         description := tool.Description;
         inputSchema := tool.InputSchema;
      end));
   end;

   Result := JSONRPC.CreateSuccess(
      requestId,
      JSON.Serialize(record
         tools := list
      end)
   );
end;

class function MCPServer.ProcessCallTool(requestId: String; params: JSONVariant): String;
begin
   var toolName := params.name;
   if toolName = '' then
      exit JSONRPC.CreateError(requestId, JSON_RPC_INVALID_PARAMS, 'Missing tool name parameter');

   var tool := Tools[toolName];
   if tool = nil then
      exit JSONRPC.CreateError(requestId, JSON_RPC_METHOD_NOT_FOUND, 'Unknown tool: ' + toolName);

   Result := JSONRPC.CreateSuccess(
      requestId,
      tool.Call(params.arguments)
   );
end;

// ProcessMCPRequest
//
class function MCPServer.ProcessMCPRequest(sessionId: String; requestBody: String): String;
var
   request : JSONVariant;
begin
   try
      request := JSON.Parse(requestBody);
   except
      on E: Exception do
         exit JSONRPC.CreateError('', JSON_RPC_PARSE_ERROR, 'Parse error: ' + E.Message);
   end;

   var requestId := request.id;

   try
      if request.jsonrpc <> '2.0' then
         exit JSONRPC.CreateError(requestId, JSON_RPC_INVALID_REQUEST, 'Invalid Request');

      var mcpMethod := request['method'];
      if mcpMethod = '' then
         exit JSONRPC.CreateError(requestId, JSON_RPC_INVALID_REQUEST, 'Missing method parameter');

      var params := request['params'] ?? JSON.NewObject;

      // Route to appropriate handler
      case mcpMethod of
         'initialize': Result := ProcessInitialize(requestId, params);
         'tools/list': Result := ProcessListTools(requestId, params);
         'tools/call': Result := ProcessCallTool(requestId, params);
      else
         Result := JSONRPC.CreateError(requestId, JSON_RPC_METHOD_NOT_FOUND, 'Method not found: ' + mcpMethod);
      end;

   except
      on E: Exception do
         Result := JSONRPC.CreateError(requestId, JSON_RPC_INTERNAL_ERROR, 'Internal error: ' + E.Message);
   end;
end;

// ProcessWebRequest
//
class procedure MCPServer.ProcessWebRequest;
begin
   WebResponse.Header['Access-Control-Allow-Origin'] := '*';
   
   var sessionId := WebRequest.Header['Mcp-Session-Id'];
   
   case WebRequest.Method of
      'OPTIONS' : begin // Handle preflight OPTIONS
         WebResponse.Header['Access-Control-Allow-Methods'] := 'GET, POST, OPTIONS';
         WebResponse.Header['Access-Control-Allow-Headers'] := 'Content-Type';
         WebResponse.SetStatusPlainText(200, '');
      end;

      'GET' : begin
         if 'text/event-stream' in WebRequest.Header['Accept'] then
            WebResponse.SetContentEventStream(sessionId)
         else begin
            WebResponse.StatusCode := 400;
            WebResponse.ContentType := 'application/json';
            WebResponse.ContentData := JSONRPC.CreateError(sessionId, JSON_RPC_INVALID_REQUEST, 'GET can only be used to establish an event-stream.');
         end;
      end;
   
      'POST' : begin
         try
            var requestBody := WebRequest.ContentData;
   
            if requestBody = '' then begin
               WebResponse.SetStatusJSON(400, JSONRPC.CreateError(sessionId, JSON_RPC_INVALID_REQUEST, 'Empty request body'));
               exit;
            end;
   
            // Process MCP request
            if sessionId = '' then begin
               WebResponse.SetStatusJSON(200, ProcessMCPRequest(sessionId, requestBody));
            end else begin
               WebResponse.SetStatusPlainText(202, 'Accepted');
               WebServerSentEvents.PostRaw(sessionId, ProcessMCPRequest(sessionId, requestBody));
            end;
   
         except
            on E: Exception do begin
               WebResponse.SetStatusJSON(500, JSONRPC.CreateError(sessionId, JSON_RPC_INTERNAL_ERROR, 'Server error: ' + E.Message));
            end;
         end;
      end;
   
   else
      WebResponse.SetStatusJSON(405, JSONRPC.CreateError(sessionId, JSON_RPC_INVALID_REQUEST, 'Method not allowed. Use GET/POST.'));
   end;

end;

