<#
.DESCRIPTION
Script made for use in Azure Automation Accounts.
Creates snapshots of all VHD's in specified storage account 
and copies snapshots to new storage container.
Deletes snapshots on source container if older then 2 day.
#>
Import-Module -Name AzureRM.Resources

# Get all variables from Runbook Assets
# Set source context
$SubId = Get-AutomationVariable -Name 'SubscriptionId'
$srcAccountName = Get-AutomationVariable -Name 'srcAccountName'
$srcKey = Get-AutomationVariable -Name 'srcKey'
$srcContainerName = Get-AutomationVariable -Name 'vhds'
$srcContext = New-AzureStorageContext -StorageAccountName $srcAccountName -StorageAccountKey $srcKey

# Set destination context
$dstAccountName = Get-AutomationVariable -Name 'dstAccountName'
$dstKey = Get-AutomationVariable -Name 'dstKey'
$dstContainerName = 'vhd-snapshots'
$dstContext = New-AzureStorageContext -StorageAccountName $dstAccountName -StorageAccountKey $dstKey

function CreateSnapshotFromBlob {
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

    # Get Blob reference and create snapshots of VHD's
    $blobs = Get-AzureStorageBlob -Container $srcContainerName -Context $srcContext | Where-Object {$_.Name -like '*.vhd'}
    foreach ($blob in $blobs) {
        if (!$blob.ICloudBlob.IsSnapshot) {
            $blob.ICloudBlob.CreateSnapshot()
            Write-Host "Creating snapshot of " $blob.Name
        }
    }

    # Copy snapshot to new container
    $dstContainer = Get-AzureStorageContainer -Name $dstContainerName -Context $dstContext -ErrorAction SilentlyContinue
    if (!$dstContainer) {
        Write-Host "Creating destination container $dstContainerName"
        New-AzureStorageContainer -Name $dstContainerName -Context $dstContext
    }
    $container = Get-AzureStorageContainer -Name $srcContainerName -Context $srcContext
    $listOfBlobs = $container.CloudBlobContainer.ListBlobs($BlobName, $true, "Snapshots")
    foreach ($CloudBlockBlob in $listOfBlobs) {
        $CloudBlockBlob.FetchAttributes()
        if ($CloudBlockBlob.IsSnapshot) {
            $TimeDate = Get-Date -Format dd-MM-yyyy
            $newBlobName = $($CloudBlockBlob.Metadata["MicrosoftAzureCompute_DiskName"] + "-$TimeDate.vhd")
            $copyBlob = Start-AzureStorageBlobCopy `
                -CloudBlob $CloudBlockBlob `
                -DestContainer $dstContainerName `
                -DestBlob $newBlobName `
                -Context $dstContext `
                -Force
            $status = $copyBlob | Get-AzureStorageBlobCopyState
            if ($status.Status -eq "Pending") {
                Start-Sleep -Seconds 10
                Write-Host $($CloudBlockBlob.Metadata["MicrosoftAzureCompute_DiskName"] + " is " + $status.Status)
            } 
        }
    }

    # Delete old snapshots if older then 2 days
    # Should involve more advanced checking
    Write-Host "Checking for old snapshots .."
    foreach ($CloudBlockBlob in $ListOfBLobs) {
        $CloudBlockBlob.FetchAttributes()
        if ($CloudBlockBlob.IsSnapshot -and $CloudBlockBlobSnapshot.SnapshotTime.Date -le (Get-Date).AddDays(-2)) {
            $CloudBlockBlobSnapshot = $CloudBlockBlob
            Write-Host "Deleting old snapshot of  " $CloudBlockBlob.Metadata["MicrosoftAzureCompute_DiskName"]
            $CloudBlockBlobSnapshot.SnapshotTime
            $CloudBlockBlobSnapshot.Delete() 
        }
    }
}
CreateSnapshotFromBlob