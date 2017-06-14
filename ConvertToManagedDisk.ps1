<#
.DESCRIPTION
Script for converting Azure VM disks to Managed Disks.
.PARAMETER
- rgName 
- subName
- vmName
- diskType
- vmSize
#>
function ConvertToMangedDisk {
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [String]
        $rgName,
        [Parameter(Mandatory = $True, Position = 1)]
        [String]
        $subName,
        [Parameter(Mandatory = $True, Position = 2)]
        [String]
        $vmName,
        [Parameter(Mandatory = $True, Position = 3)]
        [ValidateSet("Standard", "Premium")]
        [String]
        $diskType = "Standard",
        [Parameter(Mandatory = $false, Position = 4)]
        [ValidateSet("Standard_DS1_v2", "Standard_DS2_v2", "Standard_DS3_v2", "Standard_DS4_v2")]
        [String]
        $vmSize = "Standard_DS1_v2"
    )

    try {
        Get-AzureRMContext
    }
    catch {
        if ($_ -like "*Login-AzureRMAccount to login*") {
            Login-AzureRmAccount
        }
        else {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
    Get-AzureRMSubscription -SubscriptionName $subName | Select-AzureRmSubscription

    # $vmList = $vmName.Split(",")
    foreach ($vm in $vmName.Split(",")) {
        # Set VM Context and check if VM is already using Managed Disks
        $vmContext = Get-AzureRmVM -Name $vm -ResourceGroupName $rgName
        if ($vmContext.StorageProfile.OsDisk.ManagedDisk -eq $null) {
            Write-Host $(" Stopping and converting " + $vm)
            Stop-AzureRmVM -ResourceGroupName $rgName -Name $vm -Force
            ConvertTo-AzureRmVMManagedDisk -ResourceGroupName $rgName -VMName $vm
        }
        else {
            Write-Host $($vm + " is already using Managed Disks ")
        }
        # If Premium storage is selected convert disks that belong
        # to the selected VM, convert to Premium storage
        # Get all disks in the resource group of the VM
        $vmDisks = Get-AzureRmDisk -ResourceGroupName $rgName | Where-Object {$_.OwnerId -eq $vmContext.Id}
        if ($diskType -eq 'Premium'-and $vmDisks.AccountType -eq 'Standard') {
            # Change VM size to a size supporting Premium storage
            Write-Host $(" Upgrading " + $vm + " to Premium Storage ")
            $PowerState = (Get-AzureRmVM -ResourceGroupName $rgName -Name $vm -Status).Statuses.Code[1]
            if ($PowerState -eq 'PowerState/running') {
                Stop-AzureRmVM -ResourceGroupName $rgName -Name $vm -Force
            }
            $vmContext.HardwareProfile.VmSize = $size
            Update-AzureRmVM -VM $vmContext -ResourceGroupName $rgName
            foreach ($disk in $vmDisks) {
                $diskUpdateConfig = New-AzureRmDiskUpdateConfig –AccountType "PremiumLRS"
                Update-AzureRmDisk -DiskUpdate $diskUpdateConfig -ResourceGroupName $rgName `
                -DiskName $disk.Name
            }
        }
        Start-AzureRmVM -ResourceGroupName $rgName -Name $vm
    }
}
ConvertToMangedDisk 