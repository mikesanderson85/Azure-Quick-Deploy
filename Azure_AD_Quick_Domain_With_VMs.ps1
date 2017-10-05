if (!$AzureAccount) {
$AzureAccount = Login-AzureRmAccount
}
 
$subs = Get-AzureRmSubscription 
Select-AzureRmSubscription -TenantId $subs[0].TenantId -SubscriptionId $subs[0].SubscriptionId
 
$rgName ='RG-MAGICMIKE' 
$location = 'West Europe'
 
# Create New Resource Group
 
try {     
    Get-AzureRmResourceGroup -Name $rgName -Location $location -ErrorAction Stop     
    Write-Host 'RG already exists... skipping' -foregroundcolor yellow -backgroundcolor red 
} catch {     
    New-AzureRmResourceGroup -Name $rgName -Location $location 
}

$password = 'Password_001'
 
$newDomainParams = @{     
   'Name' = 'magicmikead' # Deployment name     
   'ResourceGroupName' = $rgName     
   'TemplateUri' = 'https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/active-directory-new-domain/azuredeploy.json'     
   'adminUsername' = 'adadmin'     
   'domainName' = 'ad.magicmike.com' # The FQDN of the AD Domain created       
   'dnsPrefix' = 'magicmikead' # The DNS prefix for the public IP address used by the Load Balancer       
   'adminPassword' = ConvertTo-SecureString $password -asplaintext -force
}
New-AzureRmResourceGroupDeployment @newDomainParams

# Display the RDP connection string to the loadbalancer
 
$rdpVM = Get-AzureRmPublicIpAddress -Name adPublicIP -ResourceGroupName $rgName 
$rdpString = $rdpVM.DnsSettings.Fqdn + ':3389'
 
Write-Host 'Connect to the VM using the URL below:' -foregroundcolor yellow -backgroundcolor red 
Write-Host $rdpString

if (!$AzureAccount) {
$AzureAccount = Login-AzureRmAccount
}

$subs = Get-AzureRmSubscription 
Select-AzureRmSubscription -TenantId $subs[0].TenantId -SubscriptionId $subs[0].SubscriptionId

$numberOfComputerstoCreate = 6

# Create New Resource Group
# Checks to see if RG exists
# -ErrorAction Stop added to Get-AzureRmResourceGroup cmdlet to treat errors as terminating
 
try {
    Get-AzureRmResourceGroup -Name $rgName -Location $location -ErrorAction Stop
} catch {
    Write-Host "Resource Group doesn't exist" -foregroundcolor yellow -backgroundcolor red
    throw 'An error occurred'
}

For ($i = 1;$i -le $numberOfComputerstoCreate;$i++){
$rgName ='RG-MAGICMIKE'
$location = 'West Europe'
$domainPassword = 'Password_001'
$vmPassword = 'Password_001'
$vmName = "MAGICMIKE$i"

 
# Check availability of DNS name
 
If ((Test-AzureRmDnsAvailability -DomainQualifiedName $vmName -Location $location) -eq $false) {
        Write-Host 'The DNS label prefix for the VM is already in use' -foregroundcolor yellow -backgroundcolor red
        throw 'An error occurred'
}
 
$newVMParams = @{
    'ResourceGroupName' = $rgName
    'TemplateURI' = 'https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/201-vm-domain-join/azuredeploy.json'
    'existingVNETName' = 'adVNET'
    'existingSubnetName' = 'adSubnet'
    'dnsLabelPrefix' = $vmName
    'vmSize' = 'Basic_A1'
    'domainToJoin' = 'ad.magicmike.com'
    'domainUsername' = 'adadmin'
    'domainPassword' = convertto-securestring $domainPassword -asplaintext -force
    'ouPath' = ''
    'domainJoinOptions' = 3
    'vmAdminUsername' = 'azureuser'
    'vmAdminPassword' = convertto-securestring $vmPassword -asplaintext -force
}
New-AzureRmResourceGroupDeployment @newVMParams

# Display the RDP connection string
 
$rdpVM = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName
 
$rdpString = $vmName + '.' + $rdpVM.Location + '.cloudapp.azure.com'
Write-Host 'Connect to the VM using the URL below:' -foregroundcolor yellow -backgroundcolor red 
Write-Host $rdpString
}