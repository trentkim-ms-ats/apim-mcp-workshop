# 워크샵 노트북 완성 가이드

## 현재 상태

워크샵의 핵심 구성 요소가 모두 생성되었습니다:

### ✅ 완료된 항목

1. **프로젝트 구조** - 표준 폴더 구조 및 파일 생성
2. **Azure Functions MCP 서버** ([src/mcp-function/function_app.py](src/mcp-function/function_app.py))
   - MCP 프로토콜 구현
   - 3가지 도구: echo, get_current_time, calculate
   - Health check, Tools, Messages 엔드포인트
   - OpenAPI 스펙 포함

3. **APIM 정책 템플릿** ([apim-policies](apim-policies/))
   - base-policy.xml: 기본 정책 (CORS, Rate Limiting, 로깅)
   - jwt-validation-policy.xml: JWT 검증 및 OpenID Connect
   - transform-request-policy.xml: REST → MCP 요청 변환
   - transform-response-policy.xml: REST → MCP 응답 변환

4. **Bicep 인프라 템플릿** ([bicep/main.bicep](bicep/main.bicep))
   - APIM (Basicv2 SKU)
   - Azure Functions (Python 3.12)
   - Application Insights
   - Log Analytics
   - Storage Account
   - 완전한 통합 설정

5. **클라이언트 샘플** ([src/client](src/client/))
   - test-client.py: Python MCP 클라이언트
   - get-token.sh: Entra ID 토큰 발급 스크립트

6. **워크샵 노트북** ([workshop.ipynb](workshop.ipynb))
   - 기본 구조 및 초기 섹션 생성됨
   - Section 0 시작됨

## 노트북 완성하기

[workshop.ipynb](workshop.ipynb) 노트북을 VS Code에서 열고 다음 섹션들을 추가하세요:

### Section 1: Azure Functions로 MCP 서버 개발 🔧

```python
# 1.1 리소스 그룹 생성
!az group create --name {WORKSHOP_CONFIG['resource_group']} --location {WORKSHOP_CONFIG['location']}

# 1.2 Bicep으로 인프라 배포
!az deployment group create \
    --resource-group {WORKSHOP_CONFIG['resource_group']} \
    --template-file bicep/main.bicep \
    --parameters location={WORKSHOP_CONFIG['location']}

# 1.3 Functions 배포
!cd src/mcp-function && func azure functionapp publish {WORKSHOP_CONFIG['function_app_name']}

# 1.4 Functions 테스트
import requests
function_url = f"https://{WORKSHOP_CONFIG['function_app_name']}.azurewebsites.net/api/mcp"
response = requests.get(f"{function_url}/health")
print(response.json())
```

### Section 2: APIM으로 엔터프라이즈 게이트웨이 구성 🌐

```python
# 2.1 APIM API 생성
!az apim api create \
    --resource-group {WORKSHOP_CONFIG['resource_group']} \
    --service-name {WORKSHOP_CONFIG['apim_name']} \
    --api-id mcp-api \
    --path mcp \
    --display-name "MCP Server API"

# 2.2 Backend 설정
!az apim backend create \
    --resource-group {WORKSHOP_CONFIG['resource_group']} \
    --service-name {WORKSHOP_CONFIG['apim_name']} \
    --backend-id functions-backend \
    --url "https://{WORKSHOP_CONFIG['function_app_name']}.azurewebsites.net/api/mcp"

# 2.3 정책 적용
# base-policy.xml 업로드
```

### Section 3: 외부 REST API를 MCP 서버로 변환 🔄

```python
# 3.1 Weather API Backend 등록
# 3.2 transform-request-policy.xml 적용
# 3.3 transform-response-policy.xml 적용
# 3.4 테스트
```

### Section 4: OpenID Connect 기반 인증 🔐

```python
# 4.1 Entra ID 앱 등록
!az ad app create --display-name "MCP-API"
!az ad app create --display-name "MCP-Client"

# 4.2 Scope 설정
# 4.3 jwt-validation-policy.xml 적용
# 4.4 토큰 발급 및 테스트
!bash src/client/get-token.sh
```

### Section 5: External Entra ID 연계 (고급) 🌍

```python
# 5.1 Cross-tenant 설정
# 5.2 External user 초대
# 5.3 External user 토큰으로 테스트
```

### Section 6: 모니터링 및 최적화 📊

```python
# 6.1 Application Insights 쿼리
# 6.2 APIM Analytics
# 6.3 성능 최적화
```

### Section 7: 리소스 정리 🗑️

```python
# 리소스 그룹 삭제
!az group delete --name {WORKSHOP_CONFIG['resource_group']} --yes --no-wait
```

## 빠른 시작

1. **환경 설정**
```bash
cd /Users/hyungilkim/Documents/Labs/workshop/apim-mcp
pip install -r requirements.txt
cp .env.example .env
# .env 파일 편집
```

2. **Azure 로그인**
```bash
az login
az account set --subscription "<your-subscription-id>"
```

3. **노트북 실행**
```bash
jupyter notebook workshop.ipynb
# 또는 VS Code에서 직접 열기
```

4. **Functions 로컬 테스트** (선택)
```bash
cd src/mcp-function
func start
```

## 주요 엔드포인트

Functions (로컬):
- http://localhost:7071/api/mcp/health
- http://localhost:7071/api/mcp/info
- http://localhost:7071/api/mcp/tools
- http://localhost:7071/api/mcp/messages

Functions (Azure):
- https://{function-app}.azurewebsites.net/api/mcp/health
- https://{function-app}.azurewebsites.net/api/mcp/tools

APIM Gateway:
- https://{apim-name}.azure-api.net/mcp/health
- https://{apim-name}.azure-api.net/mcp/tools

## 참고 자료

### MCP 프로토콜
- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [MCP GitHub](https://github.com/modelcontextprotocol)

### Azure 문서
- [Azure Functions Python](https://learn.microsoft.com/azure/azure-functions/functions-reference-python)
- [APIM Policies](https://learn.microsoft.com/azure/api-management/api-management-policies)
- [Entra ID OAuth 2.0](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-client-creds-grant-flow)

### 예제 코드
- [Azure-Samples/AI-Gateway](https://github.com/Azure-Samples/AI-Gateway)
- [azure-ai-foundry/mcp-foundry](https://github.com/azure-ai-foundry/mcp-foundry)

## 트러블슈팅

### Functions 배포 실패
```bash
# Functions Core Tools 버전 확인
func --version

# 로그 확인
az functionapp log tail --name {function-app-name} --resource-group {rg-name}
```

### APIM 정책 오류
```bash
# APIM 진단 로그 활성화
az apim diagnostic create --service-name {apim-name} --resource-group {rg-name}

# Application Insights에서 로그 확인
```

### JWT 검증 실패
- Audience (aud) 클레임 확인
- Issuer (iss) 클레임 확인
- Scope (scp) 클레임 확인
- 토큰 만료 시간 확인

## 다음 단계

1. **노트북 완성**: 위의 섹션들을 노트북에 추가
2. **실습 진행**: 각 섹션을 순서대로 실행
3. **커스터마이징**: 자신만의 MCP 도구 추가
4. **프로덕션 준비**:
   - Private Endpoint 설정
   - VNet 통합
   - Key Vault 통합
   - CI/CD 파이프라인 구축

## 기여

이슈 및 개선 제안을 환영합니다!

## 라이선스

MIT License
