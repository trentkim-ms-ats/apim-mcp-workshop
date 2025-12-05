#!/bin/bash

# Azure Entra ID에서 토큰 발급
# 사용법: ./get-token.sh

set -e

# 환경 변수 로드
if [ -f .env ]; then
    source .env
fi

TENANT_ID="${AZURE_TENANT_ID}"
CLIENT_ID="${ENTRA_CLIENT_APP_ID}"
CLIENT_SECRET="${ENTRA_CLIENT_SECRET}"
SCOPE="${ENTRA_API_APP_ID}/.default"

if [ -z "$TENANT_ID" ] || [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "❌ 환경 변수가 설정되지 않았습니다."
    echo "   AZURE_TENANT_ID, ENTRA_CLIENT_APP_ID, ENTRA_CLIENT_SECRET를 확인하세요."
    exit 1
fi

echo "🔐 Azure Entra ID 토큰 발급 중..."
echo "   Tenant: $TENANT_ID"
echo "   Client: $CLIENT_ID"
echo "   Scope: $SCOPE"
echo ""

# OAuth2 Client Credentials Flow로 토큰 발급
RESPONSE=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" \
    -d "scope=$SCOPE" \
    -d "grant_type=client_credentials")

# 토큰 추출
ACCESS_TOKEN=$(echo $RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))")

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ 토큰 발급 실패"
    echo "$RESPONSE" | python3 -m json.tool
    exit 1
fi

echo "✅ 토큰 발급 완료!"
echo ""
echo "Access Token:"
echo "$ACCESS_TOKEN"
echo ""
echo "토큰을 환경 변수로 저장하려면:"
echo "export MCP_ACCESS_TOKEN=\"$ACCESS_TOKEN\""
echo ""

# 토큰 디코드 (선택)
echo "토큰 정보 (디코딩):"
echo "$ACCESS_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | python3 -m json.tool || echo "토큰 디코딩 실패"
