# Infrastructure Deployment Script
# This script deploys the Azure resources for Document Intelligence MLOps

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "qa", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "South Africa North"
)

Write-Host "Deploying Azure Document Intelligence MLOps infrastructure for $Environment environment" -ForegroundColor Green

try {
    # Set the Azure subscription
    Write-Host "Setting Azure subscription: $SubscriptionId" -ForegroundColor Yellow
    az account set --subscription $SubscriptionId
    
    # Create resource group if it doesn't exist
    Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
    az group create --name $ResourceGroupName --location $Location
    
    # Validate the Bicep template
    Write-Host "Validating Bicep template..." -ForegroundColor Yellow
    $validationResult = az deployment group validate `
        --resource-group $ResourceGroupName `
        --template-file "./main.bicep" `
        --parameters "@main.parameters.$Environment.json" `
        --query "error" -o tsv --verbose
    
    if ($validationResult) {
        Write-Error "Template validation failed: $validationResult"
        exit 1
    }
    
    Write-Host "✓ Template validation successful" -ForegroundColor Green
    
    # Preview the deployment
    Write-Host "Previewing deployment changes..." -ForegroundColor Yellow
    az deployment group what-if `
        --resource-group $ResourceGroupName `
        --template-file "./main.bicep" `
        --parameters "@main.parameters.$Environment.json"
    
    # Prompt for confirmation
    $confirmation = Read-Host "Do you want to proceed with the deployment? (y/N)"
    if ($confirmation -ne "y" -and $confirmation -ne "Y") {
        Write-Host "Deployment cancelled by user" -ForegroundColor Yellow
        exit 0
    }
    
    # Deploy the resources
    Write-Host "Starting deployment..." -ForegroundColor Yellow
    $deploymentResult = az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file "./main.bicep" `
        --parameters "@main.parameters.$Environment.json" `
        --name "dimlops-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
        --output json | ConvertFrom-Json
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Deployment completed successfully!" -ForegroundColor Green
        
        # Display outputs
        Write-Host "`nDeployment Outputs:" -ForegroundColor Cyan
        $outputs = $deploymentResult.properties.outputs
        
        foreach ($output in $outputs.PSObject.Properties) {
            Write-Host "$($output.Name): $($output.Value.value)" -ForegroundColor Gray
        }
        
        # Save outputs to file for pipeline usage
        $outputsFile = "deployment-outputs-$Environment.json"
        $outputs | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputsFile -Encoding UTF8
        Write-Host "`nOutputs saved to: $outputsFile" -ForegroundColor Yellow
        
        Write-Host "`nNext steps:" -ForegroundColor Cyan
        Write-Host "1. Update Azure DevOps variable groups with the deployment outputs" -ForegroundColor White
        Write-Host "2. Configure service principal permissions for the deployed resources" -ForegroundColor White
        Write-Host "3. Upload test data to the storage account" -ForegroundColor White
        Write-Host "4. Test the Document Intelligence service" -ForegroundColor White
        
    } else {
        Write-Error "Deployment failed with exit code: $LASTEXITCODE"
        exit 1
    }
}
catch {
    Write-Error "Deployment failed with error: $($_.Exception.Message)"
    exit 1
}
