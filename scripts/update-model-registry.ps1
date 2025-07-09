param(
    [Parameter(Mandatory=$true)]
    [string]$ModelName,
    
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$true)]
    [string]$Environment
)

Write-Host "Updating model registry for $ModelName version $Version in $Environment environment" -ForegroundColor Green

try {
    # Create registry entry
    $registryEntry = @{
        ModelName = $ModelName
        Version = $Version
        Environment = $Environment
        DeploymentDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        Status = "Active"
        DeployedBy = $env:BUILD_REQUESTEDFOR
        BuildId = $env:BUILD_BUILDID
        SourceBranch = $env:BUILD_SOURCEBRANCH
    }
    
    # Create registry directory if it doesn't exist
    $registryDir = Join-Path $PSScriptRoot "..\registry"
    if (-not (Test-Path $registryDir)) {
        New-Item -ItemType Directory -Path $registryDir -Force
        Write-Host "Created registry directory: $registryDir" -ForegroundColor Yellow
    }
    
    # Save registry entry
    $registryFile = Join-Path $registryDir "$ModelName-$Environment.json"
    $registryEntry | ConvertTo-Json -Depth 10 | Out-File -FilePath $registryFile -Encoding UTF8
    
    Write-Host "✓ Model registry updated successfully" -ForegroundColor Green
    Write-Host "Registry file: $registryFile" -ForegroundColor Gray
    
    # Update global registry index
    $indexFile = Join-Path $registryDir "registry-index.json"
    $index = @()
    
    if (Test-Path $indexFile) {
        $index = Get-Content $indexFile | ConvertFrom-Json
    }
    
    # Remove existing entry for same model and environment
    $index = $index | Where-Object { -not ($_.ModelName -eq $ModelName -and $_.Environment -eq $Environment) }
    
    # Add new entry
    $index += $registryEntry
    
    # Save updated index
    $index | ConvertTo-Json -Depth 10 | Out-File -FilePath $indexFile -Encoding UTF8
    
    Write-Host "✓ Registry index updated successfully" -ForegroundColor Green
    Write-Host "Total models in registry: $($index.Count)" -ForegroundColor Gray
    
    exit 0
}
catch {
    Write-Error "Failed to update model registry: $($_.Exception.Message)"
    exit 1
}
