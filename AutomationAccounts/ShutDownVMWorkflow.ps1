workflow ShutDownResource
{
  Param(
    [Parameter (Mandatory = $true)][string]$SubscriptionId,
    [Parameter (Mandatory = $false)][string]$ResourceGroupName,
    [Parameter (Mandatory = $true)][string]$ShutDownValue = 'Yes'
  )
  $ShutDownTag = "AutoShutDown"
  $connectionName = "AzureRunAsConnection"

  # Get the connection "AzureRunAsConnection "
  $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName

  "Logging in to Azure..."
  Add-AzureRmAccount `
      -ServicePrincipal `
      -TenantId $servicePrincipalConnection.TenantId `
      -ApplicationId $servicePrincipalConnection.ApplicationId `
      -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
  Set-AzureRmContext -SubscriptionId $SubscriptionId

  $vmList = Find-AzureRmResource -TagName $ShutDownTag -TagValue $ShutDownValue | Where-Object {$_.ResourceGroupName -eq $ResourceGroupName -and $_.ResourceType -eq "Microsoft.Compute/virtualMachines"} | Select Name, ResourceGroupName
  foreach -Parallel ($vm in $vmList)
  {
    $PowerState = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VM.Name -Status -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).Statuses.Code[1]
    if ($PowerState -eq 'PowerState/deallocated')
    {
      $VM.Name + " is already shut down."
    }
      else
      {
        $VM.Name + " is being shut down."
        $ShutdownState = (Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VM.Name -Force -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).IsSuccessStatusCode
        Start-Sleep -s 10
        if ($ShutdownState -eq 'True')
        {
          $VM.Name + " has been shut down successfully."
        }
          else
          {
            $VM.Name + " has failed to shut down. Shutdown Status  = " + $ShutdownState
          }
      }
  }
}
