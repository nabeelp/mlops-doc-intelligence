# Azure Document Intelligence MLOps Pipeline

This repository contains an Azure DevOps pipeline for implementing MLOps practices with Azure Document Intelligence models, providing automated promotion from Development to QA to Production environments.

## Overview

The pipeline automates the deployment and testing of Azure Document Intelligence models across multiple environments with the following stages:

1. **Model Validation** - Validates model configuration and performance metrics
2. **Promote to QA** - Deploys model to QA environment and runs comprehensive tests
3. **Promote to Production** - Deploys model to production with backup and smoke testing
4. **Post-Deployment** - Updates model registry and sends notifications

## Architecture

```
Dev Environment → QA Environment → Production Environment
     ↓                 ↓                    ↓
Model Validation → Integration Tests → Smoke Tests
     ↓                 ↓                    ↓
   Pass/Fail      Automated Deploy    Manual Approval
```

## Prerequisites

### Azure Resources
- Azure Cognitive Services accounts in each environment (Dev, QA, Prod)
- Azure DevOps project with pipelines enabled
- Service principal with appropriate permissions

### Required Tools
- Azure CLI with Cognitive Services extension
- PowerShell 5.1 or later
- jq (for JSON processing in bash scripts)

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd mlops-doc-intelligence
   ```

2. **Configure Azure DevOps**
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
├── scripts/                     # PowerShell and bash scripts
│   ├── validate-model.ps1       # Model validation script
│   ├── copy-model.sh           # Model copying script
│   ├── backup-model.sh         # Model backup script
│   ├── test-model.ps1          # Model testing script
│   └── update-model-registry.ps1 # Registry update script
├── models/                     # Model configurations
│   └── example-model/
│       └── config.json         # Model configuration example
├── test-data/                  # Test documents for validation
├── docs/                       # Documentation
│   └── variable-groups.md      # Variable groups setup guide
└── README.md                   # This file
```

## Pipeline Stages

### 1. Model Validation
- Validates model configuration files
- Checks accuracy thresholds
- Verifies required properties
- Generates validation reports

### 2. QA Deployment
- Copies model from Dev to QA environment
- Runs integration tests
- Validates model performance
- Generates test reports

### 3. Production Deployment
- Creates backup of current production model
- Copies model from QA to Production
- Runs smoke tests
- Updates model registry

### 4. Post-Deployment
- Updates centralized model registry
- Sends deployment notifications
- Generates deployment reports

## Configuration

### Model Configuration
Each model requires a `config.json` file with the following structure:

```json
{
  "modelType": "document-intelligence-custom",
  "version": "1.0.0",
  "description": "Model description",
  "accuracy": 0.92,
  "trainingData": {
    "datasetName": "dataset-name",
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

### Environment Variables
Configure the following variable groups in Azure DevOps:

- `doc-intelligence-dev`
- `doc-intelligence-qa`
- `doc-intelligence-prod`

See [Variable Groups Configuration](docs/variable-groups.md) for detailed setup instructions.

## Testing

The pipeline includes comprehensive testing at each stage:

- **Validation Tests**: Configuration and accuracy validation
- **Integration Tests**: End-to-end model functionality
- **Smoke Tests**: Basic connectivity and availability

Test results are published in JUnit format for Azure DevOps integration.

## Monitoring and Logging

- Pipeline execution logs are available in Azure DevOps
- Model registry maintains deployment history
- Test results are tracked across environments
- Notifications sent to configured channels

## Security

- Service principal authentication with least privilege access
- Secrets managed through Azure DevOps variable groups
- Environment-specific access controls
- Audit trail for all deployments

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify service connection configuration
   - Check service principal permissions
   - Ensure subscription access

2. **Model Copy Failures**
   - Verify source model exists
   - Check target service availability
   - Validate network connectivity

3. **Test Failures**
   - Review test document availability
   - Check model accuracy thresholds
   - Verify service endpoints

### Support

For issues and questions:
1. Check Azure DevOps pipeline logs
2. Review test result outputs
3. Validate configuration files
4. Contact the MLOps team

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
