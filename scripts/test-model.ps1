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

    $headers = @{
        'Ocp-Apim-Subscription-Key' = $key
        'Content-Type' = 'application/json'
    }

    Write-Host "✓ Service information retrieved" -ForegroundColor Green
    Write-Host "Endpoint: $endpoint" -ForegroundColor Gray
    
    # Test 1: Service Health
    Write-Host "Testing service health..." -ForegroundColor Yellow
    
    try {
        $healthUri = $endpoint+"/documentintelligence/documentModels?api-version=2024-11-30"
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
    
    # Test 2: Model Availability
    Write-Host "Testing model availability..." -ForegroundColor Yellow
    
    try {
        $modelUri = $endpoint+"/documentintelligence/documentModels/"+$ModelName+"?api-version=2024-11-30"
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
    
    # Test 3: Document Processing Test (if not smoke test only)
    if (-not $SmokeTestOnly) {
        Write-Host "Testing document processing..." -ForegroundColor Yellow
        
        # Check for test document
        $testDocPath = Join-Path $PSScriptRoot "..\test-data\Test\Invoice_6.pdf"
        
        if (Test-Path $testDocPath) {
            try {
                # Read test document
                $testDocBytes = [System.IO.File]::ReadAllBytes($testDocPath)
                $testDocBase64 = [System.Convert]::ToBase64String($testDocBytes)
                
                # Prepare request
                $analyzeUri = $endpoint+"/documentintelligence/documentModels/"+$ModelName+":analyze?api-version=2024-11-30"
                $analyzeBody = @{
                    base64Source = $testDocBase64
                } | ConvertTo-Json
                
                $analyzeHeaders = $headers.Clone()
                $analyzeHeaders['Content-Type'] = 'application/json'

                # Submit analysis request
                $analyzeResponse = Invoke-WebRequest -Uri $analyzeUri -Method POST -Headers $analyzeHeaders -Body $analyzeBody
                
                # Get the operation-location header which contains the URL for polling
                $operationLocation = $analyzeResponse.Headers['Operation-Location']
                Write-Host "Document analysis initiated. Operation-Location: $operationLocation" -ForegroundColor Gray
                
                if (-not $operationLocation) {
                    Write-Host "✗ Document processing test failed: Operation-Location header not found" -ForegroundColor Red
                    $testsFailed++
                    $testResults += @{
                        TestName = "DocumentProcessing"
                        Status = "Failed"
                        Details = "Operation-Location header not found in the analyze response"
                        Environment = $Environment
                    }
                } else {
                    Write-Host "Document analysis initiated. Polling for results..." -ForegroundColor Yellow
                    
                    # Poll the operation until it completes
                    $maxRetries = 20
                    $retryCount = 0
                    $analyzeResult = $null
                    
                    while ($retryCount -lt $maxRetries) {
                        $retryCount++
                        Write-Host "Polling attempt $retryCount of $maxRetries..." -ForegroundColor Gray
                        
                        try {
                            $statusResponse = Invoke-RestMethod -Uri $operationLocation[0] -Method GET -Headers $headers
                            
                            if ($statusResponse.status -eq "succeeded") {
                                $analyzeResult = $statusResponse.analyzeResult
                                break
                            } elseif ($statusResponse.status -eq "failed") {
                                Write-Host "✗ Document analysis failed: $($statusResponse.error.message)" -ForegroundColor Red
                                $testsFailed++
                                $testResults += @{
                                    TestName = "DocumentProcessing"
                                    Status = "Failed"
                                    Details = "Document analysis failed: $($statusResponse.error.message)"
                                    Environment = $Environment
                                }
                                break
                            } else {
                                # Still processing, wait and try again
                                Start-Sleep -Seconds 3
                            }
                        }
                        catch {
                            Write-Host "Error polling for results: $($_.Exception.Message)" -ForegroundColor Red
                            Start-Sleep -Seconds 3
                        }
                    }
                    
                    if ($analyzeResult) {
                        # Validate the analysis result
                        if ($analyzeResult.documents -and $analyzeResult.documents.Count -gt 0) {
                            Write-Host "✓ Document processing test completed successfully" -ForegroundColor Green
                            Write-Host "  Document type identified: $($analyzeResult.documents[0].docType)" -ForegroundColor Gray
                            $testsPassed++
                            $testResults += @{
                                TestName = "DocumentProcessing"
                                Status = "Passed"
                                Details = "Document processing completed successfully. Document type: $($analyzeResult.documents[0].docType)"
                                Environment = $Environment
                            }
                        } else {
                            Write-Host "✓ Document analysis completed but no documents were identified" -ForegroundColor Yellow
                            $testsPassed++
                            $testResults += @{
                                TestName = "DocumentProcessing"
                                Status = "Passed"
                                Details = "Document analysis completed but no documents were identified"
                                Environment = $Environment
                            }
                        }
                    } elseif ($retryCount -ge $maxRetries) {
                        Write-Host "✗ Document processing test failed: Timed out waiting for analysis to complete" -ForegroundColor Red
                        $testsFailed++
                        $testResults += @{
                            TestName = "DocumentProcessing"
                            Status = "Failed"
                            Details = "Timed out waiting for analysis to complete"
                            Environment = $Environment
                        }
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
    
    # Output results as JSON to the console
    $output = @{
        Environment = $Environment
        Passed = $testsPassed
        Failed = $testsFailed
        Results = $testResults
    } | ConvertTo-Json -Depth 10
    Write-Host $output

    Write-Host "Testing completed. Passed: $testsPassed, Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })

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
