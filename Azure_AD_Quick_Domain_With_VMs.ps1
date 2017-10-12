<#
.SYNOPSIS
Automatically create a Domain with connected VMs in Azure.

.DESCRIPTION
Script will create a Domain with connected VMs depending on how many specified.

.PARAMETER rgName
The name of the resource group.

.PARAMETER location
The location the resource group should be created in (this can be subscription specific and the build may fail if the location is not available to you).

.PARAMETER deploymentName 
The name of Active Directory deployment.

.PARAMETER numberOfVMsToCreate 
The number of additional virtual machines to be created (not including the DC) that will be connected to the domain.

.PARAMETER adadmin 
The username for the Active Directory server.

.PARAMETER domainName 
The domain name of the deployment.

.PARAMETER adDNSPrefix 
The DNS name of the AD Server.

.PARAMETER dcSize 
The required size of the AD VM.

.PARAMETER vmUser 
The username for the additional VMs.

.PARAMETER vmName 
The name of the additional virtual machines. The name will be suffixed with a number depending on how many are specified. E.g. If a vmName of 'computer' is specified and 3 VMs are specified to be created they will be named: computer1, computer2, computer3.

.PARAMETER vmSuffixStartNumber  
The number the VMname suffix should begin with.

.PARAMETER vmSize  
The required size of the additional VMs.

.PARAMETER autoShutdownTime
The time autoshutdown should start (useful if you have limited credits on your account). Auto shutdown is only enabled if a time has been set. 

.EXAMPLE
		PS C:\Windows\system32> ."\Azure_AD_Quick_Domain_With_VMs.ps1" -rgName RG-GROUP1 -location "West Europe" -deploymentName addeployment -numberOfVMsToCreate 2 -adadmin adadmin -domainName domain.com -adDNSPrefix group1ad -dcSize Standard_A1 -vmUser azureuser -vmName computer -vmSuffixStartNumber 1 -vmSize Basic_A1 -autoShutdownTime 18:34
		
		Create a domain named domain.com with 2 domain joined VM's

.NOTES
Author: Michael Sanderson
Date: 05OCT2017
Updated: 11OCT2017
UpdNote: Added help
#>


[CmdletBinding()]
param
(
	$rgName = 'RG-MAGICMIKE',
	$location = 'West Europe',
	$deploymentName = 'magicmikead',
	$numberOfVMsToCreate = 6,
	$adadmin = 'adadmin',
	$domainName = 'magicmike.com',
	$adDNSPrefix = 'magicmikead',
	$dcSize = 'Standard_A1',
	$vmUser = 'azureuser',
	$vmName = 'magicmike0',
	$vmSuffixStartNumber = 3,
	$vmSize = 'Basic_A1',
	$autoShutdownTime = '1830'
)

$domainPassword = Read-Host -assecurestring "Please enter your password for AD" #password for AD
$vmPassword = Read-Host -assecurestring "Please enter your password for VMs" #password for VM


if ($autoShutdownTime) {
	$autoShutdown = 'Enabled'
} else {
	$autoShutdown = 'Disabled'
}

if (!$AzureAccount) {
	$AzureAccount = Login-AzureRmAccount
}

$subs = Get-AzureRmSubscription
Select-AzureRmSubscription -TenantId $subs[0].TenantId -SubscriptionId $subs[0].SubscriptionId

# Create New Resource Group 
try {
	Get-AzureRmResourceGroup -Name $rgName -Location $location -ErrorAction Stop
	Write-Host 'RG already exists... skipping' -foregroundcolor yellow -backgroundcolor red
} catch {
	New-AzureRmResourceGroup -Name $rgName -Location $location
}

if (!(Get-AzureRmVM -Name $adDNSPrefix -ResourceGroupName $rgName -ErrorAction SilentlyContinue)) {
	$newDomainParams = @{
		'Name'				      = $deploymentName # Deployment name     
		'ResourceGroupName'	      = $rgName
		'TemplateUri'			  = 'https://raw.githubusercontent.com/mikesanderson85/PS-Azure-Quick-Deploy/master/azuredeploy_active_directory_new_domain.json'
		'adminUsername'		      = $adadmin
		'domainName'			  = $domainName # The FQDN of the AD Domain created       
		'dnsPrefix'			      = $adDNSPrefix # The DNS prefix for the public IP address used by the Load Balancer
		'adVMSize'			      = $dcsize
		'adminPassword'		      = $domainPassword
	}
	New-AzureRmResourceGroupDeployment @newDomainParams
	
	# Display the RDP connection string to the loadbalancer
	
	$rdpVM = Get-AzureRmPublicIpAddress -Name adPublicIP -ResourceGroupName $rgName
	$rdpString = $rdpVM.DnsSettings.Fqdn + ':3389'
	
	Write-Host 'Connect to the VM using the URL below:' -foregroundcolor yellow -backgroundcolor red
	Write-Host $rdpString
	
} else {
	Write-Host 'AD server name already exists. Skipping...' -foregroundcolor yellow -backgroundcolor red
}

if ($numberOfVMsToCreate -gt 0) {
	if (!$AzureAccount) {
		$AzureAccount = Login-AzureRmAccount
	}
	
	$subs = Get-AzureRmSubscription
	Select-AzureRmSubscription -TenantId $subs[0].TenantId -SubscriptionId $subs[0].SubscriptionId
	
	try {
		Get-AzureRmResourceGroup -Name $rgName -Location $location -ErrorAction Stop
	} catch {
		Write-Host "Resource Group doesn't exist" -foregroundcolor yellow -backgroundcolor red
		exit
	}
	
	For ($i = $vmSuffixStartNumber; $i -le $numberOfVMsToCreate; $i++) {
		
		$vmNewName = "$vmName$i"
		
		# Check availability of DNS name
		
		If ((Test-AzureRmDnsAvailability -DomainQualifiedName $vmNewName -Location $location) -eq $false) {
			Write-Host "The DNS label prefix, $vmNewName for the VM is already in use" -foregroundcolor yellow -backgroundcolor red
			exit
		}
		
		$newVMParams = @{
			'ResourceGroupName'	       = $rgName
			'TemplateURI'			   = 'https://raw.githubusercontent.com/mikesanderson85/PS-Azure-Quick-Deploy/master/azuredeploy_domain_joined_VM.json'
			'existingVNETName'		   = 'adVNET'
			'existingSubnetName'	   = 'adSubnet'
			'dnsLabelPrefix'		   = $vmNewName
			'vmSize'				   = $vmsize
			'domainToJoin'			   = $domainName
			'domainUsername'		   = $adadmin
			'autoShutdownEnabled'	   = $autoShutdown
			'autoShutdownTime'		   = $autoShutdownTime
			'domainPassword'		   = $domainPassword
			'ouPath'				   = ''
			'domainJoinOptions'	       = 3
			'vmAdminUsername'		   = $vmUser
			'vmAdminPassword'		   = $vmPassword
		}
		New-AzureRmResourceGroupDeployment @newVMParams
		
		# Display the RDP connection string
		
		$rdpVM = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmNewName
		
		$rdpString = $vmNewName + '.' + $rdpVM.Location + '.cloudapp.azure.com'
		Write-Host 'Connect to the VM using the URL below:' -foregroundcolor yellow -backgroundcolor red
		Write-Host $rdpString
	}
} else {
	Write-Host "No VM's will be created"
}

