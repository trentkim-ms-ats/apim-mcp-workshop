#!/bin/bash
# APIM API 정책 추가 - Backend 사용하도록 설정

set -e

SUB_ID=$(az account show --query id -o tsv)
echo "Subscription: $SUB_ID"

# API 정책 XML
POLICY='<policies><inbound><base /><set-backend-service backend-id="mcp-functions-backend" /></inbound><backend><base /></backend><outbound><base /><set-header name="X-MCP-Protocol-Version" exists-action="override"><value>2024-11-05</value></set-header></outbound><on-error><base /></on-error></policies>'

# JSON body 생성
BODY=$(cat <<EOF
{
  "properties": {
    "format": "xml",
    "value": "$POLICY"
  }
}
EOF
)

echo "Adding API policy..."
az rest --method put \
  --url "https://management.azure.com/subscriptions/${SUB_ID}/resourceGroups/rg-mcp-lab/providers/Microsoft.ApiManagement/service/mcp-dev-apim-i6ht/apis/mcp-api/policies/policy?api-version=2024-05-01" \
  --body "$BODY" \
  -o none

echo "✅ API 정책 추가 완료!"
echo ""
echo "🧪 테스트 중..."
sleep 3

APIM_KEY=$(az rest --method post --url "https://management.azure.com/subscriptions/${SUB_ID}/resourceGroups/rg-mcp-lab/providers/Microsoft.ApiManagement/service/mcp-dev-apim-i6ht/subscriptions/master/listSecrets?api-version=2024-05-01" --query "primaryKey" -o tsv)

curl -s -w "\nHTTP Status: %{http_code}\n" \
  -H "Ocp-Apim-Subscription-Key: ${APIM_KEY}" \
  "https://mcp-dev-apim-i6ht.azure-api.net/mcp/health"
