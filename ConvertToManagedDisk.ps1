function ConvertToMangedDisk {
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [String]
        $ResourceGroup,
        [Parameter(Mandatory = $True, Position = 1)]
        [String]
        $SubscriptionName,
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
    Get-AzureRMSubscription -SubscriptionName $SubscriptionName | Select-AzureRmSubscription
    $vmList = Get-AzureRmVM -Name $vmName -ResourceGroupName $resourceGroupName
    # Stop and deallocate the VM before changing the size
    foreach ($vm in $vmList) {
        Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vm -Force
        ConvertTo-AzureRmVMManagedDisk -ResourceGroupName $rgName -VMName $vmName
        # If Premium storage is selected, change disks
        # For disks that belong to the VM selected, convert to Premium storage
        if ($diskType -eq "Premium") {
            # Change VM size to a size supporting Premium storage
            $vm.HardwareProfile.VmSize = $size
            Write-Host $("Setting correct VM type for Premium storage")
            Update-AzureRmVM -VM $vm -ResourceGroupName $resourceGroupName
            # Get all disks in the resource group of the VM
            $vmDisks = Get-AzureRmDisk -ResourceGroupName $resourceGroupName 
            foreach ($disk in $vmDisks) {
                if ($disk.OwnerId -eq $vm.Id) {
                    $diskUpdateConfig = New-AzureRmDiskUpdateConfig –AccountType PremiumLRS
                    Update-AzureRmDisk -DiskUpdate $diskUpdateConfig -ResourceGroupName $resourceGroupName `
                        -DiskName $disk.Name
                }
            }
        }

        Start-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName
    }
}
ConvertToMangedDisk 