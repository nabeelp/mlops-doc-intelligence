#!/bin/bash

# Azure Document Intelligence Model Copy Script
# Usage: ./copy-model.sh <source_service> <target_service> <model_name> <target_resource_group>

set -e

SOURCE_SERVICE=$1
TARGET_SERVICE=$2
MODEL_NAME=$3
TARGET_RESOURCE_GROUP=$4

if [ $# -ne 4 ]; then
    echo "Usage: $0 <source_service> <target_service> <model_name> <target_resource_group>"
    exit 1
fi

echo "Starting model copy operation..."
echo "Source Service: $SOURCE_SERVICE"
echo "Target Service: $TARGET_SERVICE"
echo "Model Name: $MODEL_NAME"
echo "Target Resource Group: $TARGET_RESOURCE_GROUP"

# Function to check if a service exists
check_service_exists() {
    local service_name=$1
    local resource_group=$2
    
    echo "Checking if service $service_name exists..."
    if az cognitiveservices account show --name "$service_name" --resource-group "$resource_group" >/dev/null 2>&1; then
        echo "✓ Service $service_name found"
        return 0
    else
        echo "✗ Service $service_name not found in resource group $resource_group"
        return 1
    fi
}

# Function to get service key
get_service_key() {
    local service_name=$1
    local resource_group=$2
    
    echo "Getting access key for $service_name..."
    az cognitiveservices account keys list --name "$service_name" --resource-group "$resource_group" --query "key1" -o tsv
}

# Function to get service endpoint
get_service_endpoint() {
    local service_name=$1
    local resource_group=$2
    
    echo "Getting endpoint for $service_name..."
    az cognitiveservices account show --name "$service_name" --resource-group "$resource_group" --query "properties.endpoint" -o tsv
}

# Function to copy model using REST API
copy_model() {
    local source_endpoint=$1
    local source_key=$2
    local target_endpoint=$3
    local target_key=$4
    local model_name=$5
    
    echo "Copying model $model_name from source to target..."
    
    # First, get the model from source
    echo "Retrieving model from source service..."
    source_model_response=$(curl -s -X GET \
        "$source_endpoint/formrecognizer/documentModels/$model_name" \
        -H "Ocp-Apim-Subscription-Key: $source_key" \
        -H "Content-Type: application/json")
    
    if [ $? -ne 0 ]; then
        echo "✗ Failed to retrieve model from source service"
        exit 1
    fi
    
    echo "✓ Model retrieved from source service"
    
    # Extract model definition
    model_definition=$(echo "$source_model_response" | jq -r '.modelDefinition // .docTypes')
    
    if [ "$model_definition" == "null" ]; then
        echo "✗ Unable to extract model definition from source"
        exit 1
    fi
    
    # Create model in target service
    echo "Creating model in target service..."
    
    # Prepare the request body for model creation
    request_body=$(cat <<EOF
{
    "modelId": "$model_name",
    "description": "Model copied from $SOURCE_SERVICE",
    "modelDefinition": $model_definition
}
EOF
)
    
    # Submit model creation request
    create_response=$(curl -s -X POST \
        "$target_endpoint/formrecognizer/documentModels:build" \
        -H "Ocp-Apim-Subscription-Key: $target_key" \
        -H "Content-Type: application/json" \
        -d "$request_body")
    
    if [ $? -eq 0 ]; then
        echo "✓ Model copy initiated successfully"
        
        # Extract operation ID for tracking
        operation_id=$(echo "$create_response" | jq -r '.operationId // .operation')
        
        if [ "$operation_id" != "null" ] && [ -n "$operation_id" ]; then
            echo "Operation ID: $operation_id"
            echo "You can track the progress using: az cognitiveservices account operation show --name $TARGET_SERVICE --resource-group $TARGET_RESOURCE_GROUP --operation-id $operation_id"
        fi
    else
        echo "✗ Failed to initiate model copy"
        echo "Response: $create_response"
        exit 1
    fi
}

# Main execution
echo "Validating Azure CLI login..."
if ! az account show >/dev/null 2>&1; then
    echo "✗ Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi

echo "✓ Azure CLI authenticated"

# Note: For simplicity, we're assuming both services are in the same resource group
# In a real scenario, you might need different resource groups
SOURCE_RESOURCE_GROUP=$TARGET_RESOURCE_GROUP

# Check if source service exists
if ! check_service_exists "$SOURCE_SERVICE" "$SOURCE_RESOURCE_GROUP"; then
    exit 1
fi

# Check if target service exists
if ! check_service_exists "$TARGET_SERVICE" "$TARGET_RESOURCE_GROUP"; then
    exit 1
fi

# Get service credentials
SOURCE_KEY=$(get_service_key "$SOURCE_SERVICE" "$SOURCE_RESOURCE_GROUP")
TARGET_KEY=$(get_service_key "$TARGET_SERVICE" "$TARGET_RESOURCE_GROUP")
SOURCE_ENDPOINT=$(get_service_endpoint "$SOURCE_SERVICE" "$SOURCE_RESOURCE_GROUP")
TARGET_ENDPOINT=$(get_service_endpoint "$TARGET_SERVICE" "$TARGET_RESOURCE_GROUP")

if [ -z "$SOURCE_KEY" ] || [ -z "$TARGET_KEY" ] || [ -z "$SOURCE_ENDPOINT" ] || [ -z "$TARGET_ENDPOINT" ]; then
    echo "✗ Failed to retrieve service credentials or endpoints"
    exit 1
fi

echo "✓ Service credentials and endpoints retrieved successfully"

# Perform the model copy
copy_model "$SOURCE_ENDPOINT" "$SOURCE_KEY" "$TARGET_ENDPOINT" "$TARGET_KEY" "$MODEL_NAME"

echo "Model copy operation completed successfully!"
echo "Please verify the model is available in the target service: $TARGET_SERVICE"
