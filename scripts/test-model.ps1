param(
    [Parameter(Mandatory=$true)]
    [string]$CognitiveServiceName,
    
    [Parameter(Mandatory=$true)]
    [string]$ModelName,
    
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [switch]$SmokeTestOnly
)

# Import required modules
Import-Module Az.CognitiveServices -Force

Write-Host "Starting model testing for $ModelName in $Environment environment" -ForegroundColor Green

try {
    # Initialize test results
    $testResults = @()
    $testsPassed = 0
    $testsFailed = 0
    
    # Get service information using Azure CLI
    Write-Host "Getting service information for $CognitiveServiceName..." -ForegroundColor Yellow

    $serviceJson = az cognitiveservices account show --name $CognitiveServiceName --resource-group $ResourceGroup --query "{Endpoint:properties.endpoint}" -o json 2>$null
    if (-not $serviceJson) {
        throw "Cognitive Services account $CognitiveServiceName not found in resource group $ResourceGroup"
    }
    $service = $serviceJson | ConvertFrom-Json
    $endpoint = $service.Endpoint

    $key = az cognitiveservices account keys list --name $CognitiveServiceName --resource-group $ResourceGroup --query "key1" -o tsv 2>$null
    if (-not $key) {
        throw "Failed to retrieve key for $CognitiveServiceName in $ResourceGroup"
    }

    Write-Host "✓ Service information retrieved" -ForegroundColor Green
    Write-Host "Endpoint: $endpoint" -ForegroundColor Gray
    
    # Test 1: Model Availability
    Write-Host "Testing model availability..." -ForegroundColor Yellow
    
    try {
        $headers = @{
            'Ocp-Apim-Subscription-Key' = $key
            'Content-Type' = 'application/json'
        }
        
        $modelUri = "$endpoint/documentintelligence/documentModels/$ModelName?api-version=2024-11-30"
        $response = Invoke-RestMethod -Uri $modelUri -Method GET -Headers $headers
        
        if ($response -and $response.modelId -eq $ModelName) {
            Write-Host "✓ Model $ModelName is available and accessible" -ForegroundColor Green
            $testsPassed++
            $testResults += @{
                TestName = "ModelAvailability"
                Status = "Passed"
                Details = "Model is available and accessible"
                Environment = $Environment
            }
        } else {
            Write-Host "✗ Model $ModelName response validation failed" -ForegroundColor Red
            $testsFailed++
            $testResults += @{
                TestName = "ModelAvailability"
                Status = "Failed"
                Details = "Model response validation failed"
                Environment = $Environment
            }
        }
    }
    catch {
        Write-Host "✗ Model $ModelName is not available: $($_.Exception.Message)" -ForegroundColor Red
        $testsFailed++
        $testResults += @{
            TestName = "ModelAvailability"
            Status = "Failed"
            Details = "Model not available: $($_.Exception.Message)"
            Environment = $Environment
        }
    }
    
    # Test 2: Model Status
    Write-Host "Testing model status..." -ForegroundColor Yellow
    
    try {
        $statusUri = "$endpoint/documentintelligence/documentModels/$ModelName?api-version=2024-11-30"
        $statusResponse = Invoke-RestMethod -Uri $statusUri -Method GET -Headers $headers
        
        if ($statusResponse.status -eq "ready") {
            Write-Host "✓ Model status is ready" -ForegroundColor Green
            $testsPassed++
            $testResults += @{
                TestName = "ModelStatus"
                Status = "Passed"
                Details = "Model status is ready"
                Environment = $Environment
            }
        } else {
            Write-Host "✗ Model status is not ready: $($statusResponse.status)" -ForegroundColor Red
            $testsFailed++
            $testResults += @{
                TestName = "ModelStatus"
                Status = "Failed"
                Details = "Model status: $($statusResponse.status)"
                Environment = $Environment
            }
        }
    }
    catch {
        Write-Host "✗ Failed to get model status: $($_.Exception.Message)" -ForegroundColor Red
        $testsFailed++
        $testResults += @{
            TestName = "ModelStatus"
            Status = "Failed"
            Details = "Failed to get model status: $($_.Exception.Message)"
            Environment = $Environment
        }
    }
    
    # Test 3: Service Health
    Write-Host "Testing service health..." -ForegroundColor Yellow
    
    try {
        $healthUri = "$endpoint/documentintelligence/documentModels?api-version=2024-11-30"
        $healthResponse = Invoke-RestMethod -Uri $healthUri -Method GET -Headers $headers
        
        if ($healthResponse) {
            Write-Host "✓ Service is healthy and responding" -ForegroundColor Green
            $testsPassed++
            $testResults += @{
                TestName = "ServiceHealth"
                Status = "Passed"
                Details = "Service is healthy and responding"
                Environment = $Environment
            }
        } else {
            Write-Host "✗ Service health check failed" -ForegroundColor Red
            $testsFailed++
            $testResults += @{
                TestName = "ServiceHealth"
                Status = "Failed"
                Details = "Service health check failed"
                Environment = $Environment
            }
        }
    }
    catch {
        Write-Host "✗ Service health check failed: $($_.Exception.Message)" -ForegroundColor Red
        $testsFailed++
        $testResults += @{
            TestName = "ServiceHealth"
            Status = "Failed"
            Details = "Service health check failed: $($_.Exception.Message)"
            Environment = $Environment
        }
    }
    
    # Test 4: Document Processing Test (if not smoke test only)
    if (-not $SmokeTestOnly) {
        Write-Host "Testing document processing..." -ForegroundColor Yellow
        
        # Check for test document
        $testDocPath = Join-Path $PSScriptRoot "..\test-data\sample-document.pdf"
        
        if (Test-Path $testDocPath) {
            try {
                # Read test document
                $testDocBytes = [System.IO.File]::ReadAllBytes($testDocPath)
                $testDocBase64 = [System.Convert]::ToBase64String($testDocBytes)
                
                # Prepare request
                $analyzeUri = "$endpoint/documentintelligence/documentModels/$ModelName`:analyze?api-version=2024-11-30"
                $analyzeBody = @{
                    base64Source = $testDocBase64
                } | ConvertTo-Json
                
                $analyzeHeaders = $headers.Clone()
                $analyzeHeaders['Content-Type'] = 'application/json'
                
                # Submit analysis request
                $analyzeResponse = Invoke-RestMethod -Uri $analyzeUri -Method POST -Headers $analyzeHeaders -Body $analyzeBody
                
                if ($analyzeResponse -and $analyzeResponse.status) {
                    Write-Host "✓ Document processing test initiated successfully" -ForegroundColor Green
                    $testsPassed++
                    $testResults += @{
                        TestName = "DocumentProcessing"
                        Status = "Passed"
                        Details = "Document processing test completed successfully"
                        Environment = $Environment
                    }
                } else {
                    Write-Host "✗ Document processing test failed" -ForegroundColor Red
                    $testsFailed++
                    $testResults += @{
                        TestName = "DocumentProcessing"
                        Status = "Failed"
                        Details = "Document processing test failed"
                        Environment = $Environment
                    }
                }
            }
            catch {
                Write-Host "✗ Document processing test failed: $($_.Exception.Message)" -ForegroundColor Red
                $testsFailed++
                $testResults += @{
                    TestName = "DocumentProcessing"
                    Status = "Failed"
                    Details = "Document processing test failed: $($_.Exception.Message)"
                    Environment = $Environment
                }
            }
        } else {
            Write-Host "⚠ Test document not found at $testDocPath, skipping document processing test" -ForegroundColor Yellow
            $testResults += @{
                TestName = "DocumentProcessing"
                Status = "Skipped"
                Details = "Test document not found"
                Environment = $Environment
            }
        }
    }
    
    # Generate JUnit XML results
    $junitXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="ModelTesting_$Environment" tests="$($testsPassed + $testsFailed)" failures="$testsFailed" errors="0" time="0">
"@
    
    foreach ($result in $testResults) {
        $junitXml += @"
    <testcase name="$($result.TestName)" classname="ModelTesting_$($result.Environment)">
"@
        if ($result.Status -eq "Failed") {
            $junitXml += @"
        <failure message="$($result.Details)">$($result.Details)</failure>
"@
        } elseif ($result.Status -eq "Skipped") {
            $junitXml += @"
        <skipped message="$($result.Details)">$($result.Details)</skipped>
"@
        }
        $junitXml += @"
    </testcase>
"@
    }
    
    $junitXml += @"
</testsuite>
"@
    
    # Save results
    $resultsPath = Join-Path $PSScriptRoot "..\$($Environment.ToLower())-test-results.xml"
    $junitXml | Out-File -FilePath $resultsPath -Encoding UTF8
    
    Write-Host "Testing completed. Passed: $testsPassed, Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
    Write-Host "Results saved to: $resultsPath" -ForegroundColor Yellow
    
    # Exit with appropriate code
    if ($testsFailed -gt 0) {
        exit 1
    } else {
        exit 0
    }
}
catch {
    Write-Error "Testing failed with error: $($_.Exception.Message)"
    exit 1
}
