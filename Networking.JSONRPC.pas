unit Networking.JSONRPC;

interface

uses System.Net;

const
   JSON_RPC_PARSE_ERROR = -32700;
   JSON_RPC_INVALID_REQUEST = -32600;
   JSON_RPC_METHOD_NOT_FOUND = -32601;
   JSON_RPC_INVALID_PARAMS = -32602;
   JSON_RPC_INTERNAL_ERROR = -32603;

type
   JSONRPC = static class

      class function CreateError(requestId: String; rpcErrorCode: Integer; errorMessage: String) : String;

      class function CreateSuccess(requestId: String; rpcResult: JSONVariant): String;

   end;

implementation

// CreateError
//
class function JSONRPC.CreateError(requestId: String; rpcErrorCode: Integer; errorMessage: String) : String;
begin
   Result := JSON.Stringify(record
      jsonrpc := '2.0';
      error := record
         code := rpcErrorCode;
         'message' := errorMessage;
      end;
      id := requestId;
   end);
end;

// CreateSuccess
//
class function JSONRPC.CreateSuccess(requestId: String; rpcResult: JSONVariant): String;
begin
   Result := JSON.Stringify(record
      jsonrpc := '2.0';
      'result' := rpcResult;
      id := requestId;
   end);
end;

