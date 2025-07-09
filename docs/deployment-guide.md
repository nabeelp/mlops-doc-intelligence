# Azure Document Intelligence MLOps Deployment Guide

This guide provides step-by-step instructions for deploying and configuring the Azure Document Intelligence MLOps pipeline.

## Prerequisites

Before starting the deployment, ensure you have:

1. **Azure CLI** installed and authenticated
2. **Azure DevOps** project with Pipelines enabled
3. **PowerShell 5.1** or later
4. **Appropriate permissions** in Azure subscription:
   - Contributor role on the subscription or resource groups
   - User Access Administrator (for RBAC assignments)

## Infrastructure Deployment

### Step 1: Deploy Azure Resources

Deploy the infrastructure for each environment (dev, qa, prod):

```powershell
# Navigate to the infra directory
cd infra

# Deploy development environment
./deploy.ps1 -Environment "dev" -ResourceGroupName "rg-dimlops-dev" -SubscriptionId "your-subscription-id"

# Deploy QA environment
./deploy.ps1 -Environment "qa" -ResourceGroupName "rg-dimlops-qa" -SubscriptionId "your-subscription-id"

# Deploy production environment
./deploy.ps1 -Environment "prod" -ResourceGroupName "rg-dimlops-prod" -SubscriptionId "your-subscription-id"
```

### Step 2: Note the Deployment Outputs

Each deployment will create a file `deployment-outputs-{environment}.json` with the following information:
- Cognitive Services account name and endpoint
- Storage account name
- Key Vault name
- Application Insights name
- Resource group name

## Azure DevOps Configuration

### Step 3: Create Service Connection

1. Navigate to **Project Settings** > **Service connections**
2. Create a new **Azure Resource Manager** connection:
   - Connection name: `azure-service-connection`
   - Authentication method: Service principal (automatic)
   - Scope level: Subscription
   - Select your subscription
   - Grant access permission to all pipelines

### Step 4: Create Variable Groups

Create three variable groups with the following variables:

#### doc-intelligence-dev
```
DEV_COGNITIVE_SERVICE_NAME: [from deployment outputs]
DEV_RESOURCE_GROUP: rg-dimlops-dev
DEV_SUBSCRIPTION_ID: [your subscription id]
```

#### doc-intelligence-qa
```
QA_COGNITIVE_SERVICE_NAME: [from deployment outputs]
QA_RESOURCE_GROUP: rg-dimlops-qa
QA_SUBSCRIPTION_ID: [your subscription id]
```

#### doc-intelligence-prod
```
PROD_COGNITIVE_SERVICE_NAME: [from deployment outputs]
PROD_RESOURCE_GROUP: rg-dimlops-prod
PROD_SUBSCRIPTION_ID: [your subscription id]
```

### Step 5: Create Environments

1. Navigate to **Pipelines** > **Environments**
2. Create environments:
   - **QA**: No approval required
   - **Production**: Add approval gate (recommended)

### Step 6: Configure Service Principal Permissions

Grant the service principal (from the service connection created in Step 3) the following permissions on each environment by running the configuration script:

```powershell
# Navigate to the scripts directory
cd scripts

# Run the service principal configuration script
# Use the Object ID of the service principal associated with your 'azure-service-connection'
./configure-service-principal.ps1 `
    -ServicePrincipalId "service-principal-object-id-from-step-3" `
    -SubscriptionId "your-subscription-id"
```

> **Note**: To find the service principal Object ID, go to **Project Settings** > **Service connections** > **azure-service-connection** > **Manage App Registration** > Click on the link in the Essentials section, after the "Managed application in local directory" label, and copy the Object ID of the associated Enterprise Application.

This script will automatically assign the following roles to the service principal for all environments (dev, qa, prod):
- **Cognitive Services Contributor** - For managing Document Intelligence models
- **Storage Blob Data Contributor** - For accessing training data and artifacts
- **Key Vault Secrets User** - For accessing secrets and configuration

## Model Preparation

### Step 7: Prepare Your Model

1. Create a model directory under `models/your-model-name/`
2. Add a `config.json` file with your model configuration:

```json
{
  "modelType": "document-intelligence-custom",
  "version": "1.0.0",
  "description": "Your model description",
  "accuracy": 0.92,
  "trainingData": {
    "datasetName": "your-dataset",
    "documentCount": 150
  },
  "fields": [
    {
      "name": "FieldName",
      "type": "string",
      "confidence": 0.95
    }
  ]
}
```

3. Update the `modelName` variable in `azure-pipelines.yml`

### Step 8: Add Test Data

1. Place test documents in the `test-data/` directory
2. Ensure you have at least one sample document for testing
3. Name your primary test document `sample-document.pdf`

## Pipeline Execution

### Step 9: Create and Run Pipeline

1. Navigate to **Pipelines** > **Pipelines**
2. Create a new pipeline:
   - Select **Azure Repos Git**
   - Choose your repository
   - Select **Existing Azure Pipelines YAML file**
   - Choose `/azure-pipelines.yml`
3. Save and run the pipeline

### Step 10: Monitor Pipeline Execution

The pipeline will execute the following stages:
1. **Model Validation** - Validates configuration and accuracy
2. **Promote to QA** - Deploys to QA environment (triggered on develop branch)
3. **Promote to Production** - Deploys to production (triggered on main branch)
4. **Post-Deployment** - Updates registry and notifications

## Verification and Testing

### Step 11: Verify Deployment

After successful pipeline execution:

1. **Check Cognitive Services**: Verify models are deployed
2. **Review Test Results**: Check JUnit test outputs
3. **Validate Model Registry**: Confirm registry updates
4. **Test Endpoints**: Manually test Document Intelligence endpoints

### Step 12: Test Model Functionality

```powershell
# Test the deployed model
./scripts/test-model.ps1 `
    -CognitiveServiceName "your-service-name" `
    -ModelName "your-model-name" `
    -Environment "qa" `
    -ResourceGroup "rg-dimlops-qa"
```

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify service connection configuration
   - Check service principal permissions
   - Ensure correct subscription IDs

2. **Model Copy Failures**
   - Verify source model exists
   - Check network connectivity
   - Validate service endpoints

3. **Test Failures**
   - Review test document availability
   - Check accuracy thresholds
   - Verify model configuration

### Logs and Monitoring

- **Pipeline Logs**: Available in Azure DevOps pipeline runs
- **Azure Monitor**: Application Insights for service monitoring
- **Storage Logs**: Backup and artifact storage logs
- **Test Results**: JUnit XML reports in pipeline results

## Maintenance

### Regular Tasks

1. **Monitor Pipeline Executions**: Review success/failure rates
2. **Update Model Configurations**: Keep accuracy thresholds current
3. **Rotate Secrets**: Regularly update service principal credentials
4. **Review Permissions**: Audit RBAC assignments
5. **Update Test Data**: Keep test documents current

### Scaling Considerations

- **Multi-Region**: Deploy to multiple Azure regions for availability
- **Cost Optimization**: Use appropriate SKUs for each environment
- **Performance**: Monitor and adjust Cognitive Services capacity
- **Security**: Implement network restrictions and private endpoints

## Next Steps

1. **Implement Advanced Testing**: Add performance and load testing
2. **Add Monitoring**: Set up alerts and dashboards
3. **Enhance Security**: Implement private endpoints and network restrictions
4. **Optimize Costs**: Review and adjust SKUs based on usage
5. **Document Processes**: Create operational runbooks

For additional support, refer to:
- [Azure Document Intelligence Documentation](https://docs.microsoft.com/azure/cognitive-services/form-recognizer/)
- [Azure DevOps Pipeline Documentation](https://docs.microsoft.com/azure/devops/pipelines/)
- [MLOps Best Practices](https://docs.microsoft.com/azure/machine-learning/concept-model-management-and-deployment)
