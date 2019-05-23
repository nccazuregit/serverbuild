#############################################################################################################################################################################
#      1.0
#
#      Created by rf22
#      This script will create server(s) specified in the $vmNames array using the parameters gathered from the user
# 
#  
#############################################################################################################################################################################

#import presentation framework
Add-Type -AssemblyName PresentationCore,PresentationFramework
$ButtonType = [System.Windows.MessageBoxButton]::YesNo
$MessageIcon = [System.Windows.MessageBoxImage]::Question

### Do not change these variables
$DomaintoJoin = "" # e.g 'nccadmin.ad.nottscc.gov.uk' leave this value empty to have server join a workgroup
$domainUser = "userm@domain.gov.uk" 
$domainUserPWD = convertto-securestring "P@ssW0rD!" -asplaintext -force # do not amend this

### Change the variables below as you see fit
#$vmNames =  @("rftest02") # e.g. @("Server1","Server2","Server3") !!!!!! REMEMBER THE 15 CHARACTER LIMIT FOR SERVER NAMES !!!!!!
$vmNames = New-Object System.Collections.ArrayList
$resourceGroupName = ''
$vmSize = '' 
$vmOSVer = '2016-Datacenter'
$vNetRG ='' # the name of the resource group containing the VNET below
$VnetName ='' # the name of the VNET containing the subnet below
$SubnetName = '' #

#Change path below to point to location of 'Basic-VM.Json'
$template = 'C:\test\Basic-VM\Basic-VM.json'

$context =Connect-AzureRmAccount # connect to azure with your credentials

#Specify which subscription to use
$AzureInfo = (Get-AzureRmSubscription -ErrorAction Stop | Out-GridView -Title 'Select a Subscription/Tenant ID for deployment...' -PassThru)
Select-AzureRmSubscription -SubscriptionId $AzureInfo.SubscriptionId -TenantId $AzureInfo.TenantId -ErrorAction Stop| Out-Null

while($true)
    {
    $newVM = read-host "Enter the name of your new Virtual Machine, 15 characters or less [e.g. VMP-ADDS-DC-01]"
    if(($newVM -ne "") -AND ($newVM.Length -le 15)){
        $vmNames += $newVM
        if((Read-Host -Prompt ‘Do you want to add another server to the list[y/n]’) -ne 'y'){break}
    }
    else{Write-Host "Servername entered was invalid, try again!"}
}


#Specify which region to use
$objRegion = (Get-AzureRmLocation | where Location -Like *uk* -ErrorAction Stop | Out-GridView -Title 'Select the region where the VM will be deployed to...' -PassThru)

#Get URI of VM diagnostic storage account for the selected region and subscription
#$objSA = (get-azurermstorageaccount | where resourcegroupname -Like *diag* | where location -EQ $objRegion.Location -ErrorAction Stop | Out-GridView -Title 'Select the storage account to be used for Boot Diagnostics' -PassThru)
$objSA = get-azurermstorageaccount | where resourcegroupname -Like *diag* | where location -EQ $objRegion.Location
$sauri =$objSA.PrimaryEndpoints.Blob

#If new resource group is required, create one
if((Read-Host -Prompt ‘Do you want a new Resource Group [y/n]’) -eq 'y'){
    $resourceGroupName= read-Host "Enter the name of the new RG [e.g RG-ADDS-DC-MAN-UKS-01]"
    if($resourceGroupName -ne ""){
        Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorVariable notPresent -ErrorAction SilentlyContinue
        if ($notPresent){
            Write-host "Create a new rg!"
            New-AzureRmResourceGroup -Name $ResourceGroupName -Location $objRegion.Location
        }
    }
}


#If no resource group supplied Select desired RG name from list
if (!$resourceGroupName) {
    $objRG = (Get-AzureRmResourceGroup -ErrorAction Stop | Out-GridView -Title 'Select an existing resource group for deployment...' -PassThru)
    $resourceGroupName = $objRG.ResourceGroupName
}


#Select desired VM size from list
if (!$vmSize) {
    $objVM = (Get-AzureRmVmSize -location $objRegion.Location -ErrorAction Stop | Out-GridView -Title 'Select a VM Size for deployment...' -PassThru)
    $vmSize = $objVM.Name
}

#Get Vnet + Subnet
if (!$vNetRG) {
    $objvNetRG = (get-azurermvirtualnetwork | where location -EQ $objRegion.Location -ErrorAction Stop | Out-GridView -Title 'Select the VNET for deployment...' -PassThru)
    $vNetRG = $objvNetRG.ResourceGroupName
    $VnetName = $objvNetRG.Name
    $ObjSubnet =($objvNetRG.Subnets  | Out-GridView -Title 'Select a Subnet...' -PassThru) 
    $SubnetName= $ObjSubnet.Name
}

if((Read-Host -Prompt ‘Do you want to add the VM to a domain [y/n]’) -eq 'y'){
    $DomaintoJoin = Read-Host -Prompt ‘Enter the name of the domain [e.g. nccadmin.ad.nottscc.gov.uk]’ 
}

if ($DomaintoJoin) { 
    $domainUser = Read-Host -Prompt 'Enter UPN of account used to join domain (e.g rf22-adm@nottscc.gov.uk)' # Get SR number
    $domainUserPWD = Read-Host -Prompt 'Input Password' -AsSecureString # Get password of account used to join domain
}

if((Read-Host -Prompt ‘Do you want any data disks?[y/n]’) -eq 'y'){
    $DataDiskCount = read-Host "How many data disks do you want [e.g 2]"
    if($DataDiskCount -ge 1){$DataDiskSize = read-Host "And what size disks do you want in GB [e.g 200]"}
}

#Get Tag Values
$TagFullVMBackup = read-Host "Do you want a full VM backup [yes/no]"
$TagApplicationOwner = read-Host "Enter a valule for the ApplicationOwner Tag"
$TagBusinessService = read-Host "Enter a valule for the BusinessService Tag"
$TagCostCentre = read-Host "Enter a valule for the CostCentre Tag"
$TagDepartmentOwner = read-Host "Enter a valule for the DepartmentOwner Tag"
$TagEnvironment = read-Host "Enter a valule for the Environment Tag"
$TagRoleFunction = read-Host "Enter a valule for the RoleFunction Tag"


#Set engineer tag
$engSignature = $context.Context.Account.Id


foreach ($objVM in $vmNames)
{

    $additionalParameters = New-Object -TypeName Hashtable
    $additionalParameters['newVMName'] = $objVM
    $additionalParameters['newVMRegion'] = $objRegion.Location
    $additionalParameters['TagDeployedBy'] = $engSignature
    $additionalParameters['TagBusinessService'] = $TagBusinessService
    $additionalParameters['TagCostCentre'] = $TagCostCentre
    $additionalParameters['TagDepartmentOwner'] = $TagDepartmentOwner
    $additionalParameters['TagEnvironment'] = $TagEnvironment
    $additionalParameters['TagRoleFunction'] = $TagRoleFunction
    $additionalParameters['TagApplicationOwner'] = $TagApplicationOwner
    $additionalParameters['vNetRG'] = $vNetRG
    $additionalParameters['vNetName'] = $VnetName
    $additionalParameters['subnetName'] = $SubnetName
    $additionalParameters['vmSize'] = $vmSize
    $additionalParameters['diagSAURI'] = $sauri
    $additionalParameters['newVMAdminUserName'] = (Get-AzureKeyVaultSecret -vaultName "kv-automation-dev-01" -Name "localadminuser").SecretValueText
    $additionalParameters['newVMAdminPassword'] = (Get-AzureKeyVaultSecret -vaultName "kv-automation-dev-01" -Name "localadminpwd").SecretValue
    $additionalParameters['DomainJoinUPN'] = $domainUser
    $additionalParameters['DomainUserPWD'] = $domainUserPWD
    $additionalParameters['newVMDomain'] = $DomaintoJoin
    $additionalParameters['dscRegURL'] =  (Get-AzureKeyVaultSecret -vaultName "kv-automation-dev-01" -Name "dsc-registration-url").SecretValueText
    $additionalParameters['dscRegKey'] =  (Get-AzureKeyVaultSecret -vaultName "kv-automation-dev-01" -Name "dsc-registration-key").SecretValueText
    $additionalParameters['ScriptFileURI'] = (Get-AzureKeyVaultSecret -vaultName "kv-automation-dev-01" -Name "ScriptFileURI").SecretValueText
    $additionalParameters['ScriptFilename'] = (Get-AzureKeyVaultSecret -vaultName "kv-automation-dev-01" -Name "SophosScriptName").SecretValueText
    $additionalParameters['ScriptSAName'] = (Get-AzureKeyVaultSecret -vaultName "kv-automation-dev-01" -Name "SophosScriptSAName").SecretValueText
    $additionalParameters['ScriptSAKey'] = (Get-AzureKeyVaultSecret -vaultName "kv-automation-dev-01" -Name "SophosScriptSAKey").SecretValueText
    if(($DataDiskCount -ge 1) -and ($DataDiskSize -ge 1) ){
        $additionalParameters['DataDiskCount'] = $DataDiskCount
        $additionalParameters['DataDiskGB'] = $DataDiskSize
    }
    
    #$additionalParameters['StorageAccountType'] = 'Standard_LRS'


    
    New-AzureRmResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $template `
        @additionalParameters `
        -Verbose -Force

  

}



