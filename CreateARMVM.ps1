function CreateARMVM {
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
    ))

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
    # Needs fix
}