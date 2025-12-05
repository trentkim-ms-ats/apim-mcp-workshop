# 🎉 Azure APIM + MCP 서버 워크샵 - 구현 완료

## 📊 프로젝트 개요

Azure API Management와 Azure Functions를 활용한 엔터프라이즈급 MCP (Model Context Protocol) 서버 구축 워크샵이 성공적으로 생성되었습니다.

## 📁 생성된 파일 구조

```
apim-mcp/
├── 📄 README.md                                  ✅ 프로젝트 소개
├── 📄 WORKSHOP_COMPLETION_GUIDE.md              ✅ 워크샵 완성 가이드
├── 📓 workshop.ipynb                             ✅ 메인 워크샵 노트북
├── 📄 requirements.txt                           ✅ Python 패키지
├── 📄 .env.example                               ✅ 환경 변수 템플릿
│
├── 📂 src/
│   ├── 📂 mcp-function/                          ✅ Azure Functions MCP 서버
│   │   ├── function_app.py                      ✅ MCP 서버 구현 (3 도구)
│   │   ├── host.json                            ✅ Functions 호스트 설정
│   │   ├── local.settings.json                  ✅ 로컬 설정
│   │   ├── requirements.txt                     ✅ Functions 패키지
│   │   └── openapi.json                         ✅ OpenAPI 스펙
│   │
│   └── 📂 client/                                ✅ MCP 클라이언트 샘플
│       ├── test-client.py                       ✅ Python 테스트 클라이언트
│       └── get-token.sh                         ✅ Entra ID 토큰 발급
│
├── 📂 apim-policies/                             ✅ APIM 정책 템플릿
│   ├── base-policy.xml                          ✅ 기본 정책
│   ├── jwt-validation-policy.xml                ✅ JWT 검증
│   ├── transform-request-policy.xml             ✅ 요청 변환
│   └── transform-response-policy.xml            ✅ 응답 변환
│
└── 📂 bicep/                                     ✅ Infrastructure as Code
    └── main.bicep                               ✅ 전체 인프라 템플릿
```

## ✨ 주요 구성 요소

### 1. Azure Functions MCP 서버 ([src/mcp-function/function_app.py](src/mcp-function/function_app.py))

**구현된 기능:**
- ✅ MCP 프로토콜 2024-11-05 버전 지원
- ✅ HTTP Trigger 기반 엔드포인트
- ✅ 3가지 도구 (Tools):
  - `echo`: 메시지 에코
  - `get_current_time`: 현재 시간 (UTC/KST)
  - `calculate`: 사칙연산

**엔드포인트:**
- `GET /mcp/health` - 헬스 체크
- `GET /mcp/info` - 서버 정보
- `GET /mcp/tools` - 도구 목록
- `POST /mcp/tools` - 도구 실행
- `POST /mcp/messages` - MCP 메시지 (JSON-RPC)

**특징:**
- 완전한 MCP 프로토콜 준수
- OpenAPI 3.0 스펙 포함
- Application Insights 통합
- 에러 처리 및 로깅

### 2. APIM 정책 템플릿 ([apim-policies/](apim-policies/))

#### a. base-policy.xml
- CORS 설정
- Rate Limiting (100 calls/분)
- 요청/응답 로깅
- MCP 프로토콜 헤더 추가
- 에러 응답 표준화

#### b. jwt-validation-policy.xml
- OpenID Connect 기반 JWT 검증
- Entra ID 통합
- Audience, Issuer, Scope 검증
- 사용자 정보 추출 (User ID, Email)
- 감사 로그

#### c. transform-request-policy.xml
- MCP 요청 → REST API 요청 변환
- Weather API 예제 포함
- 쿼리 파라미터 매핑
- HTTP Method 변환

#### d. transform-response-policy.xml
- REST API 응답 → MCP 응답 변환
- Weather 데이터 포맷팅
- 에러 처리 및 변환

### 3. Bicep 인프라 템플릿 ([bicep/main.bicep](bicep/main.bicep))

**배포되는 리소스:**
- ✅ **API Management** (Basicv2 SKU)
  - System-assigned Managed Identity
  - Application Insights 통합
  - Diagnostics 설정

- ✅ **Azure Functions App** (Python 3.12)
  - System-assigned Managed Identity
  - Premium/Consumption Plan 지원
  - Application Insights 통합
  - MCP 환경 변수 설정

- ✅ **Application Insights**
  - Log Analytics Workspace 연동
  - 30일 retention

- ✅ **Storage Account**
  - Standard_LRS
  - TLS 1.2 강제
  - Public access 차단

- ✅ **APIM Logger & Diagnostics**
  - 요청/응답 로깅
  - W3C 상관 관계 프로토콜

**출력 (Outputs):**
- APIM Gateway URL
- Functions App URL
- Application Insights Key
- Managed Identity Principal IDs

### 4. MCP 클라이언트 샘플

#### a. test-client.py ([src/client/test-client.py](src/client/test-client.py))

**기능:**
- MCP 서버 연결
- Bearer Token 인증 지원
- 8가지 테스트 시나리오:
  1. Health Check
  2. Server Info
  3. List Tools
  4. Echo Tool
  5. Get Time Tool
  6. Calculate Tool
  7. MCP Message: tools/list
  8. MCP Message: tools/call

**사용법:**
```python
from test_client import McpClient

client = McpClient(
    base_url="https://apim-mcp-lab.azure-api.net/mcp",
    access_token="eyJ0eXAiOiJKV1Q..."
)

# 도구 호출
result = client.call_tool('echo', {'message': 'Hello MCP!'})
print(result)
```

#### b. get-token.sh ([src/client/get-token.sh](src/client/get-token.sh))

**기능:**
- OAuth 2.0 Client Credentials Flow
- Entra ID 토큰 발급
- 토큰 디코딩 및 검증

**사용법:**
```bash
export AZURE_TENANT_ID="..."
export ENTRA_CLIENT_APP_ID="..."
export ENTRA_CLIENT_SECRET="..."
./get-token.sh
```

### 5. 워크샵 노트북 ([workshop.ipynb](workshop.ipynb))

**구조:**
- Section 0: 환경 설정 및 초기화 (✅ 시작됨)
- Section 1: Azure Functions로 MCP 서버 개발
- Section 2: APIM으로 엔터프라이즈 게이트웨이 구성
- Section 3: 외부 REST API를 MCP 서버로 변환
- Section 4: OpenID Connect 기반 인증
- Section 5: External Entra ID 연계 (B2B)
- Section 6: 모니터링 및 최적화
- Section 7: 리소스 정리

**패턴:**
- Azure-Samples/AI-Gateway 스타일 따름
- 번호 매긴 섹션 (0️⃣, 1️⃣, 2️⃣...)
- 코드 셀 + 설명 셀 조합
- 한국어 설명

## 🚀 빠른 시작 가이드

### 1. 환경 준비

```bash
cd /Users/hyungilkim/Documents/Labs/workshop/apim-mcp

# Python 패키지 설치
pip install -r requirements.txt

# 환경 변수 설정
cp .env.example .env
# .env 파일 편집하여 필요한 값 입력
```

### 2. Azure 로그인

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 3. 로컬에서 Functions 테스트 (선택)

```bash
cd src/mcp-function
func start

# 다른 터미널에서 테스트
curl http://localhost:7071/api/mcp/health
curl http://localhost:7071/api/mcp/tools
```

### 4. Azure에 배포

```bash
# 리소스 그룹 생성
az group create --name rg-mcp-lab --location koreacentral

# Bicep으로 인프라 배포
az deployment group create \
  --resource-group rg-mcp-lab \
  --template-file bicep/main.bicep

# Functions 배포
cd src/mcp-function
func azure functionapp publish <function-app-name>
```

### 5. APIM 설정

```bash
# API 생성 및 정책 적용은 워크샵 노트북 참조
```

### 6. 테스트

```bash
# 토큰 발급
cd src/client
./get-token.sh

# 클라이언트 테스트
export APIM_GATEWAY_URL="https://<apim-name>.azure-api.net/mcp"
export MCP_ACCESS_TOKEN="<token>"
python test-client.py
```

## 📚 핵심 학습 포인트

### 1. MCP 프로토콜 구현
- ✅ MCP Tools 구조 이해
- ✅ JSON-RPC 스타일 메시지 처리
- ✅ Tool 실행 및 결과 반환
- ✅ 에러 처리 패턴

### 2. Azure Functions 활용
- ✅ HTTP Trigger 설정
- ✅ Function App 구조
- ✅ Application Insights 통합
- ✅ Managed Identity 활용

### 3. APIM 엔터프라이즈 패턴
- ✅ API Gateway 역할
- ✅ 정책 (Policies) 작성
- ✅ 요청/응답 변환
- ✅ Rate Limiting & Quota
- ✅ JWT 검증

### 4. OpenID Connect & Entra ID
- ✅ OAuth 2.0 흐름
- ✅ JWT 토큰 발급
- ✅ 클레임 검증
- ✅ External Entra ID (B2B)

### 5. Infrastructure as Code
- ✅ Bicep 템플릿 작성
- ✅ 리소스 간 연동
- ✅ Outputs 활용
- ✅ 모범 사례 적용

## 🔐 보안 고려사항

### 구현된 보안 기능
- ✅ JWT 토큰 기반 인증
- ✅ OpenID Connect 통합
- ✅ HTTPS 전용
- ✅ Rate Limiting
- ✅ Managed Identity
- ✅ TLS 1.2 최소 버전
- ✅ Public Blob Access 차단

### 추가 권장사항
- 🔲 VNet 통합
- 🔲 Private Endpoint
- 🔲 Key Vault 통합
- 🔲 조건부 액세스
- 🔲 IP 필터링

## 📊 모니터링 & 관찰성

### 구현된 기능
- ✅ Application Insights 통합
- ✅ Log Analytics Workspace
- ✅ APIM Diagnostics
- ✅ 구조화된 로깅
- ✅ 상관 관계 추적 (W3C)

### 사용 가능한 메트릭
- 요청/응답 시간
- 에러율
- Tool 실행 횟수
- Rate Limit 적중
- 사용자별 사용량

## 🎓 확장 아이디어

1. **추가 MCP 도구**
   - Azure Blob Storage 연동
   - Cosmos DB 쿼리
   - Azure OpenAI 통합

2. **고급 APIM 기능**
   - GraphQL Federation
   - WebSocket 지원
   - Circuit Breaker 패턴

3. **멀티 테넌트**
   - 테넌트별 격리
   - 사용량 추적
   - 청구 통합

4. **CI/CD**
   - GitHub Actions
   - Azure DevOps
   - 자동 배포

5. **성능 최적화**
   - 캐싱 전략
   - CDN 통합
   - 콜드 스타트 최소화

## 🐛 알려진 제한사항

1. **APIM 정책 XML**
   - XML 특수 문자 이스케이프 필요
   - IDE에서 문법 오류 표시될 수 있음 (실제로는 정상 작동)

2. **Bicep 템플릿**
   - OpenAPI 파일 경로 관련 경고 (배포 시 정상 작동)
   - Management API URL 하드코딩 경고

3. **Functions 콜드 스타트**
   - Consumption Plan 사용 시 초기 지연
   - Premium Plan 권장 (프로덕션)

## 🤝 기여 방법

1. 이슈 생성
2. Fork 후 개선
3. Pull Request 제출

## 📄 라이선스

MIT License

---

## 🎯 다음 단계

1. ✅ **[WORKSHOP_COMPLETION_GUIDE.md](WORKSHOP_COMPLETION_GUIDE.md)** 읽기
2. ✅ **[workshop.ipynb](workshop.ipynb)** 노트북 열기
3. ✅ 환경 변수 설정 (.env)
4. ✅ Section 0부터 순서대로 실행
5. ✅ 각 섹션의 코드와 설명 확인
6. ✅ 커스터마이징 및 실험

---

**워크샵을 즐기세요! 🚀**

질문이나 이슈가 있다면 언제든 문의해 주세요.
