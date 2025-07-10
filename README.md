# Azure Document Intelligence MLOps Pipeline

This repository contains an Azure DevOps pipeline for implementing MLOps practices with Azure Document Intelligence models, providing automated promotion from Development to QA to Production environments with comprehensive infrastructure as code.

## Overview

The pipeline automates the deployment and testing of Azure Document Intelligence models across multiple environments with the following stages:

1. **Promote to QA** - Deploys model from Dev to QA environment and runs comprehensive tests
2. **Promote to Production** - Creates backup, deploys model to production with smoke testing
3. **Infrastructure Management** - Bicep templates for automated resource provisioning
4. **Automated Backup** - Production model backup before deployment

## Architecture

```
Dev Environment → QA Environment → Production Environment
     ↓                 ↓                    ↓
PowerShell Copy → Integration Tests → Backup + Deploy
     ↓                 ↓                    ↓
Branch: develop   Automated Testing    Branch: main
                                      Manual Approval
```

**Infrastructure Components:**
- Azure Document Intelligence services (Dev, QA, Prod)
- Azure Storage accounts for model artifacts and backups
- Azure Key Vault for secure credential storage
- Service Principal with environment-specific RBAC

## Prerequisites

### Azure Resources
- Azure Cognitive Services accounts in each environment (Dev, QA, Prod)
- Azure DevOps project with pipelines enabled
- Service principal with appropriate permissions

### Required Tools
- Azure CLI with Cognitive Services extension
- PowerShell 5.1 or later
- Azure DevOps project with Pipelines enabled

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd mlops-doc-intelligence
   ```

2. **Configure Azure Infrastructure**
   - Deploy infrastructure using Bicep templates: `.\infra\deploy.ps1`
   - Create variable groups (see [Variable Groups Configuration](docs/variable-groups.md))
   - Set up service connections
   - Create environments (QA, Production)

3. **Prepare your model**
   - Place model configuration in `models/<model-name>/config.json`
   - Update the `modelName` variable in `azure-pipelines.yml`

4. **Run the pipeline**
   - Push changes to trigger the pipeline
   - Monitor execution in Azure DevOps

## Directory Structure

```
mlops-doc-intelligence/
├── azure-pipelines.yml          # Main pipeline definition
├── infra/                       # Infrastructure as Code
│   ├── main.bicep              # Main Bicep template
│   ├── deploy.ps1              # Deployment script
│   └── main.parameters.*.json  # Environment-specific parameters
├── scripts/                     # PowerShell and bash scripts
│   ├── Copy-Model.ps1          # Model copying script (PowerShell)
│   ├── backup-model.sh         # Model backup script (Bash)
│   ├── test-model.ps1          # Model testing script (PowerShell)
│   ├── configure-service-principal.ps1 # RBAC configuration
│   └── backups/                # Model backup storage
├── models/                     # Model configurations
│   └── example-model/
│       └── config.json         # Model configuration example
├── test-data/                  # Test documents for validation
├── docs/                       # Documentation
│   ├── variable-groups.md      # Variable groups setup guide
│   └── deployment-guide.md     # Infrastructure deployment guide
└── README.md                   # This file
```

## Pipeline Stages

### 1. Promote to QA Environment
- **Trigger**: Commits to `develop` branch
- **Actions**:
  - Uses PowerShell `Copy-Model.ps1` script for reliable model copying
  - Follows Microsoft's recommended Document Intelligence model copy API
  - Automatically deletes existing target model before copying (configurable)
  - Runs comprehensive integration tests using `test-model.ps1`
  - Generates detailed test reports

### 2. Promote to Production Environment  
- **Trigger**: Commits to `main` branch, after successful QA promotion
- **Actions**:
  - Creates timestamped backup of current production model using `backup-model.sh`
  - Stores backup metadata and model information in `scripts/backups/`
  - Copies model from QA to Production using PowerShell script
  - Runs smoke tests to validate deployment
  - Requires manual approval via Azure DevOps environments

### 3. Infrastructure Management
- **Bicep Templates**: Complete infrastructure as code for all environments
- **Automated Deployment**: PowerShell script for resource provisioning
- **Components**: Document Intelligence, Storage Account, Key Vault
- **RBAC Configuration**: Service principal setup with least-privilege access

## Configuration

### Infrastructure Deployment
Deploy the required Azure resources using Bicep templates:

```powershell
# Navigate to infrastructure directory
cd infra

# Deploy development environment
.\deploy.ps1 -Environment "dev" -ResourceGroupName "rg-dimlops-dev" -SubscriptionId "your-subscription-id"

# Deploy QA environment  
.\deploy.ps1 -Environment "qa" -ResourceGroupName "rg-dimlops-qa" -SubscriptionId "your-subscription-id"

# Deploy production environment
.\deploy.ps1 -Environment "prod" -ResourceGroupName "rg-dimlops-prod" -SubscriptionId "your-subscription-id"
```

### Service Principal Configuration
Configure the service principal with appropriate permissions:

```powershell
.\scripts\configure-service-principal.ps1 -ServicePrincipalId "your-sp-id" -SubscriptionId "your-subscription-id"
```

### Model Configuration
Each model requires a `config.json` file with Document Intelligence model schema:

```json
{
  "docTypes": {
    "SampleInvoices-1.0": {
      "fieldSchema": {
        "InvoiceNumber": {
          "type": "string"
        },
        "InvoiceDate": {
          "type": "string"
        },
        "TotalAmount": {
          "type": "string"
        },
        "VendorName": {
          "type": "string"
        }
      },
      "buildMode": "template",
      "fieldConfidence": {
        "InvoiceDate": 0.995,
        "InvoiceNumber": 0.995,
        "TotalAmount": 0.995,
        "VendorName": 0.8
      }
    }
  },
  "modelId": "SampleInvoices-1.0",
  "createdDateTime": "2025-07-09T12:14:15Z",
  "modifiedDateTime": "2025-07-09T12:14:15Z",
  "expirationDateTime": "2027-07-09T12:14:15Z"
}
```

### Environment Variables
Configure the following variable groups in Azure DevOps:

- `doc-intelligence-dev`
- `doc-intelligence-qa`
- `doc-intelligence-prod`

See [Variable Groups Configuration](docs/variable-groups.md) for detailed setup instructions.

## Testing

The pipeline includes comprehensive testing using PowerShell scripts:

- **Model Copy Validation**: Verifies successful model transfer between environments
- **Integration Tests**: End-to-end model functionality testing using `test-model.ps1`
- **Smoke Tests**: Basic connectivity and availability checks in production
- **Service Validation**: Confirms Azure Document Intelligence service accessibility

Test results are published in standard formats for Azure DevOps integration.

## Backup and Recovery

### Automated Backup System
- **Pre-deployment Backup**: Automatic backup before production deployments
- **Timestamped Storage**: Backups stored in `scripts/backups/YYYYMMDD_HHMMSS/` format
- **Metadata Tracking**: Complete backup metadata including service details and timestamps
- **Model Information**: Full model configuration and properties preserved

### Backup Structure
```
scripts/backups/20250709_170010/
├── backup_metadata.json           # Backup metadata and timestamps
└── SampleInvoices-1.0_model_info.json  # Complete model information
```

## Infrastructure as Code

### Bicep Templates
- **Complete Environment Setup**: Automated provisioning of all required Azure resources
- **Environment-Specific Parameters**: Separate parameter files for dev, qa, and prod
- **Security Best Practices**: Managed identities, Key Vault integration, minimal permissions

### Deployed Resources
- **Azure Document Intelligence**: FormRecognizer service with S0 SKU
- **Azure Storage Account**: Containers for model artifacts, backups, and test data
- **Azure Key Vault**: Secure storage for secrets and connection strings
- **RBAC Configuration**: Proper role assignments for service principals

### Deployment Script Features
- Template validation before deployment
- What-if analysis for change preview
- Automated resource group creation
- Environment-specific configuration

## Security

- **Service Principal Authentication**: Least privilege access with environment-specific RBAC
- **Azure Key Vault Integration**: Secure secret management across all environments
- **Managed Identities**: System-assigned identities for Azure resources
- **Network Security**: Configurable network access controls and private endpoints
- **Audit Trail**: Complete deployment and access logging
- **Environment Isolation**: Separate service principals and resource groups per environment

## Branch Strategy

- **develop branch**: Triggers deployment to QA environment
- **main branch**: Triggers deployment to Production environment (after QA success)
- **Feature branches**: No automatic deployments
- **Manual approval**: Required for production deployments via Azure DevOps environments

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify service connection configuration in Azure DevOps
   - Check service principal permissions using `configure-service-principal.ps1`
   - Ensure subscription access and proper RBAC assignments

2. **Model Copy Failures**
   - Verify source model exists in source environment
   - Check target service availability and resource group permissions
   - Validate network connectivity between services
   - Review Copy-Model.ps1 logs for detailed error information

3. **Infrastructure Deployment Issues**
   - Run Bicep template validation: `az deployment group validate`
   - Check resource naming conflicts (names must be globally unique)
   - Verify subscription quotas and service availability in target region
   - Review deploy.ps1 execution logs

4. **Test Failures**
   - Verify test document availability in `test-data` folder
   - Check model confidence thresholds in config.json
   - Validate service endpoints and authentication keys
   - Review test-model.ps1 output for specific failure details

5. **Backup Issues**
   - Ensure sufficient storage space in backup directory
   - Check bash script execution permissions on Linux agents
   - Verify source model exists before backup attempt

### Support

For issues and questions:
1. Check Azure DevOps pipeline logs for detailed execution information
2. Review test result outputs and PowerShell script logs
3. Validate configuration files (config.json, parameter files)
4. Run infrastructure validation using Bicep what-if analysis
5. Check backup directory for successful model backup operations
6. Contact the MLOps team for advanced troubleshooting

## Scripts Reference

### PowerShell Scripts
- `Copy-Model.ps1`: Robust model copying with automatic cleanup and validation
- `test-model.ps1`: Comprehensive model testing with smoke test options
- `configure-service-principal.ps1`: RBAC configuration for all environments
- `deploy.ps1`: Infrastructure deployment with validation and preview

### Bash Scripts  
- `backup-model.sh`: Production model backup with metadata tracking

## Getting Started Checklist

- [ ] Azure subscription with appropriate permissions
- [ ] Azure DevOps project configured
- [ ] Service principal created and configured
- [ ] Infrastructure deployed to all environments (dev, qa, prod)
- [ ] Variable groups configured in Azure DevOps
- [ ] Service connections established
- [ ] Environment approvals configured
- [ ] Test model deployed to development environment
- [ ] Pipeline successfully executed end-to-end

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
