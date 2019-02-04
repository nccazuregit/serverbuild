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
$vmNames =  @("Deteteme1") # e.g. @("Server1","Server2","Server3") !!!!!! REMEMBER THE 15 CHARACTER LIMIT FOR SERVER NAMES !!!!!!
$avsetName = ''
$resourceGroupName = ''
$vmSize = '' 
$vmOSVer = '2016-Datacenter'
$vNetRG ='' # the name of the resource group containing the VNET below
$VnetName ='' # the name of the VNET containing the subnet below
$SubnetName = '' #
$DomaintoJoin = "" # e.g 'nccadmin.ad.nottscc.gov.uk' leave this value empty to have server join a workgroup
$domainUser = "rf22-adm@nccadmin.ad.nottscc.gov.uk" 
$domainUserPWD = convertto-securestring "P@ssW0rD!" -asplaintext -force # do not amend this
$TagApplicationOwner = "rf22"
$TagBusinessService =""
$TagCostCentre = ""
$TagDepartmentOwner = "ICT"
$TagEnvironment = "DEV"
$TagFullVMBackup = "Yes"
$TagRoleFunction = "ADDS"

#Do not change the paths below unless you move the files also.
$template = 'H:\_Projects\_Cloud\_ARM_Templates\NCC vm build templates\Dev Scripts\_Basic-VM-AVSET\Basic-VM-AVSET.json'

$context =Connect-AzureRmAccount # connect to azure with your credentials
#Specify which subscription to use

$AzureInfo = (Get-AzureRmSubscription -ErrorAction Stop | Out-GridView -Title 'Select a Subscription/Tenant ID for deployment...' -PassThru)
Select-AzureRmSubscription -SubscriptionId $AzureInfo.SubscriptionId -TenantId $AzureInfo.TenantId -ErrorAction Stop| Out-Null

$objRegion = (Get-AzureRmLocation -ErrorAction Stop | Out-GridView -Title 'Select the region where the VM will be deployed to...' -PassThru)
$objSA = (get-azurermstorageaccount | where resourcegroupname -Like *diag* | where location -EQ $objRegion.Location -ErrorAction Stop | Out-GridView -Title 'Select the storage account to be used for Boot Diagnostics' -PassThru)
$sauri =$objSA.PrimaryEndpoints.Blob

#Select desired RG name from list
if (!$resourceGroupName) {
    $objRG = (Get-AzureRmResourceGroup -ErrorAction Stop | Out-GridView -Title 'Select a resource group for deployment...' -PassThru)
    $resourceGroupName = $objRG.ResourceGroupName
}

if (!$avsetName) {
    $objAVSET = (Get-AzureRmAvailabilitySet -ResourceGroupName $objRG.ResourceGroupName -ErrorAction Stop | Out-GridView -Title 'Select a resource group for deployment...' -PassThru)
    $avsetName = $objAVSET.name
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
    $additionalParameters['newVMRegion'] = $objRegion.Location
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
    $additionalParameters['AVset'] = $avsetName
    $additionalParameters['DataDiskCount'] = 1
    $additionalParameters['DataDiskGB'] = 100
    #$additionalParameters['skipExtensions'] = "yes"

    
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

