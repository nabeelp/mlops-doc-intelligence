# Azure DevOps Variable Groups Configuration

This document outlines the required variable groups and variables for the Document Intelligence MLOps pipeline.

## Variable Groups

### 1. doc-intelligence-dev
Development environment variables:
- `DEV_COGNITIVE_SERVICE_NAME`: Name of the Azure Cognitive Services account in Dev
- `DEV_RESOURCE_GROUP`: Resource group name for Dev environment
- `DEV_SUBSCRIPTION_ID`: Azure subscription ID for Dev environment

### 2. doc-intelligence-qa
QA environment variables:
- `QA_COGNITIVE_SERVICE_NAME`: Name of the Azure Cognitive Services account in QA
- `QA_RESOURCE_GROUP`: Resource group name for QA environment
- `QA_SUBSCRIPTION_ID`: Azure subscription ID for QA environment

### 3. doc-intelligence-prod
Production environment variables:
- `PROD_COGNITIVE_SERVICE_NAME`: Name of the Azure Cognitive Services account in Prod
- `PROD_RESOURCE_GROUP`: Resource group name for Prod environment
- `PROD_SUBSCRIPTION_ID`: Azure subscription ID for Prod environment

## Service Connections

### Required Service Connections:
1. **azure-service-connection**: Azure Resource Manager service connection with appropriate permissions
2. **teams-webhook**: (Optional) Teams webhook for notifications

## Permissions Required

The service principal used by the Azure service connection needs the following permissions:

### For Each Environment (Dev, QA, Prod):
- **Cognitive Services Contributor** role on the Cognitive Services accounts
- **Reader** role on the resource groups
- **Storage Blob Data Contributor** (if using storage for model artifacts)

### Minimum Required Permissions:
- Microsoft.CognitiveServices/accounts/read
- Microsoft.CognitiveServices/accounts/write
- Microsoft.CognitiveServices/accounts/listKeys/action
- Microsoft.CognitiveServices/accounts/models/read
- Microsoft.CognitiveServices/accounts/models/write
- Microsoft.CognitiveServices/accounts/models/delete

## Setup Instructions

1. Create the variable groups in Azure DevOps:
   - Go to Pipelines > Library
   - Create new variable group for each environment
   - Add the required variables with appropriate values

2. Create service connections:
   - Go to Project Settings > Service connections
   - Create new Azure Resource Manager connection
   - Use service principal authentication
   - Grant appropriate permissions to the service principal

3. Configure environments:
   - Go to Pipelines > Environments
   - Create "QA" and "Production" environments
   - Add approval gates for Production environment if required

4. Update pipeline variables:
   - Modify the `azureServiceConnection` variable in azure-pipelines.yml
   - Update the `modelName` variable to match your model name
