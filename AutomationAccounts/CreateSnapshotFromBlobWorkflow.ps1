<#
.SYNOPSIS
Script made for use in Azure Automation Accounts.
Creates snapshots of all VHD's in specified storage account 
and copies snapshots to new storage container.
Deletes snapshots on source-container if older then 1 day.
#>
workflow CreateSnapshotFromBlob {

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
    $blob.ICloudBlob.CreateSnapshot()
    Write-Host "Creating snapshot of " + $blob.Name
  }

  # Copy snapshot to new container
  $container = Get-AzureStorageContainer -Name $srcContainerName -Context $srcContext
  $listOfBlobs = $container.CloudBlobContainer.ListBlobs($BlobName, $true, "Snapshots")

  foreach -Parallel ($CloudBlockBlob in $listOfBlobs) {
    if ($CloudBlockBlob.IsSnapshot) {
      $CloudBlockBlob.FetchAttributes()
      $TimeDate = Get-Date -Format dd-MM-yyyy
      $newBlobName = $CloudBlockBlob.Metadata["MicrosoftAzureCompute_VMName"] + "-$TimeDate.vhd"
      $blobCopy = Start-AzureStorageBlobCopy -CloudBlob $CloudBlockBlob -DestContainer $dstContainerName -DestBlob $newBlobName -Context $dstContext -Force
      $status = Get-AzureStorageBlobCopyState -CloudBlob $blobCopy.ICloudBlob -Context $srcContext
      while ($status.Status -eq "Pending")
      {
        Start-Sleep -Seconds 10
        Write-Host "$CloudBlockBlob  is "  $status.Status
      }
    }
  }
  
   # Delete old snapshots in source container if older then 1 day
  Write-Host "Checking for old snapshots .."
  foreach ($CloudBlockBlob in $ListOfBLobs) {
    if ($CloudBlockBlob.IsSnapshot -and $SnapShotTime -le (Get-Date).AddDays(-1)) {
      $CloudBlockBlobSnapshot = $CloudBlockBlob
      $SnapShotTime = $CloudBlockBlobSnapshot.SnapshotTime.Date
      $CloudBlockBlob.FetchAttributes()
      Write-Host "Deleting old snapshot of  " $CloudBlockBlobSnapshot.Metadata["MicrosoftAzureCompute_VMName"]
      $CloudBlockBlobSnapshot.SnapshotTime
      $CloudBlockBlobSnapshot.Delete() 
    }
  }
}