#!/bin/bash

# Azure Document Intelligence Model Backup Script
# Usage: ./backup-model.sh <service_name> <model_name> <resource_group>

set -e

SERVICE_NAME=$1
MODEL_NAME=$2
RESOURCE_GROUP=$3

if [ $# -ne 3 ]; then
    echo "Usage: $0 <service_name> <model_name> <resource_group>"
    exit 1
fi

echo "Starting model backup operation..."
echo "Service Name: $SERVICE_NAME"
echo "Model Name: $MODEL_NAME"
echo "Resource Group: $RESOURCE_GROUP"

# Create backup directory with timestamp
BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backup directory: $BACKUP_DIR"

# Function to get service key
get_service_key() {
    local service_name=$1
    local resource_group=$2
    
    az cognitiveservices account keys list --name "$service_name" --resource-group "$resource_group" --query "key1" -o tsv
}

# Function to get service endpoint
get_service_endpoint() {
    local service_name=$1
    local resource_group=$2
    
    az cognitiveservices account show --name "$service_name" --resource-group "$resource_group" --query "properties.endpoint" -o tsv
}

# Function to backup model
backup_model() {
    local endpoint=$1
    local key=$2
    local model_name=$3
    local backup_dir=$4
    
    echo "Backing up model $model_name..."
    
    # Get model information
    echo "Retrieving model information..."
    model_info=$(curl -s -X GET \
        "$endpoint/documentintelligence/documentModels/$model_name?api-version=2024-11-30" \
        -H "Ocp-Apim-Subscription-Key: $key" \
        -H "Content-Type: application/json")
    
    if [ $? -ne 0 ]; then
        echo "✗ Failed to retrieve model information"
        exit 1
    fi

    # Check if the mode_info contains an error
    if [[ "$model_info" == *"error"* ]]; then
        echo "✗ Model not found or an error occurred: $model_info"
        exit 1
    fi
    
    # Save model information to backup directory (no jq formatting)
    echo "$model_info" > "$backup_dir/${model_name}_model_info.json"
    if [ $? -eq 0 ]; then
        echo "✓ Model information backed up to $backup_dir/${model_name}_model_info.json"
    else
        echo "✗ Failed to save model information"
        exit 1
    fi
    
    # Create backup metadata
    backup_metadata=$(cat <<EOF
{
    "backupTimestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "sourceService": "$SERVICE_NAME",
    "resourceGroup": "$RESOURCE_GROUP",
    "modelName": "$model_name",
    "backupLocation": "$backup_dir",
    "backupFiles": [
        "${model_name}_model_info.json"
    ]
}
EOF
)
    echo "$backup_metadata" > "$backup_dir/backup_metadata.json"
    echo "✓ Backup metadata saved to $backup_dir/backup_metadata.json"
}

# Main execution
echo "Validating Azure CLI login..."
if ! az account show >/dev/null 2>&1; then
    echo "✗ Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi

echo "✓ Azure CLI authenticated"

# Check if service exists
echo "Checking if service $SERVICE_NAME exists..."
if ! az cognitiveservices account show --name "$SERVICE_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "✗ Service $SERVICE_NAME not found in resource group $RESOURCE_GROUP"
    exit 1
fi

echo "✓ Service $SERVICE_NAME found"

# Get service credentials
SERVICE_KEY=$(get_service_key "$SERVICE_NAME" "$RESOURCE_GROUP")
SERVICE_ENDPOINT=$(get_service_endpoint "$SERVICE_NAME" "$RESOURCE_GROUP")

if [ -z "$SERVICE_KEY" ] || [ -z "$SERVICE_ENDPOINT" ]; then
    echo "✗ Failed to retrieve service credentials or endpoint"
    exit 1
fi

echo "✓ Service credentials and endpoint retrieved successfully"

# Perform the backup
backup_model "$SERVICE_ENDPOINT" "$SERVICE_KEY" "$MODEL_NAME" "$BACKUP_DIR"

echo "Model backup operation completed successfully!"
echo "Backup location: $BACKUP_DIR"
echo "To restore this model, you can use the backed up configuration files."
