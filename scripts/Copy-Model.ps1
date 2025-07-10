<#
.SYNOPSIS
    Azure Document Intelligence Model Copy Script

.DESCRIPTION
    This script copies a custom Document Intelligence model from one service to another.
    It implements the recommended disaster recovery approach by Microsoft.

.PARAMETER SourceService
    The name of the source Document Intelligence service

.PARAMETER TargetService
    The name of the target Document Intelligence service

.PARAMETER ModelName
    The name of the model to copy

.PARAMETER SourceResourceGroup
    The resource group containing the source service

.PARAMETER TargetResourceGroup
    The resource group containing the target service

.PARAMETER SkipTargetModelDeletion
    If specified, the script will not delete the existing model in the target service before copying.
    By default, the script will delete any existing model with the same name in the target service.

.EXAMPLE
    .\Copy-Model.ps1 -SourceService "doc-intel-dev" -TargetService "doc-intel-prod" -ModelName "invoice-model-v1" -SourceResourceGroup "rg-dev" -TargetResourceGroup "rg-prod"

.EXAMPLE
    .\Copy-Model.ps1 -SourceService "doc-intel-dev" -TargetService "doc-intel-prod" -ModelName "invoice-model-v1" -SourceResourceGroup "rg-dev" -TargetResourceGroup "rg-prod" -SkipTargetModelDeletion

.NOTES
    This script follows the Microsoft recommended approach for copying Document Intelligence models:
    https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/how-to-guides/disaster-recovery
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceService,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetService,
    
    [Parameter(Mandatory = $true)]
    [string]$ModelName,
    
    [Parameter(Mandatory = $true)]
    [string]$SourceResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetResourceGroup,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipTargetModelDeletion = $false
)

# Set strict mode to catch common programming errors
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Log information function
function Write-LogInfo {
    param([string]$Message)
    Write-Host "INFO: $Message" -ForegroundColor Cyan
}

# Log success function
function Write-LogSuccess {
    param([string]$Message)
    Write-Host "SUCCESS: $Message" -ForegroundColor Green
}

# Log error function
function Write-LogError {
    param([string]$Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

# Function to check if a service exists
function Test-ServiceExists {
    param(
        [string]$ServiceName,
        [string]$ResourceGroup
    )
    
    Write-LogInfo "Checking if service $ServiceName exists..."
    try {
        $service = az cognitiveservices account show --name $ServiceName --resource-group $ResourceGroup --output json | ConvertFrom-Json
        if ($null -ne $service) {
            Write-LogSuccess "Service $ServiceName found"
            return $true
        }
    }
    catch {
        Write-LogError "Service $ServiceName not found in resource group $ResourceGroup"
        return $false
    }
}

# Function to get service key
function Get-ServiceKey {
    param(
        [string]$ServiceName,
        [string]$ResourceGroup
    )
    
    try {
        $key = az cognitiveservices account keys list --name $ServiceName --resource-group $ResourceGroup --query "key1" --output tsv
        return $key
    }
    catch {
        Write-LogError "Failed to retrieve key for service $ServiceName"
        throw $_
    }
}

# Function to get service endpoint
function Get-ServiceEndpoint {
    param(
        [string]$ServiceName,
        [string]$ResourceGroup
    )
    
    try {
        $endpoint = az cognitiveservices account show --name $ServiceName --resource-group $ResourceGroup --query "properties.endpoint" --output tsv
        return $endpoint
    }
    catch {
        Write-LogError "Failed to retrieve endpoint for service $ServiceName"
        throw $_
    }
}

# Function to check if a model exists in a service
function Test-ModelExists {
    param(
        [string]$ServiceEndpoint,
        [string]$ServiceKey,
        [string]$ModelName
    )
    
    Write-LogInfo "Checking if model $ModelName exists in the target service..."
    
    try {
        # Remove trailing slash from endpoint if present
        $endpointTrim = $ServiceEndpoint.TrimEnd('/')
        
        $headers = @{
            "Ocp-Apim-Subscription-Key" = $ServiceKey
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod `
            -Uri "$endpointTrim/documentintelligence/documentModels/$ModelName`?api-version=2024-11-30" `
            -Method Get `
            -Headers $headers `
            -ErrorAction SilentlyContinue
        
        if ($null -ne $response) {
            Write-LogInfo "Model $ModelName found in target service"
            return $true
        }
        
        return $false
    }
    catch {
        # If the error is 404, the model doesn't exist
        if ($_.Exception.Response.StatusCode.value__ -eq 404) {
            Write-LogInfo "Model $ModelName not found in target service"
            return $false
        }
        
        # For other errors, log and return false
        Write-LogInfo "Error checking if model exists: $_"
        return $false
    }
}

# Function to delete a model from a service
function Remove-Model {
    param(
        [string]$ServiceEndpoint,
        [string]$ServiceKey,
        [string]$ModelName
    )
    
    Write-LogInfo "Deleting model $ModelName from target service..."
    
    try {
        # Remove trailing slash from endpoint if present
        $endpointTrim = $ServiceEndpoint.TrimEnd('/')
        
        $headers = @{
            "Ocp-Apim-Subscription-Key" = $ServiceKey
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod `
            -Uri "$endpointTrim/documentintelligence/documentModels/$ModelName`?api-version=2024-11-30" `
            -Method Delete `
            -Headers $headers
            
        Write-LogSuccess "Model $ModelName deleted from target service"
        return $true
    }
    catch {
        Write-LogError "Failed to delete model $ModelName from target service: $_"
        return $false
    }
}

# Function to copy model using REST API
function Copy-DocumentIntelligenceModel {
    param(
        [string]$SourceEndpoint,
        [string]$SourceKey,
        [string]$TargetEndpoint,
        [string]$TargetKey,
        [string]$ModelName
    )
    
    Write-LogInfo "Copying model $ModelName from source to target..."
    
    # Step 1: Get copy authorization from target
    Write-LogInfo "Generating copy authorization from target service..."
    
    $authPayload = @{
        modelId = $ModelName
        description = "Model copied from $SourceService"
    } | ConvertTo-Json -Compress
    
    # Invoke REST API to get copy authorization
    try {
        $authHeaders = @{
            "Ocp-Apim-Subscription-Key" = $TargetKey
            "Content-Type" = "application/json"
        }
        
        # Remove trailing slash from endpoint if present
        $targetEndpointTrim = $TargetEndpoint.TrimEnd('/')
        
        $authResponse = Invoke-RestMethod `
            -Uri "$targetEndpointTrim/documentintelligence/documentModels:authorizeCopy?api-version=2024-11-30" `
            -Method Post `
            -Headers $authHeaders `
            -Body $authPayload `
            -ErrorAction Stop
        
        Write-LogSuccess "Copy authorization generated successfully"
    }
    catch {
        Write-LogError "Failed to get copy authorization: $_"
        throw
    }
    
    # Step 2: Start copy operation on source
    Write-LogInfo "Initiating copy operation on source service..."
    
    try {
        $copyHeaders = @{
            "Ocp-Apim-Subscription-Key" = $SourceKey
            "Content-Type" = "application/json"
        }
        
        # Remove trailing slash from endpoint if present
        $sourceEndpointTrim = $SourceEndpoint.TrimEnd('/')
        
        $copyResponse = Invoke-WebRequest `
            -Uri "$sourceEndpointTrim/documentintelligence/documentModels/$ModelName`:copyTo?api-version=2024-11-30" `
            -Method Post `
            -Headers $copyHeaders `
            -Body ($authResponse | ConvertTo-Json) `
            -ErrorAction Stop
        
        # Extract operation ID from response headers
        $operationLocation = $copyResponse.Headers['Operation-Location']
        if (-not $operationLocation) {
            Write-LogError "No operation location returned from copy request"
            throw "Unable to track copy operation"
        }
        
        $operationId = $operationLocation -replace '.*operations/(.*)\?.*', '$1'
        Write-LogSuccess "Copy operation initiated successfully"
        Write-LogInfo "Operation ID: $operationId"
    }
    catch {
        Write-LogError "Failed to initiate copy operation: $_"
        throw
    }
    
    # Step 3: Track copy operation status
    Write-LogInfo "Tracking copy operation status..."
    $maxRetries = 30
    $retryCount = 0
    $operationStatus = "notStarted"
    $delay = 10  # Initial delay in seconds
    
    while ($operationStatus -ne "succeeded" -and $retryCount -lt $maxRetries) {
        $retryCount++
        
        try {
            Start-Sleep -Seconds $delay
            
            # Implement exponential backoff with a cap
            $delay = [Math]::Min([Math]::Pow(1.5, $retryCount), 60)
            
            $statusResponse = Invoke-RestMethod `
                -Uri $operationLocation[0] `
                -Headers @{ "Ocp-Apim-Subscription-Key" = $SourceKey } `
                -Method Get `
                -ErrorAction Stop
            
            $operationStatus = $statusResponse.status
            Write-LogInfo "Operation status: $operationStatus (Attempt $retryCount of $maxRetries)"
            
            if ($operationStatus -eq "failed") {
                Write-LogError "Copy operation failed: $($statusResponse.error.message)"
                return $false
            }
        }
        catch {
            Write-LogInfo "Error checking status, will retry: $_"
            # Continue with retry
        }
    }
    
    if ($operationStatus -eq "succeeded") {
        Write-LogSuccess "Model copy completed successfully"
        return $true
    }
    else {
        Write-LogError "Model copy did not complete within expected time"
        return $false
    }
}

# Main execution
try {
    Write-LogInfo "Starting model copy operation..."
    Write-LogInfo "Source Service: $SourceService"
    Write-LogInfo "Target Service: $TargetService"
    Write-LogInfo "Model Name: $ModelName"
    Write-LogInfo "Source Resource Group: $SourceResourceGroup"
    Write-LogInfo "Target Resource Group: $TargetResourceGroup"
    
    # Validate Azure CLI login
    Write-LogInfo "Validating Azure CLI login..."
    try {
        $azAccount = az account show --output json | ConvertFrom-Json
        if ($null -eq $azAccount) {
            throw "Not logged in"
        }
        Write-LogSuccess "Azure CLI authenticated as $($azAccount.user.name)"
    }
    catch {
        Write-LogError "Not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    }
    
    # Check if source service exists
    if (-not (Test-ServiceExists -ServiceName $SourceService -ResourceGroup $SourceResourceGroup)) {
        exit 1
    }
    
    # Check if target service exists
    if (-not (Test-ServiceExists -ServiceName $TargetService -ResourceGroup $TargetResourceGroup)) {
        exit 1
    }
    
    # Get service credentials
    $sourceKey = Get-ServiceKey -ServiceName $SourceService -ResourceGroup $SourceResourceGroup
    $targetKey = Get-ServiceKey -ServiceName $TargetService -ResourceGroup $TargetResourceGroup
    $sourceEndpoint = Get-ServiceEndpoint -ServiceName $SourceService -ResourceGroup $SourceResourceGroup
    $targetEndpoint = Get-ServiceEndpoint -ServiceName $TargetService -ResourceGroup $TargetResourceGroup
    
    if (-not $sourceKey -or -not $targetKey -or -not $sourceEndpoint -or -not $targetEndpoint) {
        Write-LogError "Failed to retrieve service credentials or endpoints"
        exit 1
    }
    
    Write-LogSuccess "Service credentials and endpoints retrieved successfully"
    
    # Check if model exists in target service
    $modelExists = Test-ModelExists -ServiceEndpoint $targetEndpoint -ServiceKey $targetKey -ModelName $ModelName
    
    if ($modelExists -and -not $SkipTargetModelDeletion) {
        # Model exists and deletion is not skipped, remove the existing model
        $deleteResult = Remove-Model -ServiceEndpoint $targetEndpoint -ServiceKey $targetKey -ModelName $ModelName
        if (-not $deleteResult) {
            Write-LogError "Failed to delete existing model in target service. Aborting copy operation."
            exit 1
        }
    }
    elseif ($modelExists -and $SkipTargetModelDeletion) {
        Write-LogInfo "Skipping model deletion in target service as per user request"
    }
    
    # Perform the model copy
    $copyResult = Copy-DocumentIntelligenceModel `
        -SourceEndpoint $sourceEndpoint `
        -SourceKey $sourceKey `
        -TargetEndpoint $targetEndpoint `
        -TargetKey $targetKey `
        -ModelName $ModelName
    
    if ($copyResult) {
        Write-LogSuccess "Model copy operation completed successfully!"
        Write-Host "You can verify the model is available in the target service: $TargetService"
    }
    else {
        Write-LogError "Model copy operation failed."
        exit 1
    }
}
catch {
    Write-LogError "An unexpected error occurred: $_"
    exit 1
}
