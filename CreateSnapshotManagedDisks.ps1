<#
.DESCRIPTION

#>
Import-Module -Name AzureRM.Resources
Import-Module -Name AzureRM.Compute
function CreateSnapshotManagedDisks (OptionalParameters) {

    # Get all variables from Runbook Assets
    $rgName = Get-AutomationVariable -Name 'ResourceGroup'
    $location = 'westeurope'
    $SubId = Get-AutomationVariable -Name 'SubscriptionId'
    # Set source context
    $srcAccountName = Get-AutomationVariable -Name 'srcAccountName'
    $srcKey = Get-AutomationVariable -Name 'srcKey'
    $srcContainerName = Get-AutomationVariable -Name 'vhds'
    $srcContext = New-AzureStorageContext -StorageAccountName $srcAccountName -StorageAccountKey $srcKey

    # Set destination context
    $dstAccountName = Get-AutomationVariable -Name 'dstAccountName'
    $dstKey = Get-AutomationVariable -Name 'dstKey'
    $dstContainerName = 'vhd-snapshots'
    $dstContext = New-AzureStorageContext -StorageAccountName $dstAccountName -StorageAccountKey $dstKey

    # Connect to ARM Resources
    $connectionName = "AzureRunAsConnection"
  
    try {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

        "Logging in to Azure..."
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
        Set-AzureRmContext -SubscriptionId $SubId
    }
    catch {
        if (!$servicePrincipalConnection) {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        }
        else {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
    
    $vmList = Get-AzureRMVM 
}