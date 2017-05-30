Import-Module -Name AzureRM.Resources

function ShutDownResource
{
  # Get all variables from Runbook Assets
  $ResourceGroupName = Get-AutomationVariable -Name 'ResourceGroupName'
  $ShutDownValue = Get-AutomationVariable -Name 'ShutDownValue'
  $SubId = Get-AutomationVariable -Name 'SubscriptionId'
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
# Find and stop all VM's by specific tag and return status
$vmList = Find-AzureRmResource -TagName "AutoShutDown" -TagValue $ShutDownValue | Where-Object {$_.ResourceGroupName -eq $ResourceGroupName -and $_.ResourceType -eq "Microsoft.Compute/virtualMachines"} | Select Name, ResourceGroupName
foreach ($vm in $vmList)
{
  $PowerState = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $vm.Name -Status -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).Statuses.Code[1]
  if ($PowerState -eq 'PowerState/deallocated')
  {
    $vm.Name + " is already shut down."
  }
    else
    {
      $vm.Name + " is being shut down."
      $ShutdownState = (Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $vm.Name -Force -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).IsSuccessStatusCode
      Start-Sleep -s 10
      if ($ShutdownState -eq 'True')
      {
        $vm.Name + " Has been shut down successfully."
      }
        else
        {
          $vm.Name + " Has failed to shut down. Shutdown Status  = " + $ShutdownState
        }
    }
  }
}
ShutDownResource
