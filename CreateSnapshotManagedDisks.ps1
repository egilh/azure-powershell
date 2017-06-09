<#
.DESCRIPTION

#>
Import-Module -Name AzureRM.Resources
Import-Module -Name AzureRM.Compute
function CreateSnapshotManagedDisks {

    # Get all variables from Runbook Assets
    $SubId = Get-AutomationVariable -Name 'SubscriptionId'
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
    
    $location = 'westeurope'
    $sasExpiryDuration = '3600'
    $diskList = Get-AzureRMDisk
    foreach ($disk in $diskList) {
        $snapshotName = $($disk.Name + "_snapshot-" + $(Get-Date -Format dd-MM-yyyy))
        $snapshot = New-AzureRMSnapshotConfig -SourceUri $disk.id -CreateOption Copy -Location $location
        New-AzureRmSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName
        $sas = Grant-AzureRmSnapshotAccess `
            -ResourceGroupName $ResourceGroupName `
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