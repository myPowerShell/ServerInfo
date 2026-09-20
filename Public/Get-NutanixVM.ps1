function Get-NutanixVM {

    [CmdletBinding()]
    param (
        # Changed to String[] to accept one or multiple Prism Central targets
        [Parameter(Mandatory = $true)]
        [String[]] $PrismCentral,
        
        [Parameter(Mandatory = $true, HelpMessage = "Enter your UserID")]
        [String] $nxUser,
        
        [Parameter(Mandatory = $true, HelpMessage = "Enter your Password")]
        [ValidateNotNullOrEmpty()]
        [SecureString]$nxPassword,

        [Parameter(Mandatory = $false)]
        [String[]]$ComputerName,

        [Parameter(Mandatory = $false)]
        [String]
        $ExportPath = "C:\Temp\Logs"
    )

    # Trust all certificates (PowerShell 5.1 replacement for -SkipCertificateCheck)
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    
    Write-Host "Script execution in Progress... Please wait" -ForegroundColor Yellow
    
    # Decrypt the SecureString password safely
    $MyKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($nxPassword))
    $APIKey = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${nxUser}:${MyKey}"))
    $MyKey = $null
    
    $Headers = @{
        "Authorization" = "Basic $APIKey"
        "Content-Type"  = "application/json"
    }

    # Initialize a master response array to collect records from ALL endpoints
    $MasterResponse = @()

    # Iterate through each Prism Central target
    foreach ($PC in $PrismCentral) {
        Write-Host "Connecting to Prism Central: $PC..." -ForegroundColor Cyan
        
        $Url = "https://$($PC):9440/api/nutanix/v3/vms/list"
        $offsetby = 0
        $totalVMsFound = $null

        do {
            $Body = @{
                kind   = "vm"
                offset = $offsetby
                length = 500 
            } | ConvertTo-Json

            try {
                $payload = Invoke-RestMethod -Uri $Url -Method Post -Headers $Headers -Body $Body -ErrorAction Stop
            }
            catch {
                Write-Error "Failed to retrieve data from $PC. Error: $_"
                break # Exit the do-while loop for this target and move to the next PC
            }
            
            if (!$totalVMsFound) {
                $totalVMsFound = $payload.metadata.total_matches
            }

            if ($null -eq $payload.entities) {
                break
            }

            foreach ($p in $payload.entities) {

                $diskList = $p.status.resources.disk_list
                $vDisks = $diskList | Where-Object { $_.device_properties.device_type -ne "CDROM" -and $_.disk_size_mib -gt 0 }
                
                $totalAllocatedMiB = ($vDisks | Measure-Object -Property disk_size_mib -Sum).Sum
                if ($null -eq $totalAllocatedMiB) { $totalAllocatedMiB = 0 }

                $storageUsageBytes = $p.status.resources.storage_usage_bytes
                if ($null -eq $storageUsageBytes) { $storageUsageBytes = 0 }
                
                $allocatedMemoryMiB = $p.status.resources.memory_size_mib
                if ($null -eq $allocatedMemoryMiB) { $allocatedMemoryMiB = 0 }

                $hostName = $p.status.resources.host_reference.name
                if ($null -eq $hostName) { 
                    $hostName = "N/A" 
                }
                elseif ($hostName -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                    try {
                        $fqdn = [System.Net.Dns]::GetHostEntry($hostName).HostName
                        $hostName = $fqdn.Split('.')[0]
                    }
                    catch {
                        Write-Verbose "falling back to original data as name lookup failed"
                    }
                }

                # Appending data to our cumulative Master list
                $MasterResponse += [PSCustomObject]@{
                    Prism_Central    = $PC  # Visual tracking of origin
                    Server           = $p.spec.name
                    Host_Name        = $hostName
                    CPUs             = $p.spec.resources.num_sockets
                    CPU_Cores        = $p.spec.resources.num_vcpus_per_socket
                    Memory_GiB       = [Math]::Round(($allocatedMemoryMiB / 1024), 2)
                    Power_State      = $p.spec.resources.power_state
                    DiskAllocatedGiB = [Math]::Round(($totalAllocatedMiB / 1024), 2)
                    VM_UUID          = $p.metadata.uuid
                    Created          = $p.metadata.creation_time
                }
            }

            $offsetby += 500

        } while ($offsetby -lt $totalVMsFound)
    }

    $APIKey = $null

    # Global filter logic using $ComputerName against the collected dataset
    if ($ComputerName) {
        $Report = $MasterResponse | Where-Object { $ComputerName -contains $_.Server }
    }
    else {
        $Report = $MasterResponse
    }

    # Define the output file structure with a unique timestamp
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputFile = Join-Path -Path $ExportPath -ChildPath "NutanixVM_Report_$($timestamp).csv"

    # Export the combined data to a single consolidated CSV file
    if ($Report) {
        if (-not (Test-Path $ExportPath)) {
            New-Item -ItemType Directory -Force -Path $ExportPath | Out-Null
        }
        
        $Report | Export-Csv -Path $OutputFile -NoTypeInformation
        Write-Host "Execution completed successfully! Report saved to: $OutputFile" -ForegroundColor Green
        
        # return $Report
    }
    else {
        Write-Warning "No virtual machine data matched your criteria."
    }
}




<#
# Loading standalone function to Terminal if it's not part of Module
 . ./Get-NutanixVM.ps1


# if the function is part of Module, Makesure Module is loaded
Import-Module -Name ServerInfo
# $secureKey  = Read-Host "Enter Password for (nxUserID@domain.local):" -AsSecureString

# if output needs to be filtered down to contain only select list of LOB systems
$ServerList = (Get-Content "allservers.txt")




# $Secret = Read-Host -Prompt "Please enter your Secret" -AsSecureString
# $bytes = ConvertFrom-SecureString $Secret
# $bytes | out-file .\secureKey.key


# Using locally stored secret.
$secureKey = (get-content .\secureKey.key) | ConvertTo-SecureString



$Params = @{
    nxUser       = "nxuser@domain.local"
    nxPassword   = $secureKey
    ComputerName = $ServerList
   }

# Dynamically add the target list later
$Params["PrismCentral"] = @("prism01.domain.local", "prism02.domain.local")


Get-NutanixVM @Params



#>