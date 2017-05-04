Import-Module -Name AzureRM.Resources

function ShutDownResource
{
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

$vmList = Find-AzureRmResource -TagName "AutoShutDown" -TagValue $ShutDownValue | Where-Object {$_.ResourceGroupName -eq $ResourceGroupName -and $_.ResourceType -eq "Microsoft.Compute/virtualMachines"} | Select Name, ResourceGroupName
foreach ($vm in $vmList)
{
  $PowerState = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VM.Name -Status -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).Statuses.Code[1]
  if ($PowerState -eq 'PowerState/allocated')
  {
    $VM.Name + " is already running."
  }
    else
    {
      $VM.Name + " is starting up."
      $BootState = (Start-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VM.Name -Force -ErrorAction $ErrorActionPreference -WarningAction $WarningPreference).IsSuccessStatusCode
      Start-Sleep -s 10
      if ($BootState -eq 'True')
      {
        $VM.Name + " has been started successfully."
      }
        else
        {
          $VM.Name + " has failed to start. Boot status  = " + $BootState
        }
    }
  }
}
ShutDownResource
