function CreateARMVM {
    param(
        # Parameter help description
        [Parameter(Mandatory=$True, Position=0)]
        [String]
        $ResourgeGroup,
        # Parameter help description
        [Parameter(Mandatory=$True, Position=1)]
        [String]
        $vmName,
        # Parameter help description
        [Parameter(Mandatory=$True, Position=2)]
        [ValidateSet("Standard_DS1_v2","Standard_DS2_v2","Standard_DS3_v2", "Standard_DS4_v2")]
        [String]
        $vmSize = "Standard_DS2_v2",
        # Parameter help description
        [Parameter(Mandatory=$True, Position=3)]
        [ValidateSet("Standard","Premium")]
        [String]
        $diskType = "Standard"
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

}