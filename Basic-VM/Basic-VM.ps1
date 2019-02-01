#############################################################################################################################################################################
#      1.0
#
#      Created by rf22
#      This script will create server(s) specified in the $vmNames array using an existing Resource Group and boot diagnostics SA. 
#      If $DomaintoJoin is set, the sever will be added to the domain name specified
#      The server will be added to an existing AVSET
#      Sophos will also be installed
#############################################################################################################################################################################

### Change the variables below as you see fit
$vmNames =  @("TestDJrf22") # e.g. @("Server1","Server2","Server3") !!!!!! REMEMBER THE 15 CHARACTER LIMIT FOR SERVER NAMES !!!!!!
$resourceGroupName = ''
$vmSize = '' 
$vmOSVer = '2016-Datacenter'
$vNetRG ='' # the name of the resource group containing the VNET below
$VnetName ='' # the name of the VNET containing the subnet below
$SubnetName = '' #
$DomaintoJoin = "" # e.g 'nccadmin.ad.nottscc.gov.uk' leave this value empty to have server join a workgroup
$domainUser = "rf22-adm@nccadmin.ad.nottscc.gov.uk" 
$domainUserPWD = convertto-securestring "P@ssW0rD!" -asplaintext -force # do not amend this
$TagApplicationOwner = "RF22"
$TagBusinessService =""
$TagCostCentre = ""
$TagDepartmentOwner = "ICT"
$TagEnvironment = "DEV"
$TagFullVMBackup = "Yes"
$TagRoleFunction = "Test domain join using my HA account"
$debug = "Yes"


#Do not change the paths below unless you move the files also.

$template = 'H:\_Projects\_Cloud\_ARM_Templates\NCC vm build templates\Master Scripts\Basic-VM\v7\Basic-VM.json'

$context =Connect-AzureRmAccount # connect to azure with your credentials
#Specify which subscription to use
$AzureInfo = (Get-AzureRmSubscription -ErrorAction Stop | Out-GridView -Title 'Select a Subscription/Tenant ID for deployment...' -PassThru)
Select-AzureRmSubscription -SubscriptionId $AzureInfo.SubscriptionId -TenantId $AzureInfo.TenantId -ErrorAction Stop| Out-Null

$objSA = (get-azurermstorageaccount | where resourcegroupname -Like *diag* -ErrorAction Stop | Out-GridView -Title 'Select the storage account to be used for Boot Diagnostics' -PassThru)
$sauri =$objSA.PrimaryEndpoints.Blob


#Select desired RG name from list
if (!$resourceGroupName) {
    $objRG = (Get-AzureRmResourceGroup -ErrorAction Stop | Out-GridView -Title 'Select a resource group for deployment...' -PassThru)
    $resourceGroupName = $objRG.ResourceGroupName
}


#Select desired VM size from list
if (!$vmSize) {
    $objVM = (Get-AzureRmVmSize -location $objRG.Location -ErrorAction Stop | Out-GridView -Title 'Select a VM Size for deployment...' -PassThru)
    $vmSize = $objVM.Name
}

#Get Vnet + Subnet
if (!$vNetRG) {
    $objvNetRG = (get-azurermvirtualnetwork -ErrorAction Stop | Out-GridView -Title 'Select the VNET for deployment...' -PassThru)
    $vNetRG = $objvNetRG.ResourceGroupName
    $VnetName = $objvNetRG.Name
    $ObjSubnet =($objvNetRG.Subnets  | Out-GridView -Title 'Select a Subnet...' -PassThru) 
    $SubnetName= $ObjSubnet.Name
}

#$SRNumber = Read-Host -Prompt 'Input SR number associated with this server creation' # Get SR number
#$secPassword = Read-Host -Prompt 'Input password for local admin account (nottsadmin)' -AsSecureString # Get password for 'nottsadmin' local user account$DomaintoJoin

if ($DomaintoJoin) { 
    $domainUser = Read-Host -Prompt 'Enter UPN of account used to join domain (e.g rf22-adm@nottscc.gov.uk)' # Get SR number
    $domainUserPWD = Read-Host -Prompt 'Input Password' -AsSecureString # Get password of account used to join domain
}



#Set engineer tag
$engSignature = $context.Context.Account.Id


foreach ($objVM in $vmNames)
{

    $additionalParameters = New-Object -TypeName Hashtable
    $additionalParameters['newVMName'] = $objVM
    $additionalParameters['TagDeployedBy'] = $engSignature
    $additionalParameters['TagBusinessService'] = $TagBusinessService
    $additionalParameters['TagCostCentre'] = $TagCostCentre
    $additionalParameters['TagDepartmentOwner'] = $TagDepartmentOwner
    $additionalParameters['TagEnvironment'] = $TagEnvironment
    $additionalParameters['TagRoleFunction'] = $TagRoleFunction
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
    $additionalParameters['DataDiskCount'] = 1
    $additionalParameters['DataDiskGB'] = 10
    $additionalParameters['StorageAccountType'] = "Premium_LRS"
  #  $additionalParameters['skipExtensions'] = $debug

    
    New-AzureRmResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $template `
        @additionalParameters `
        -Verbose -Force

{
    test-AzureRmResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $template `
        @additionalParameters `
        -Verbose
}
    

}

