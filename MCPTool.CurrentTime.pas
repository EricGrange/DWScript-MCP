(*
  MCP Tool: Current Time
  
  This unit implements a tool that returns the current local date and time.

  Sample response:

  {
    "content": [
      {
        "type": "text",
        "text": "Current local time: 2025-09-23 10:38:00 (Local timezone)"
      }
    ],
    "isError": false
  }

*)
unit MCPTool.CurrentTime;

uses Networking.MCP;

type
   TCurrentTimeTool = class (TMCPTool)
      class function Description : String; override;
      begin
         Result := 'Get the current local date and time';
      end;
      class function InputSchema : JSONVariant; override;
      begin
         Result := JSON.Serialize(
            record
               'type' := 'object';
               properties := JSON.NewObject;
            end
         );
      end;
      class function Call(params : JSONVariant) : JSONVariant; override;
      begin
         Result := JSON.Serialize(record
            content := [
               record
                  'type' := 'text';
                  text := 'Current local time: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' (Local timezone)';
               end
            ];
            isError := False;
         end);
      end;
   end;
