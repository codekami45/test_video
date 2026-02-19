# PowerShell: send webhook once
$Base = if ($env:BASE_URL) { $env:BASE_URL } else { "http://localhost:3000" }
$Tenant = "a1b2c3d4-0000-4000-8000-000000000001"
$Account = "acc11111-0000-4000-8000-000000000001"

$body = @{
    source = "plaid"
    event_id = "evt_demo_001"
    tenant_id = $Tenant
    payload = @{
        account_id = $Account
        transactions = @(
            @{
                provider_tx_id = "plaid_tx_new_001"
                amount = -9.99
                description = "STARBUCKS NEW LOCATION"
                occurred_at = "2025-02-19T09:00:00Z"
                status = "posted"
                version = 1
            }
        )
    }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri "$Base/webhooks/transactions" -Method Post -Body $body -ContentType "application/json"
