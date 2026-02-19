# PowerShell: propose and confirm recategorization
$Base = if ($env:BASE_URL) { $env:BASE_URL } else { "http://localhost:3000" }
$Tenant = "a1b2c3d4-0000-4000-8000-000000000001"
$User = "u1111111-0000-4000-8000-000000000001"

$body = @{
    tenant_id = $Tenant
    user_id = $User
    question = "Please propose recategorizing one of my Starbucks transactions from yesterday to the Coffee category. Which transaction would you suggest and why?"
} | ConvertTo-Json

Write-Host "Step 1: Ask AI to propose"
$resp = Invoke-RestMethod -Uri "$Base/ai/chat" -Method Post -Body $body -ContentType "application/json"
$resp | ConvertTo-Json -Depth 5

$proposalId = $resp.action_proposal.proposal_id
if (-not $proposalId) {
    Write-Host "No proposal in response. Set OPENAI_API_KEY for full flow."
    exit
}

Write-Host "`nStep 2: User confirms proposal $proposalId"
$confirmBody = @{
    proposal_id = $proposalId
    user_id = $User
    tenant_id = $Tenant
} | ConvertTo-Json

Invoke-RestMethod -Uri "$Base/actions/confirm" -Method Post -Body $confirmBody -ContentType "application/json" | ConvertTo-Json
