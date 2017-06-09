<#
.DESCRIPTION
Script made for use in Azure Automation Accounts.
Creates snapshots of Managed disks in specified 
Subsctiption ID and Resource Group and copies 
snapshots to new container.
#>
Import-Module -Name AzureRM.Resources
Import-Module -Name AzureRM.Compute
function CreateSnapshotManagedDisks {

    # Get all variables from Runbook Assets
    $SubId = Get-AutomationVariable -Name 'SubscriptionId'
    $rgName = Get-AutomationConnection -Name 'ResourceGroup'
    $dstAccountName = Get-AutomationVariable -Name 'dstAccountName'
    $dstKey = Get-AutomationVariable -Name 'dstKey'
    $dstContainerName = 'vhd-snapshots'
    # Set destination context
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
    
    $location = 'westeurope'
    $sasExpiryDuration = '3600'
    $diskList = Get-AzureRMDisk -ResourceGroupName $rgName
    # Check if container exists
    $dstContainer = Get-AzureStorageContainer -Name $dstContainerName -Context $dstContext -ErrorAction SilentlyContinue
    if (!$dstContainer){
        Write-Host "Creating destination container $dstContainerName"
        New-AzureStorageContainer -Name $dstContainerName -Context $dstContext
    }
    # Create snapshots and copy to destination container
    foreach ($disk in $diskList) {
        $snapshotName = $($disk.Name + "_snapshot-" + $(Get-Date -Format dd-MM-yyyy))
        $snapshot = New-AzureRMSnapshotConfig -SourceUri $disk.id -CreateOption Copy -Location $location
        Write-Host "Creating snapshot of $disk.Name "
        New-AzureRmSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $rgName
        $sas = Grant-AzureRmSnapshotAccess `
            -ResourceGroupName $rgName `
            -SnapshotName $SnapshotName  `
            -DurationInSecond $sasExpiryDuration `
            -Access Read 
        $dstVHDFileName = $snapshotName
        $copyBlob = Start-AzureStorageBlobCopy `
            -AbsoluteUri $sas.AccessSAS `
            -DestContainer $dstContainerName `
            -DestContext $dstContext `
            -DestBlob $dstVHDFileName
        $status = $copyBlob | Get-AzureStorageBlobCopyState
        Write-Host $($dstVHDFileName + " is " + $status.Status)
    }
} 
CreateSnapshotManagedDisks