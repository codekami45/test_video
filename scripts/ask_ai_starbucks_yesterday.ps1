# PowerShell: ask AI about Starbucks spend
$Base = if ($env:BASE_URL) { $env:BASE_URL } else { "http://localhost:3000" }
$Tenant = "a1b2c3d4-0000-4000-8000-000000000001"
$User = "u1111111-0000-4000-8000-000000000001"

$body = @{
    tenant_id = $Tenant
    user_id = $User
    question = "How much did I spend at Starbucks yesterday? Please cite each transaction ID."
} | ConvertTo-Json

Invoke-RestMethod -Uri "$Base/ai/chat" -Method Post -Body $body -ContentType "application/json" | ConvertTo-Json -Depth 5
