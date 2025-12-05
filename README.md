# Azure APIM + MCP 서버 워크샵

엔터프라이즈급 MCP (Model Context Protocol) 서버를 Azure API Management와 Azure Functions를 활용하여 구축하는 실습 워크샵입니다.

## 📋 개요

이 워크샵에서는 다음 주제를 다룹니다:
- Azure Functions로 MCP 서버 개발
- APIM을 통한 엔터프라이즈 게이트웨이 구성
- 기존 REST API를 MCP 서버로 변환
- OpenID Connect 기반 인증
- External Entra ID 연계

## 🎯 학습 목표

1. **MCP 프로토콜 이해**: Model Context Protocol의 기본 개념과 구조 학습
2. **Azure Functions 기반 MCP 서버**: HTTP Trigger를 활용한 MCP 서버 구현
3. **APIM 정책 활용**: 요청/응답 변환, 인증, Rate Limiting 등 적용
4. **엔터프라이즈 보안**: OpenID Connect, JWT 검증, External Entra ID 통합
5. **모니터링 & 관리**: Application Insights, APIM Diagnostics 활용

## 🔧 사전 요구사항

### 권한
- Azure Subscription에 대한 Contributor 권한
- Entra ID Application 등록 권한
- APIM, Functions, Managed Identity, VNet, Private Endpoint 생성 권한

### 도구
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (최신 버전)
- [VS Code](https://code.visualstudio.com/) + [Azure Functions Extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)
- [Python 3.12+](https://www.python.org/downloads/) 또는 [Node.js 18+](https://nodejs.org/)
- [Postman](https://www.postman.com/) 또는 [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) (선택)

### Azure 리소스
워크샵을 통해 다음 리소스를 생성합니다:
- API Management (Basicv2 SKU)
- Azure Functions (Premium 또는 Consumption)
- Container Apps (선택)
- Application Insights
- Storage Account
- Entra ID Applications

## 📁 프로젝트 구조

```
apim-mcp/
├── README.md                          # 이 파일
├── workshop.ipynb                     # 메인 워크샵 노트북
├── requirements.txt                   # Python 패키지
├── .env.example                       # 환경 변수 템플릿
├── images/                            # 다이어그램 및 이미지
│   └── architecture.png
├── src/
│   ├── mcp-function/                  # Azure Functions MCP 서버
│   │   ├── function_app.py            # Python 구현
│   │   ├── host.json
│   │   ├── local.settings.json
│   │   └── requirements.txt
│   ├── mcp-server/                    # Container Apps MCP 서버
│   │   ├── mcp-server.py
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   └── client/                        # MCP 클라이언트 샘플
│       ├── test-client.py
│       └── get-token.sh
├── apim-policies/                     # APIM 정책 XML
│   ├── base-policy.xml
│   ├── jwt-validation-policy.xml
│   ├── transform-request-policy.xml
│   └── transform-response-policy.xml
├── bicep/                             # Infrastructure as Code
│   ├── main.bicep
│   ├── modules/
│   │   ├── apim.bicep
│   │   ├── function.bicep
│   │   ├── containerapp.bicep
│   │   └── entra-app.bicep
│   └── parameters.json
└── shared/
    └── utils.py                       # 공통 유틸리티
```

## 🚀 빠른 시작

### 1. 환경 설정

```bash
# 저장소 클론 (또는 파일 다운로드)
cd apim-mcp

# Python 패키지 설치
pip install -r requirements.txt

# 환경 변수 설정
cp .env.example .env
# .env 파일을 편집하여 필요한 값 입력
```

### 2. Azure에 로그인

```bash
# Azure CLI 로그인
az login

# 사용할 구독 설정
az account set --subscription "<your-subscription-id>"
```

### 3. 워크샵 노트북 실행

VS Code에서 `workshop.ipynb` 파일을 열고 순서대로 실행합니다.

## 📚 워크샵 구성

### Section 1: Azure Functions로 MCP 서버 개발
- MCP 프로토콜 기본 인터페이스 설계
- HTTP Trigger Function으로 MCP 서버 구현
- 로컬 테스트 및 Azure 배포

### Section 2: APIM으로 MCP 엔드포인트 구성
- APIM 인스턴스 생성 및 API 등록
- Backend 설정 (Functions 연동)
- 정책 적용 (Rate Limiting, CORS, Logging)

### Section 3: 외부 REST API를 MCP 서버로 변환
- 기존 REST API를 APIM Backend로 등록
- OpenAPI 스펙 임포트
- 요청/응답 변환 정책 작성

### Section 4: OpenID Connect 기반 인증
- Entra ID 앱 등록 (API + Client)
- APIM에서 JWT 검증 설정
- 토큰 발급 및 테스트

### Section 5: External Entra ID 연계 (고급)
- Cross-tenant 접근 시나리오
- B2B Guest 사용자 초대
- External 사용자 토큰으로 MCP 호출

### Section 6: 모니터링 및 최적화
- Application Insights 통합
- APIM Diagnostics 활용
- 성능 최적화 및 보안 강화

## 🏗️ 아키텍처

```
┌─────────────┐
│ MCP Client  │
│ (Copilot/   │
│  AI Agent)  │
└──────┬──────┘
       │ HTTPS + JWT
       ▼
┌──────────────────────────────────────┐
│   Azure API Management (Gateway)      │
│  ┌────────────────────────────────┐  │
│  │  JWT Validation                │  │
│  │  Rate Limiting                 │  │
│  │  Request/Response Transform    │  │
│  │  Logging & Monitoring          │  │
│  └────────────────────────────────┘  │
└─────────┬────────────────────────────┘
          │
    ┌─────┴──────┐
    ▼            ▼
┌──────────┐  ┌──────────────┐
│ Azure    │  │ External     │
│ Functions│  │ REST API     │
│ MCP      │  │ (Weather,    │
│ Server   │  │  GitHub etc) │
└──────────┘  └──────────────┘
```

## 🔐 보안 고려사항

1. **인증**: OpenID Connect / OAuth 2.0
2. **권한**: RBAC 및 Entra ID 역할 기반 접근 제어
3. **네트워크**: VNet 통합, Private Endpoint (선택)
4. **비밀 관리**: Key Vault 통합
5. **감사**: Application Insights, APIM Analytics

## 📖 참고 자료

- [Model Context Protocol Specification](https://spec.modelcontextprotocol.io/)
- [Azure API Management Documentation](https://learn.microsoft.com/azure/api-management/)
- [Azure Functions Documentation](https://learn.microsoft.com/azure/azure-functions/)
- [Microsoft Entra ID Documentation](https://learn.microsoft.com/entra/identity/)
- [Azure-Samples/AI-Gateway](https://github.com/Azure-Samples/AI-Gateway)

## 🤝 기여

이슈 및 풀 리퀘스트를 환영합니다!

## 📄 라이선스

MIT License

## 💬 문의

질문이나 피드백은 이슈로 남겨주세요.
