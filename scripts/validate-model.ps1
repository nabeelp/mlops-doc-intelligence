param(
    [Parameter(Mandatory=$true)]
    [string]$ModelName,
    
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$CognitiveServiceName,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup
)

# Import required modules
Import-Module Az.CognitiveServices -Force

Write-Host "Starting model validation for $ModelName in $Environment environment" -ForegroundColor Green

try {
    # Initialize validation results
    $validationResults = @()
    $testsPassed = 0
    $testsFailed = 0
    
    # Test 1: Check if model exists
    Write-Host "Validating model existence..." -ForegroundColor Yellow
    
    if ($Environment -eq "dev") {
        # For dev environment, check local model files
        $modelPath = Join-Path $PSScriptRoot "..\models\$ModelName"
        if (Test-Path $modelPath) {
            Write-Host "✓ Model files found at $modelPath" -ForegroundColor Green
            $testsPassed++
            $validationResults += @{
                TestName = "ModelFilesExist"
                Status = "Passed"
                Details = "Model files found at $modelPath"
            }
        } else {
            Write-Host "✗ Model files not found at $modelPath" -ForegroundColor Red
            $testsFailed++
            $validationResults += @{
                TestName = "ModelFilesExist"
                Status = "Failed"
                Details = "Model files not found at $modelPath"
            }
        }
    } else {
        # For QA/Prod environments, check Azure Cognitive Services
        if (-not $CognitiveServiceName -or -not $ResourceGroup) {
            throw "CognitiveServiceName and ResourceGroup are required for $Environment environment"
        }
        
        $model = Get-AzCognitiveServicesAccountModel -ResourceGroupName $ResourceGroup -AccountName $CognitiveServiceName -Name $ModelName -ErrorAction SilentlyContinue
        if ($model) {
            Write-Host "✓ Model $ModelName found in $CognitiveServiceName" -ForegroundColor Green
            $testsPassed++
            $validationResults += @{
                TestName = "ModelExistsInAzure"
                Status = "Passed"
                Details = "Model found in Azure Cognitive Services"
            }
        } else {
            Write-Host "✗ Model $ModelName not found in $CognitiveServiceName" -ForegroundColor Red
            $testsFailed++
            $validationResults += @{
                TestName = "ModelExistsInAzure"
                Status = "Failed"
                Details = "Model not found in Azure Cognitive Services"
            }
        }
    }
    
    # Test 2: Validate model configuration
    Write-Host "Validating model configuration..." -ForegroundColor Yellow
    
    $configPath = Join-Path $PSScriptRoot "..\models\$ModelName\config.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        
        # Check required configuration properties
        $requiredProps = @('modelType', 'version', 'trainingData', 'accuracy')
        $configValid = $true
        
        foreach ($prop in $requiredProps) {
            if (-not $config.$prop) {
                Write-Host "✗ Missing required property: $prop" -ForegroundColor Red
                $configValid = $false
            }
        }
        
        if ($configValid) {
            Write-Host "✓ Model configuration is valid" -ForegroundColor Green
            $testsPassed++
            $validationResults += @{
                TestName = "ModelConfiguration"
                Status = "Passed"
                Details = "All required configuration properties present"
            }
        } else {
            $testsFailed++
            $validationResults += @{
                TestName = "ModelConfiguration"
                Status = "Failed"
                Details = "Missing required configuration properties"
            }
        }
    } else {
        Write-Host "✗ Model configuration file not found" -ForegroundColor Red
        $testsFailed++
        $validationResults += @{
            TestName = "ModelConfiguration"
            Status = "Failed"
            Details = "Configuration file not found"
        }
    }
    
    # Test 3: Validate model accuracy threshold
    Write-Host "Validating model accuracy..." -ForegroundColor Yellow
    
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        $minAccuracy = 0.85 # Minimum required accuracy
        
        if ($config.accuracy -ge $minAccuracy) {
            Write-Host "✓ Model accuracy ($($config.accuracy)) meets minimum threshold ($minAccuracy)" -ForegroundColor Green
            $testsPassed++
            $validationResults += @{
                TestName = "ModelAccuracy"
                Status = "Passed"
                Details = "Accuracy: $($config.accuracy), Threshold: $minAccuracy"
            }
        } else {
            Write-Host "✗ Model accuracy ($($config.accuracy)) below minimum threshold ($minAccuracy)" -ForegroundColor Red
            $testsFailed++
            $validationResults += @{
                TestName = "ModelAccuracy"
                Status = "Failed"
                Details = "Accuracy: $($config.accuracy), Threshold: $minAccuracy"
            }
        }
    }
    
    # Generate JUnit XML results
    $junitXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="ModelValidation" tests="$($testsPassed + $testsFailed)" failures="$testsFailed" errors="0" time="0">
"@
    
    foreach ($result in $validationResults) {
        $junitXml += @"
    <testcase name="$($result.TestName)" classname="ModelValidation">
"@
        if ($result.Status -eq "Failed") {
            $junitXml += @"
        <failure message="$($result.Details)">$($result.Details)</failure>
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
    $resultsPath = Join-Path $PSScriptRoot "..\validation-results.xml"
    $junitXml | Out-File -FilePath $resultsPath -Encoding UTF8
    
    Write-Host "Validation completed. Passed: $testsPassed, Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
    Write-Host "Results saved to: $resultsPath" -ForegroundColor Yellow
    
    # Exit with appropriate code
    if ($testsFailed -gt 0) {
        exit 1
    } else {
        exit 0
    }
}
catch {
    Write-Error "Validation failed with error: $($_.Exception.Message)"
    exit 1
}
