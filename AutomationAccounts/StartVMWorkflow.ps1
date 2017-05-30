workflow StartVM
{
  # Get all variables from Runbook Assets
  $ResourceGroupName = Get-AutomationVariable -Name 'ResourceGroupName'
  $ShutDownValue = Get-AutomationVariable -Name 'ShutDownValue'
  $SubId = Get-AutomationVariable -Name 'SubscriptionId'
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
  Set-AzureRmContext -SubscriptionId $SubId

  # Find and start all VM's by specific tag and return status
  $vmList = Find-AzureRmResource -TagName $ShutDownTag -TagValue $ShutDownValue | Where-Object {$_.ResourceGroupName -eq $ResourceGroupName -and $_.ResourceType -eq "Microsoft.Compute/virtualMachines"} | Select Name, ResourceGroupName
  foreach -Parallel ($vm in $vmList)
  {
    $PowerState = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $vm.Name -Status -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).Statuses.Code[1]
    if ($PowerState -eq 'PowerState/running')
    {
      $vm.Name + " is already running."
    }
      else
      {
        $vm.Name + " is starting up."
        $BootState = (Start-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $vm.Name -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).IsSuccessStatusCode
        Start-Sleep -s 10
        if ($BootState -eq 'True')
        {
          $vm.Name + " has been started successfully."
        }
          else
          {
            $vm.Name + " has failed to start. Boot status  = " + $BootState
          }
      }
  }
}
