#!/bin/bash
# APIM Named Value 'functions-key' 업데이트 스크립트

set -e

FUNC_KEY=$(az functionapp keys list --name mcp-dev-func-i6ht --resource-group rg-mcp-lab --query "functionKeys.default" -o tsv)
echo "Functions Key: ${FUNC_KEY:0:15}..."

SUB_ID=$(az account show --query id -o tsv)
echo "Subscription: $SUB_ID"

# Named Value 업데이트
az rest --method patch \
  --url "https://management.azure.com/subscriptions/${SUB_ID}/resourceGroups/rg-mcp-lab/providers/Microsoft.ApiManagement/service/mcp-dev-apim-i6ht/namedValues/functions-key?api-version=2024-05-01" \
  --body '{"properties":{"displayName":"functions-key","value":"'"${FUNC_KEY}"'","secret":true}}' \
  -o none

echo "✅ Named Value 업데이트 완료!"

# 테스트
echo ""
echo "🧪 APIM Gateway 테스트..."
curl -s -w "\nHTTP Status: %{http_code}\n" \
  -H "Ocp-Apim-Subscription-Key: 7ad611b7cf7449629d4c614f7314a529" \
  "https://mcp-dev-apim-i6ht.azure-api.net/mcp/health"
