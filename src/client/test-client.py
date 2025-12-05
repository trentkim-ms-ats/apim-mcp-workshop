"""
MCP 클라이언트 테스트 스크립트
"""
import os
import requests
import json
from typing import Dict, Any, Optional

class McpClient:
    """MCP 서버 클라이언트"""
    
    def __init__(self, base_url: str, access_token: Optional[str] = None):
        """
        Args:
            base_url: APIM Gateway URL (예: https://apim-mcp-lab.azure-api.net/mcp)
            access_token: JWT Bearer 토큰 (선택)
        """
        self.base_url = base_url.rstrip('/')
        self.access_token = access_token
        self.session = requests.Session()
        
        if access_token:
            self.session.headers.update({
                'Authorization': f'Bearer {access_token}'
            })
    
    def health_check(self) -> Dict[str, Any]:
        """서버 상태 확인"""
        response = self.session.get(f'{self.base_url}/health')
        response.raise_for_status()
        return response.json()
    
    def get_server_info(self) -> Dict[str, Any]:
        """서버 정보 조회"""
        response = self.session.get(f'{self.base_url}/info')
        response.raise_for_status()
        return response.json()
    
    def list_tools(self) -> Dict[str, Any]:
        """사용 가능한 도구 목록 조회"""
        response = self.session.get(f'{self.base_url}/tools')
        response.raise_for_status()
        return response.json()
    
    def call_tool(self, tool_name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """도구 실행
        
        Args:
            tool_name: 도구 이름
            arguments: 도구 인자
        
        Returns:
            도구 실행 결과
        """
        payload = {
            'name': tool_name,
            'arguments': arguments
        }
        
        response = self.session.post(
            f'{self.base_url}/tools',
            json=payload,
            headers={'Content-Type': 'application/json'}
        )
        response.raise_for_status()
        return response.json()
    
    def send_message(self, method: str, params: Dict[str, Any]) -> Dict[str, Any]:
        """MCP 메시지 전송 (JSON-RPC 스타일)
        
        Args:
            method: MCP 메서드 (예: tools/list, tools/call)
            params: 메서드 파라미터
        
        Returns:
            MCP 응답
        """
        payload = {
            'jsonrpc': '2.0',
            'method': method,
            'params': params
        }
        
        response = self.session.post(
            f'{self.base_url}/messages',
            json=payload,
            headers={'Content-Type': 'application/json'}
        )
        response.raise_for_status()
        return response.json()


def main():
    """테스트 메인 함수"""
    
    # 환경 변수에서 설정 로드
    apim_url = os.getenv('APIM_GATEWAY_URL', 'https://apim-mcp-lab.azure-api.net/mcp')
    access_token = os.getenv('MCP_ACCESS_TOKEN')
    
    print("🚀 MCP 클라이언트 테스트 시작")
    print(f"   서버: {apim_url}")
    print(f"   인증: {'있음' if access_token else '없음'}")
    print()
    
    # 클라이언트 생성
    client = McpClient(apim_url, access_token)
    
    try:
        # 1. Health Check
        print("1️⃣ Health Check")
        health = client.health_check()
        print(f"   상태: {health.get('status')}")
        print(f"   서버: {health.get('server')}")
        print()
        
        # 2. Server Info
        print("2️⃣ Server Information")
        info = client.get_server_info()
        print(f"   이름: {info.get('name')}")
        print(f"   버전: {info.get('version')}")
        print(f"   프로토콜 버전: {info.get('protocolVersion')}")
        print()
        
        # 3. List Tools
        print("3️⃣ Available Tools")
        tools_response = client.list_tools()
        tools = tools_response.get('tools', [])
        print(f"   총 {len(tools)}개 도구:")
        for tool in tools:
            print(f"   - {tool['name']}: {tool['description']}")
        print()
        
        # 4. Call Tool: Echo
        print("4️⃣ Tool Call: Echo")
        result = client.call_tool('echo', {'message': 'Hello from MCP Client!'})
        print(f"   결과: {result['content'][0]['text']}")
        print()
        
        # 5. Call Tool: Get Current Time
        print("5️⃣ Tool Call: Get Current Time (KST)")
        result = client.call_tool('get_current_time', {'timezone': 'KST'})
        print(f"   결과: {result['content'][0]['text']}")
        print()
        
        # 6. Call Tool: Calculate
        print("6️⃣ Tool Call: Calculate")
        result = client.call_tool('calculate', {
            'a': 15,
            'b': 7,
            'operation': 'multiply'
        })
        print(f"   결과: {result['content'][0]['text']}")
        print()
        
        # 7. MCP Message: tools/list
        print("7️⃣ MCP Message: tools/list")
        response = client.send_message('tools/list', {})
        tools_count = len(response.get('result', {}).get('tools', []))
        print(f"   결과: {tools_count}개 도구")
        print()
        
        # 8. MCP Message: tools/call
        print("8️⃣ MCP Message: tools/call")
        response = client.send_message('tools/call', {
            'name': 'echo',
            'arguments': {'message': 'MCP Message Test'}
        })
        print(f"   결과: {response.get('result', {}).get('content', [{}])[0].get('text')}")
        print()
        
        print("✅ 모든 테스트 성공!")
        
    except requests.exceptions.HTTPError as e:
        print(f"❌ HTTP 오류: {e}")
        print(f"   응답: {e.response.text}")
    except Exception as e:
        print(f"❌ 오류 발생: {e}")


if __name__ == '__main__':
    main()
