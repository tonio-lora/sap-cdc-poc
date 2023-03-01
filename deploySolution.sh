# Try and determine if we're executing from within the Azure Cloud Shell
if [ ! "${AZUREPS_HOST_ENVIRONMENT}" = "cloud-shell/1.0" ]; then
    echo "ERROR: It doesn't appear like your executing this from the Azure Cloud Shell. Please use the Azure Cloud Shell at https://shell.azure.com" | tee -a deploySynapse.log
    exit 1;
fi

# Try and get a token to validate that we're logged into Azure CLI
aadToken=$(az account get-access-token --resource=https://dev.azuresynapse.net --query accessToken --output tsv 2>&1)
if echo "$aadToken" | grep -q "ERROR"; then
    echo "ERROR: You don't appear to be logged in to Azure CLI. Please login to the Azure CLI using 'az login'" | tee -a deploySynapse.log
    exit 1;
fi

# Get environment details
azureSubscriptionName=$(az account show --query name --output tsv 2>&1)
azureSubscriptionID=$(az account show --query id --output tsv 2>&1)
azureUsername=$(az account show --query user.name --output tsv 2>&1)
azureUsernameObjectId=$(az ad user show --id $azureUsername --query objectId --output tsv 2>&1)

# Update Bicep AD Admin user if they aren't configured by the user
sed -i "s/REPLACE_SYNAPSE_AZURE_AD_ADMIN_OBJECT_ID/${azureUsernameObjectId}/g" ./main.parameters.json

# Check if there was a Bicep deployment
bicepDeploymentCheck=$(az deployment sub show --name Azure-Synapse-SAP-CDC-PoC --query properties.provisioningState --output tsv 2>&1)
if [ "$bicepDeploymentCheck" == "Succeeded" ]; then
    deploymentType="bicep"
elif [ "$bicepDeploymentCheck" == "Failed" ] || [ "$bicepDeploymentCheck" == "Canceled" ]; then
    echo "ERROR: It looks like a Bicep deployment was attempted, but failed." | tee -a deploySynapse.log
    exit 1;
fi

# Run Bicep deployment
echo "Starting Bicep deployment"
az deployment sub create  --name Azure-Synapse-SAP-CDC-PoC --template-file ./main.bicep --parameters ./main.parameters.json

#
# Part 2: Post-Deployment Configuration
#

# Get the output variables from the Bicep deployment
resourceGroup=$(az deployment sub show --name Azure-Synapse-SAP-CDC-PoC --query properties.parameters.resource_group_name.value --output tsv 2>&1)
synapseAnalyticsWorkspaceName=$(az deployment sub show --name Azure-Synapse-SAP-CDC-PoC --query properties.outputs.synapse_analytics_workspace_name.value --output tsv 2>&1)
synapseAnalyticsSQLAdmin=$(az deployment sub show --name Azure-Synapse-SAP-CDC-PoC --query properties.outputs.synapse_sql_administrator_login.value --output tsv 2>&1)
synapseAnalyticsSQLAdminPassword=$(az deployment sub show --name Azure-Synapse-SAP-CDC-PoC --query properties.outputs.synapse_sql_administrator_login_password.value --output tsv 2>&1)
datalakeName=$(az deployment sub show --name Azure-Synapse-SAP-CDC-PoC --query properties.outputs.datalake_name.value --output tsv 2>&1)
datalakeKey=$(az deployment sub show --name Azure-Synapse-SAP-CDC-PoC --query properties.outputs.datalake_key.value --output tsv 2>&1)

echo "Deployment Type: ${deploymentType}" | tee -a deploySynapse.log
echo "Azure Subscription: ${azureSubscriptionName}" | tee -a deploySynapse.log
echo "Azure Subscription ID: ${azureSubscriptionID}" | tee -a deploySynapse.log
echo "Azure AD Username: ${azureUsername}" | tee -a deploySynapse.log
echo "Synapse Analytics Workspace Resource Group: ${resourceGroup}" | tee -a deploySynapse.log
echo "Synapse Analytics Workspace: ${synapseAnalyticsWorkspaceName}" | tee -a deploySynapse.log
echo "Synapse Analytics SQL Admin: ${synapseAnalyticsSQLAdmin}" | tee -a deploySynapse.log
echo "Data Lake Name: ${datalakeName}" | tee -a deploySynapse.log

## Add additional config steps

echo "Deployment complete!" | tee -a deploySynapse.log
