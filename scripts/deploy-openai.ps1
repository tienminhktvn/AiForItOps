# Deploy Azure OpenAI resource using values from env.conf

# Load environment variables
$envFile = Join-Path $PSScriptRoot '../scripts/env.conf'
if (!(Test-Path $envFile)) {
    Write-Error "Environment file env.conf not found."
    exit 1
}
$envVars = @{}
foreach ($line in Get-Content $envFile) {
    if ($line -match '^([A-Z0-9_]+)=(.+)$') {
        $envVars[$matches[1]] = $matches[2]
    }
}

$resourceGroup = $envVars['RESOURCE_GROUP']
$location = $envVars['OPENAI_LOCATION']
$openaiName = $envVars['OPENAI_RESOURCE_NAME']
$deploymentName = $envVars['OPENAI_DEPLOYMENT_NAME']
$modelName = $envVars['OPENAI_MODEL_NAME']
$modelVersion = $envVars['OPENAI_MODEL_VERSION']

# Create Azure OpenAI resource
az cognitiveservices account create `
    --name $openaiName `
    --resource-group $resourceGroup `
    --location $location `
    --kind OpenAI `
    --sku s0

Write-Host "Azure OpenAI resource '$openaiName' deployed to resource group '$resourceGroup' in location '$location'."

az cognitiveservices account deployment create `
  --resource-group $resourceGroup `
  --name $openaiName `
  --deployment-name $deploymentName `
  --model-name $modelName `
  --model-version $modelVersion `
  --model-format OpenAI `
  --sku-name "GlobalStandard" `
  --sku-capacity 1

Write-Host "Azure OpenAI deployment '$deploymentName' deployed to Azure OpenAI '$openaiName' in location '$location'."