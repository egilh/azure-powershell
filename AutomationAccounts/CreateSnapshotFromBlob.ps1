<#
.SYNOPSIS
  Short description

.DESCRIPTION
  Long description

.OUTPUTS
  The value returned by this cmdlet

.EXAMPLE
  Example of how to use this cmdlet

.LINK
  To other relevant cmdlets or help
#>
Import-Module -Name AzureRM.Compute
Import-Module -Name AzureRM.Resources

function CreateSnapshotFromBlob
{
  # Get all variables from Runbook Assets
  #$ResourceGroupName = Get-AutomationVariable -Name 'ResourceGroupName'
  #$TagValue = Get-AutomationVariable -Name 'PCICompliant'
  $SubId = Get-AutomationVariable -Name 'SubscriptionId'
  $srcAccountName = Get-AutomationVariable -Name 'srcAccountName'
  $srcKey = Get-AutomationVariable -Name 'srcKey'
  $srcContainerName = Get-AutomationVariable -Name 'vhds'
  # Set source context
  $srcContext = New-AzureStorageContext -StorageAccountName $srcAccountName -StorageAccountKey $srcKey

  $dstAccountName = Get-AutomationVariable -Name 'dstAccountName'
  $dstKey = Get-AutomationVariable -Name 'dstKey'
  $dstContainerName = 'vhd-snapshots'
  # Set destination context
  $dstContext = New-AzureStorageContext -StorageAccountName $dstAccountName -StorageAccountKey $dstKey
  
  $connectionName = "AzureRunAsConnection"
  
  try
  {
      # Get the connection "AzureRunAsConnection "
      $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName

      "Logging in to Azure..."
      Add-AzureRmAccount `
          -ServicePrincipal `
          -TenantId $servicePrincipalConnection.TenantId `
          -ApplicationId $servicePrincipalConnection.ApplicationId `
          -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
      Set-AzureRmContext -SubscriptionId $SubId
  }
  catch
  {
    if (!$servicePrincipalConnection)
    {
      $ErrorMessage = "Connection $connectionName not found."
      throw $ErrorMessage
    }
      else
      {
        Write-Error -Message $_.Exception
        throw $_.Exception
      }
  }

  # Get Blob reference and create snapshots of VHD's
    $blobs = Get-AzureStorageBlob -Container $srcContainerName -Context $srcContext | Where-Object {$_.Name -like '*.vhd'}
    foreach ($blob in $blobs)
    {
        $blob.ICloudBlob.CreateSnapshot()
        Write-Host 'Creating snapshot of ' + $blob.Name
    }

  # Copy snapshot to new container
    $container = Get-AzureStorageContainer -Name $srcContainerName -Context $srcContext
    $listOfBlobs = $container.CloudBlobContainer.ListBlobs($BlobName, $true, "Snapshots")

    foreach ($CloudBlockBlob in $listOfBlobs) 
    {
        if ($CloudBlockBlob.IsSnapshot)
        {
        $CloudBlockBlob.FetchAttributes()
        $TimeDate = Get-Date -Format d | ForEach-Object {$_ -replace "/", "" }
        $newBlobName = $CloudBlockBlob.Name + $TimeDate
        Start-AzureStorageBlobCopy -ICloudBlob $CloudBlockBlob -DestContainer $dstContainerName -DestBlob $newBlobName -Context $dstContext
        }
    }

  # Delete old snapshots
    foreach ($CloudBlockBlob in $ListOfBLobs) 
    {
        if ($CloudBlockBlob.IsSnapshot)
        {
        $CloudBlockBlob.FetchAttributes()

        #write-host "filename = " $CloudBlockBlob.Metadata["filename"]
        $CloudBlockBlobSnapshot = $CloudBlockBlob
        $CloudBlockBlobSnapshot.SnapshotTime
        $CloudBlockBlobSnapshot.Delete()
        }
   }
}
CreateSnapshotFromBlob