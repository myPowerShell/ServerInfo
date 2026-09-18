function Get-NutanixDiskMapping {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$ComputerName,

        [Parameter(Mandatory = $false)]
        [string]$CsvPath
    )

    $OnlineServers = @()

    Write-Host "Verifying CIM connectivity for target servers..." -ForegroundColor Cyan

    # 1. Pre-check CIM connectivity using Try/Catch and New-CimSession
    foreach ($Server in $ComputerName) {
        
           # Attempt connection and force terminating error on failure
           if (New-CimSession -ComputerName $Server  -ErrorAction SilentlyContinue){
            # If successful, add to our list and clean up the test session object
            $OnlineServers += $Server
            }else{
            Write-Warning "Skipping '$Server': Unable to establish a CIM session. Reason: $($_.Exception.Message)"
            }

    }

    # If no servers are online, stop execution early
    if ($OnlineServers.Count -eq 0) {
        Write-Error "No target servers passed the CIM connection test. Exiting."
        return
    }

    Write-Host "Gathering disk details from $($OnlineServers.Count) accessible server(s)..." -ForegroundColor Green

    # 2. Gather data only from the online servers
    $results = Invoke-Command -ComputerName $OnlineServers -ScriptBlock {
        Get-CimInstance Win32_DiskDrive | ForEach-Object {
            $disk = $_
            $partitions = Get-CimAssociatedInstance -InputObject $disk -Association Win32_DiskDriveToDiskPartition
            $logicalDisks = $partitions | ForEach-Object {
                Get-CimAssociatedInstance -InputObject $_ -Association Win32_LogicalDiskToPartition
            }
            
            if ($logicalDisks.DeviceID) {
                $letters = $logicalDisks.DeviceID -join ', '
            } else {
                $letters = 'No Letter Assigned'
            }
            
            [PSCustomObject]@{
                ServerName   = $env:COMPUTERNAME
                DeviceID     = $disk.DeviceID
                Index        = $disk.Index
                NutanixUUID  = $disk.SerialNumber
                DriveLetters = $letters
            }
        }
    } | Select-Object ServerName, DeviceID, Index, NutanixUUID, DriveLetters | 
        Sort-Object ServerName, @{Expression = {[int]($_.DeviceID -replace '\D+')}}

    # 3. Handle output and CSV export
    if ($CsvPath) {
        $results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "Success: Details exported to $CsvPath" -ForegroundColor Green
    } else {
        return $results
    }
}



<#

Get-NutanixDiskMapping -ComputerName Server1, Server02 | ft

#>