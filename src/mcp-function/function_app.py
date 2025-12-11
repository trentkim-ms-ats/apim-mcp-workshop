"""
Azure Functions 기반 MCP (Model Context Protocol) 서버

이 모듈은 Azure Functions를 사용하여 MCP 프로토콜을 구현한 서버입니다.
MCP는 AI 에이전트가 외부 도구와 상호작용할 수 있도록 하는 표준 프로토콜입니다.

주요 기능:
- MCP 2024-11-05 프로토콜 준수
- HTTP 기반 REST API 제공
- 3가지 기본 도구 (echo, get_current_time, calculate)
- JSON-RPC 스타일 메시지 처리
"""

import azure.functions as func
import json
import logging
from datetime import datetime
from typing import Dict, List, Any

# ============================================================
# 상수 및 설정
# ============================================================

# MCP 프로토콜 버전 (2024년 11월 5일 스펙)
MCP_PROTOCOL_VERSION = "2024-11-05"

# Azure Functions 앱 초기화
# - http_auth_level: FUNCTION 레벨 인증 요구 (URL에 코드 필요)
app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

# ============================================================
# MCP 서버 메타데이터
# ============================================================

MCP_SERVER_INFO = {
    "name": "Azure-MCP-Functions-Server",
    "version": "1.0.0",
    "protocolVersion": MCP_PROTOCOL_VERSION,
    "capabilities": {
        # 서버가 제공하는 기능들을 선언
        "tools": {},      # 도구 실행 지원
        "resources": {},  # 리소스 접근 지원 (미구현)
        "prompts": {}     # 프롬프트 템플릿 지원 (미구현)
    }
}

# ============================================================
# MCP Tools 정의
# ============================================================

MCP_TOOLS = [
    {
        # Tool 1: 현재 시간 조회
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
        # Tool 2: 에코 테스트
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
            "required": ["message"]  # 필수 파라미터
        }
    },
    {
        # Tool 3: 계산기
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
            "required": ["a", "b", "operation"]  # 모든 파라미터 필수
        }
    }
]

# ============================================================
# Tool 실행 로직
# ============================================================

def execute_tool(tool_name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
    """
    MCP Tool 실행 함수

    Args:
        tool_name: 실행할 도구 이름
        arguments: 도구에 전달할 인자들

    Returns:
        MCP 표준 응답 형식의 딕셔너리
        {
            "content": [{"type": "text", "text": "결과"}],
            "isError": False  # 선택적, 에러 시에만
        }
    """

    try:
        # Tool 1: 현재 시간 반환
        if tool_name == "get_current_time":
            timezone = arguments.get("timezone", "UTC")
            now = datetime.utcnow()

            if timezone == "KST":
                # KST는 UTC+9
                from datetime import timedelta
                now = now + timedelta(hours=9)
                return {
                    "content": [{
                        "type": "text",
                        "text": f"현재 KST 시간: {now.strftime('%Y-%m-%d %H:%M:%S')} KST"
                    }]
                }
            else:
                # 기본값: UTC
                return {
                    "content": [{
                        "type": "text",
                        "text": f"현재 UTC 시간: {now.strftime('%Y-%m-%d %H:%M:%S')} UTC"
                    }]
                }

        # Tool 2: 에코 (테스트용)
        elif tool_name == "echo":
            message = arguments.get("message", "")
            return {
                "content": [{
                    "type": "text",
                    "text": f"Echo: {message}"
                }]
            }

        # Tool 3: 계산기
        elif tool_name == "calculate":
            # 파라미터 추출 및 형변환
            a = float(arguments.get("a", 0))
            b = float(arguments.get("b", 0))
            operation = arguments.get("operation", "add")

            # 연산 수행
            if operation == "add":
                result = a + b
            elif operation == "subtract":
                result = a - b
            elif operation == "multiply":
                result = a * b
            elif operation == "divide":
                # 0으로 나누기 체크
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
                # 알 수 없는 연산
                return {
                    "content": [{
                        "type": "text",
                        "text": f"오류: 알 수 없는 연산 '{operation}'"
                    }],
                    "isError": True
                }

            # 성공 응답
            return {
                "content": [{
                    "type": "text",
                    "text": f"{a} {operation} {b} = {result}"
                }]
            }

        # 알 수 없는 도구
        else:
            return {
                "content": [{
                    "type": "text",
                    "text": f"오류: 알 수 없는 도구 '{tool_name}'"
                }],
                "isError": True
            }

    except Exception as e:
        # 예외 처리 및 로깅
        logging.error(f"Tool execution error: {str(e)}")
        return {
            "content": [{
                "type": "text",
                "text": f"도구 실행 오류: {str(e)}"
            }],
            "isError": True
        }

# ============================================================
# HTTP Endpoints (Azure Functions Routes)
# ============================================================

@app.route(route="mcp/health", methods=["GET"])
def health_check(req: func.HttpRequest) -> func.HttpResponse:
    """
    헬스 체크 엔드포인트

    용도: 서버 상태 확인, 로드 밸런서 health probe
    경로: GET /api/mcp/health
    """
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
    """
    MCP 서버 정보 반환

    용도: 클라이언트가 서버 능력 파악
    경로: GET /api/mcp/info
    응답: 서버 메타데이터 및 지원 기능
    """
    logging.info("Server info requested")

    return func.HttpResponse(
        json.dumps(MCP_SERVER_INFO),
        mimetype="application/json",
        status_code=200
    )

@app.route(route="mcp/tools", methods=["GET", "POST"])
def tools_endpoint(req: func.HttpRequest) -> func.HttpResponse:
    """
    MCP Tools 엔드포인트

    GET: 사용 가능한 도구 목록 반환
    POST: 특정 도구 실행

    경로: /api/mcp/tools
    """

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
            # 요청 본문 파싱
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
            # JSON 파싱 실패
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
            # 기타 예외
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
    """
    MCP Messages 엔드포인트 (JSON-RPC 스타일)

    용도: JSON-RPC 2.0 형식의 MCP 메시지 처리
    경로: POST /api/mcp/messages

    요청 형식:
    {
        "jsonrpc": "2.0",
        "method": "tools/list" | "tools/call",
        "params": { ... }
    }

    응답 형식:
    {
        "jsonrpc": "2.0",
        "result": { ... }
    }
    """
    try:
        # 요청 본문 파싱
        req_body = req.get_json()
        method = req_body.get("method")
        params = req_body.get("params", {})

        logging.info(f"MCP Message: method={method}, params={params}")

        # 메서드별 처리
        if method == "tools/list":
            # 도구 목록 반환
            response = {
                "jsonrpc": "2.0",
                "result": {
                    "tools": MCP_TOOLS
                }
            }
        elif method == "tools/call":
            # 도구 실행
            tool_name = params.get("name")
            arguments = params.get("arguments", {})
            result = execute_tool(tool_name, arguments)
            response = {
                "jsonrpc": "2.0",
                "result": result
            }
        else:
            # 지원하지 않는 메서드
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
        # 내부 오류
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
