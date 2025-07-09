param(
    [Parameter(Mandatory = $true)]
    [string]$ServicePrincipalId,
    
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId
)

Write-Host "Configuring service principal permissions..." -ForegroundColor Green
Write-Host "Service Principal ID: $ServicePrincipalId" -ForegroundColor Cyan
Write-Host "Subscription ID: $SubscriptionId" -ForegroundColor Cyan

# Define environments and roles
$environments = @("dev", "qa", "prod")
$roles = @(
    "Cognitive Services Contributor",
    "Storage Blob Data Contributor", 
    "Key Vault Secrets User"
)

foreach ($env in $environments) {
    $resourceGroupName = "rg-dimlops-$env"
    Write-Host "`nConfiguring permissions for environment: $env" -ForegroundColor Yellow
    
    foreach ($role in $roles) {
        Write-Host "  Assigning role: $role" -ForegroundColor White
        
        try {
            az role assignment create `
                --assignee $ServicePrincipalId `
                --role $role `
                --scope "/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName" `
                --output none
            
            Write-Host "    ✓ Successfully assigned $role" -ForegroundColor Green
        }
        catch {
            Write-Host "    ✗ Failed to assign $role`: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nService principal configuration completed!" -ForegroundColor Green
