"""
Azure Functions 기반 MCP (Model Context Protocol) 서버
"""
import azure.functions as func
import json
import logging
from datetime import datetime
from typing import Dict, List, Any

# MCP 프로토콜 버전
MCP_PROTOCOL_VERSION = "2024-11-05"

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

# ============================================================
# MCP 서버 메타데이터
# ============================================================

MCP_SERVER_INFO = {
    "name": "Azure-MCP-Functions-Server",
    "version": "1.0.0",
    "protocolVersion": MCP_PROTOCOL_VERSION,
    "capabilities": {
        "tools": {},
        "resources": {},
        "prompts": {}
    }
}

# ============================================================
# MCP Tools 정의
# ============================================================

MCP_TOOLS = [
    {
        "name": "get_current_time",
        "description": "현재 서버 시간을 UTC 및 KST로 반환합니다",
        "inputSchema": {
            "type": "object",
            "properties": {
                "timezone": {
                    "type": "string",
                    "description": "타임존 (UTC 또는 KST)",
                    "enum": ["UTC", "KST"]
                }
            }
        }
    },
    {
        "name": "echo",
        "description": "입력받은 메시지를 그대로 반환합니다 (테스트용)",
        "inputSchema": {
            "type": "object",
            "properties": {
                "message": {
                    "type": "string",
                    "description": "반환할 메시지"
                }
            },
            "required": ["message"]
        }
    },
    {
        "name": "calculate",
        "description": "두 숫자의 사칙연산을 수행합니다",
        "inputSchema": {
            "type": "object",
            "properties": {
                "a": {
                    "type": "number",
                    "description": "첫 번째 숫자"
                },
                "b": {
                    "type": "number",
                    "description": "두 번째 숫자"
                },
                "operation": {
                    "type": "string",
                    "description": "연산 종류",
                    "enum": ["add", "subtract", "multiply", "divide"]
                }
            },
            "required": ["a", "b", "operation"]
        }
    }
]

# ============================================================
# Tool 실행 함수
# ============================================================

def execute_tool(tool_name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
    """MCP Tool 실행"""
    
    try:
        if tool_name == "get_current_time":
            timezone = arguments.get("timezone", "UTC")
            now = datetime.utcnow()
            
            if timezone == "KST":
                from datetime import timedelta
                now = now + timedelta(hours=9)
                return {
                    "content": [{
                        "type": "text",
                        "text": f"현재 KST 시간: {now.strftime('%Y-%m-%d %H:%M:%S')} KST"
                    }]
                }
            else:
                return {
                    "content": [{
                        "type": "text",
                        "text": f"현재 UTC 시간: {now.strftime('%Y-%m-%d %H:%M:%S')} UTC"
                    }]
                }
        
        elif tool_name == "echo":
            message = arguments.get("message", "")
            return {
                "content": [{
                    "type": "text",
                    "text": f"Echo: {message}"
                }]
            }
        
        elif tool_name == "calculate":
            a = float(arguments.get("a", 0))
            b = float(arguments.get("b", 0))
            operation = arguments.get("operation", "add")
            
            if operation == "add":
                result = a + b
            elif operation == "subtract":
                result = a - b
            elif operation == "multiply":
                result = a * b
            elif operation == "divide":
                if b == 0:
                    return {
                        "content": [{
                            "type": "text",
                            "text": "오류: 0으로 나눌 수 없습니다"
                        }],
                        "isError": True
                    }
                result = a / b
            else:
                return {
                    "content": [{
                        "type": "text",
                        "text": f"오류: 알 수 없는 연산 '{operation}'"
                    }],
                    "isError": True
                }
            
            return {
                "content": [{
                    "type": "text",
                    "text": f"{a} {operation} {b} = {result}"
                }]
            }
        
        else:
            return {
                "content": [{
                    "type": "text",
                    "text": f"오류: 알 수 없는 도구 '{tool_name}'"
                }],
                "isError": True
            }
    
    except Exception as e:
        logging.error(f"Tool execution error: {str(e)}")
        return {
            "content": [{
                "type": "text",
                "text": f"도구 실행 오류: {str(e)}"
            }],
            "isError": True
        }

# ============================================================
# HTTP Endpoints
# ============================================================

@app.route(route="mcp/health", methods=["GET"])
def health_check(req: func.HttpRequest) -> func.HttpResponse:
    """헬스 체크 엔드포인트"""
    logging.info("Health check requested")
    
    return func.HttpResponse(
        json.dumps({
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "server": MCP_SERVER_INFO["name"],
            "version": MCP_SERVER_INFO["version"]
        }),
        mimetype="application/json",
        status_code=200
    )

@app.route(route="mcp/info", methods=["GET"])
def server_info(req: func.HttpRequest) -> func.HttpResponse:
    """MCP 서버 정보 반환"""
    logging.info("Server info requested")
    
    return func.HttpResponse(
        json.dumps(MCP_SERVER_INFO),
        mimetype="application/json",
        status_code=200
    )

@app.route(route="mcp/tools", methods=["GET", "POST"])
def tools_endpoint(req: func.HttpRequest) -> func.HttpResponse:
    """MCP Tools 엔드포인트"""
    
    if req.method == "GET":
        # Tools 목록 반환
        logging.info("Listing tools")
        return func.HttpResponse(
            json.dumps({
                "tools": MCP_TOOLS
            }),
            mimetype="application/json",
            status_code=200
        )
    
    elif req.method == "POST":
        # Tool 실행
        try:
            req_body = req.get_json()
            tool_name = req_body.get("name")
            arguments = req_body.get("arguments", {})
            
            logging.info(f"Executing tool: {tool_name} with args: {arguments}")
            
            # Tool 실행
            result = execute_tool(tool_name, arguments)
            
            return func.HttpResponse(
                json.dumps(result),
                mimetype="application/json",
                status_code=200
            )
        
        except ValueError as e:
            logging.error(f"Invalid request body: {str(e)}")
            return func.HttpResponse(
                json.dumps({
                    "error": "Invalid JSON in request body",
                    "message": str(e)
                }),
                mimetype="application/json",
                status_code=400
            )
        except Exception as e:
            logging.error(f"Tool execution failed: {str(e)}")
            return func.HttpResponse(
                json.dumps({
                    "error": "Tool execution failed",
                    "message": str(e)
                }),
                mimetype="application/json",
                status_code=500
            )

@app.route(route="mcp/messages", methods=["POST"])
def messages_endpoint(req: func.HttpRequest) -> func.HttpResponse:
    """MCP Messages 엔드포인트 (SSE 스타일)"""
    try:
        req_body = req.get_json()
        method = req_body.get("method")
        params = req_body.get("params", {})
        
        logging.info(f"MCP Message: method={method}, params={params}")
        
        if method == "tools/list":
            response = {
                "jsonrpc": "2.0",
                "result": {
                    "tools": MCP_TOOLS
                }
            }
        elif method == "tools/call":
            tool_name = params.get("name")
            arguments = params.get("arguments", {})
            result = execute_tool(tool_name, arguments)
            response = {
                "jsonrpc": "2.0",
                "result": result
            }
        else:
            response = {
                "jsonrpc": "2.0",
                "error": {
                    "code": -32601,
                    "message": f"Method not found: {method}"
                }
            }
        
        return func.HttpResponse(
            json.dumps(response),
            mimetype="application/json",
            status_code=200
        )
    
    except Exception as e:
        logging.error(f"Messages endpoint error: {str(e)}")
        return func.HttpResponse(
            json.dumps({
                "jsonrpc": "2.0",
                "error": {
                    "code": -32603,
                    "message": f"Internal error: {str(e)}"
                }
            }),
            mimetype="application/json",
            status_code=500
        )
