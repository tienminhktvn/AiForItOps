# Load variables from env.conf
$envFile = Join-Path $PSScriptRoot 'env.conf'
if (!(Test-Path $envFile)) {
	Write-Error "Environment file env.conf not found in $PSScriptRoot."
	exit 1
}
$envVars = @{}
foreach ($line in Get-Content $envFile) {
	if ($line -match '^(\w+)=(.+)$') {
		$envVars[$matches[1]] = $matches[2]
	}
}
$resourceGroup = $envVars['RESOURCE_GROUP']
$location = $envVars['LOCATION']
$aksName = $envVars['AKS_NAME']
$acrName = $envVars['ACR_NAME']
$nodepoolName = $envVars['NODEPOOL_NAME']

#Create new User-Assigned Managed Identity
$identityName = "$aksName-identity"
# az identity create --resource-group $resourceGroup --name $identityName --location $location
$identityId = az identity show --resource-group $resourceGroup --name $identityName --query id -o tsv

# # Create AKS cluster, attach ACR, enable Key Vault CSI driver addon, and assign managed identity
# az aks create --resource-group $resourceGroup --name $aksName --node-count 2 --node-vm-size Standard_D2s_v3 --network-plugin azure --no-ssh-key -x --attach-acr $acrName --enable-addons azure-keyvault-secrets-provider --assign-identity $identityId

# Retrieve the default node pool's VMSS infrastructure details
Write-Host "Retrieving AKS infrastructure details..." -ForegroundColor Cyan
$VMSSresourceGroup = az aks show --resource-group $resourceGroup --name $aksName --query "nodeResourceGroup" -o tsv
$VMSSnodepoolName  = az vmss list --resource-group $VMSSresourceGroup --query "[0].name" -o tsv

if ([string]::IsNullOrEmpty($VMSSnodepoolName)) {
    Write-Error "No VMSS found in Resource Group $VMSSresourceGroup!"
    exit 1
}

Write-Host "Detected VMSS: $VMSSnodepoolName" -ForegroundColor Green

# Assign the Managed Identity to the current VMSS for the Key Vault CSI Secret Driver
Write-Host "Assigning Managed Identity to VMSS..." -ForegroundColor Yellow
az vmss identity assign --resource-group $VMSSresourceGroup --name $VMSSnodepoolName --identities $identityId

Write-Host "Updating VMSS instances to apply identity changes..." -ForegroundColor Yellow
az vmss update-instances --resource-group $VMSSresourceGroup --name $VMSSnodepoolName --instance-ids *

# Retrieve and merge AKS credentials into local Kubeconfig
Write-Host "Merging AKS Kubeconfig..." -ForegroundColor Cyan
az aks get-credentials --resource-group $resourceGroup --name $aksName --overwrite-existing

# Label all existing nodes with 'workload=true' to satisfy the k8s nodeSelector constraint
Write-Host "Labeling Kubernetes nodes with workload=true..." -ForegroundColor Cyan
kubectl label nodes --all workload=true --overwrite

Write-Host "AKS lab configuration completed successfully!" -ForegroundColor Green