# PowerShell: demonstrate webhook idempotency
$Base = if ($env:BASE_URL) { $env:BASE_URL } else { "http://localhost:3000" }
$Tenant = "a1b2c3d4-0000-4000-8000-000000000001"
$Account = "acc11111-0000-4000-8000-000000000001"

$body = @{
    source = "plaid"
    event_id = "evt_idempotent_demo"
    tenant_id = $Tenant
    payload = @{
        account_id = $Account
        transactions = @(
            @{
                provider_tx_id = "plaid_tx_idem_001"
                amount = -3.50
                description = "DUPLICATE TEST TX"
                occurred_at = "2025-02-19T10:00:00Z"
                status = "posted"
                version = 1
            }
        )
    }
} | ConvertTo-Json -Depth 5

Write-Host "First call:"
Invoke-RestMethod -Uri "$Base/webhooks/transactions" -Method Post -Body $body -ContentType "application/json" | ConvertTo-Json

Write-Host "`nSecond call (same event_id - should return duplicate_ignored):"
Invoke-RestMethod -Uri "$Base/webhooks/transactions" -Method Post -Body $body -ContentType "application/json" | ConvertTo-Json
