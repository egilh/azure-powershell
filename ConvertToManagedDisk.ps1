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

    $vmList = $vmName.Split(",")
    # Stop and deallocate the VM before converting disks
    foreach ($vm in $vmList) {
        Stop-AzureRmVM -ResourceGroupName $rgName -Name $vm -Force
        ConvertTo-AzureRmVMManagedDisk -ResourceGroupName $rgName -VMName $vm
        # If Premium storage is selected convert disks that belong
        # to the selected VM, convert to Premium storage
        # Get all disks in the resource group of the VM
        $vmDisks = Get-AzureRmDisk -ResourceGroupName $rgName
        $testDisk = $vmDisks | Where-Object {$_.OwnerId -eq $vm.Id}
        $vmContext = Get-AzureRmVM -Name $vm -ResourceGroupName $rgName
        $vm.HardwareProfile.VmSize = $size
        Write-Host $("Checking if disks needs to be upgraded to Premium ..")
        if ($diskType -eq "Premium" -and $testDisk.AccountType -eq "Standard") {
            # Change VM size to a size supporting Premium storage
            Write-Host $("Upgrading " + $vm.Id)
            Update-AzureRmVM -VM $vmContext -ResourceGroupName $rgName
            foreach ($disk in $vmDisks) {
                if ($disk.OwnerId -eq $vm.Id) {
                    $diskUpdateConfig = New-AzureRmDiskUpdateConfig –AccountType "PremiumLRS"
                    Update-AzureRmDisk -DiskUpdate $diskUpdateConfig -ResourceGroupName $rgName `
                        -DiskName $disk.Name
                }
            }
        }
        Start-AzureRmVM -ResourceGroupName $rgName -Name $vmName
    }
}
ConvertToMangedDisk 