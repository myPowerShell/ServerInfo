function Get-NutanixVMStorageReport {

    [CmdletBinding()]
    param (
        # Updated to accept an array of Prism Central host names or IPs
        [Parameter(Mandatory = $true)]
        [String[]] $PrismCentral,
        
        [Parameter(Mandatory = $true, HelpMessage="Enter your nxUserID(Ex:nxuser@domain.local")]
        [String] $nxUser,
        
        [Parameter(Mandatory = $true, HelpMessage="Enter your nxPassword as SecureString")]
        [ValidateNotNullOrEmpty()]
        [SecureString]$nxPassword,

        # Added parameter to accept a targeted list of server names
        [Parameter(Mandatory = $false)]
        [String[]]$ComputerName,

        [Parameter(Mandatory = $false)]
        [String]
        $ExportPath = "C:\Temp\Logs"

    )

    # 1. FORCE TLS 1.2 FOR POWERSHELL 5.1 COMPATIBILITY
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    # 2. BYPASS SSL CERTIFICATE CHECKS (Replaces -SkipCertificateCheck)
    if ([System.Net.ServicePointManager]::ServerCertificateValidationCallback -eq $null) {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    }

    Write-Host "Script execution in Progress... Please wait" -ForegroundColor Yellow
    Write-Verbose "PowerShell version $($PSVersionTable.PSVersion.Major) is running with TLS 1.2 enforced."

    # Decrypt SecureString password safely
    $MyKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($nxPassword))
    $APIKey = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${nxUser}:${MyKey}"))

    $Headers = @{
        "Authorization" = "Basic $APIKey"
        "Content-Type"  = "application/json"
        "Accept"        = "application/json"
    }

    # Consolidated global array to hold combined output from all provided hosts
    $MasterResponse = New-Object System.Collections.ArrayList

    # Iterate through each provided Prism Central cluster host
    foreach ($PC in $PrismCentral) {
        Write-Host "Connecting to Prism Central: $PC..." -ForegroundColor Cyan
        $baseUrl = "https://$($PC):9440/api/nutanix/v3"

        # ----------------------------------------------------
        # 1. STORAGE CONTAINERS
        # ----------------------------------------------------
        Write-Verbose "[$PC] Mapping storage containers..."
        $containerMap = @{}
        $offsetby = 0
        $pageSize = 500
        $totalContainersFound = $null

        do {
            $containerBody = @{
                entity_type             = "storage_container"
                group_member_count      = $pageSize
                group_member_offset     = $offsetby
                group_member_attributes = @(
                    @{ attribute = "container_name" }
                )
            } | ConvertTo-Json -Depth 5

            $containerResponse = Invoke-RestMethod -Uri "$baseUrl/groups" -Headers $Headers -Method Post -Body $containerBody
            
            if ($containerResponse.group_results.entity_results) {
                foreach ($sc in $containerResponse.group_results.entity_results) {
                    $uuid = $sc.entity_id
                    
                    $containerData = $sc.data | Where-Object { $_.name -eq "container_name" }
                    $name = if ($containerData.values.values) { $containerData.values.values | Select-Object -First 1 } else { $containerData.values }

                    if ($uuid -and $name) {
                        $containerMap[$uuid] = [string]$name
                    }
                }
            }

            if ($null -eq $totalContainersFound) {
                $totalContainersFound = $containerResponse.group_results.total_entity_count
            }
            
            $offsetby += $pageSize
        } while ($offsetby -lt $totalContainersFound)


        # ----------------------------------------------------
        # 2. GROUP METRICS (VM Storage Usage)
        # ----------------------------------------------------
        Write-Verbose "[$PC] Gathering storage consumption metrics via v3 groups API..."
        $groupUsageMap = @{}
        $offsetby = 0
        $totalGroupsFound = $null

        do {
            $groupsBody = @{
                entity_type             = "mh_vm"
                group_member_count      = $pageSize
                group_member_offset     = $offsetby
                group_member_attributes = @(
                    @{ attribute = "vm_name" },
                    @{ attribute = "controller_user_bytes" }
                )
            } | ConvertTo-Json -Depth 5

            $groupResponse = Invoke-RestMethod -Uri "$baseUrl/groups" -Headers $Headers -Method Post -Body $groupsBody
            
            if ($groupResponse.group_results.entity_results) {
                foreach ($groupItem in $groupResponse.group_results.entity_results) {
                    
                    $nameData = $groupItem.data | Where-Object { $_.name -eq "vm_name" }
                    $bytesData = $groupItem.data | Where-Object { $_.name -eq "controller_user_bytes" }

                    $vmNameAttr = if ($nameData.values.values) { $nameData.values.values | Select-Object -First 1 } else { $nameData.values }
                    $usedBytesAttr = if ($bytesData.values.values) { $bytesData.values.values | Select-Object -First 1 } else { $bytesData.values }

                    if ($vmNameAttr -and $usedBytesAttr) {
                        $groupUsageMap[[string]$vmNameAttr] = [int64]$usedBytesAttr
                    }
                }
            }

            if ($null -eq $totalGroupsFound) {
                $totalGroupsFound = $groupResponse.group_results.total_entity_count
            }
            
            $offsetby += $pageSize
        } while ($offsetby -lt $totalGroupsFound)


        # ----------------------------------------------------
        # 3. VMs CONFIGURATION ---> FINAL REPORT GENERATION
        # ----------------------------------------------------
        Write-Verbose "[$PC] Fetching virtual machines configuration details..."
        $offsetby = 0
        $totalVMsFound = $null

        # Pre-build filter verification matching using uppercase conversion
        $filterActive = $null -ne $ComputerName -and $ComputerName.Count -gt 0
        if ($filterActive) {
            $upperComputerList = $ComputerName | ForEach-Object { $_.ToUpper() }
        }

        do {
            $vmBody = @{
                kind   = "vm"
                offset = $offsetby
                length = $pageSize
            } | ConvertTo-Json

            $vmResponse = Invoke-RestMethod -Uri "$baseUrl/vms/list" -Headers $Headers -Method Post -Body $vmBody
            
            foreach ($vm in $vmResponse.entities) {
                $vmName = $vm.spec.name

                # Dynamic Filtering Logic
                if ($filterActive -and $upperComputerList -notcontains $vmName.ToUpper()) {
                    continue # Skip processing this VM if it isn't listed in $ComputerName
                }

                $totalSizeBytes = 0
                $containers = New-Object System.Collections.Generic.HashSet[string]
                $diskList = $vm.status.resources.disk_list
                
                if ($diskList) {
                    foreach ($disk in $diskList) {
                        if ($disk.disk_size_bytes) {
                            $totalSizeBytes += $disk.disk_size_bytes
                        }
                        
                        $scUuid = $disk.storage_config.storage_container_reference.uuid
                        $scRefName = $disk.storage_config.storage_container_reference.name
                        
                        if ($scRefName) {
                            [void]$containers.Add($scRefName)
                        } elseif ($scUuid -and $containerMap.ContainsKey($scUuid)) {
                            [void]$containers.Add($containerMap[$scUuid])
                        } elseif ($scUuid) {
                            [void]$containers.Add($scUuid)
                        }
                    }
                }

                $usedBytes = if ($groupUsageMap.ContainsKey($vmName)) { $groupUsageMap[$vmName] } else { 0 }
                
                $totalGB = [math]::Round($totalSizeBytes / 1GB, 2)
                $usedGB = [math]::Round($usedBytes / 1GB, 2)
                $freeGB = [math]::Round(($totalSizeBytes - $usedBytes) / 1GB, 2)
                $usedPct = if ($totalSizeBytes -gt 0) { [math]::Round(($usedBytes / $totalSizeBytes) * 100, 2) } else { 0 }

                $allocatedMemoryMiB = $vm.status.resources.memory_size_mib
                if ($null -eq $allocatedMemoryMiB) { $allocatedMemoryMiB = 0 }
                
                # Safe fallbacks to prevent errors if a VM is powered off and unassigned to a physical host
                $hostName = $vm.status.resources.host_reference.name
                if ($null -eq $hostName) { 
                $hostName = "N/A" 
                }
                elseif ($hostName -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                    # If the host name is an IP address, resolve it to a short name via DNS
                    try {
                    $fqdn = [System.Net.Dns]::GetHostEntry($hostName).HostName
                    $hostName = $fqdn.Split('.')[0]
                    }
                    catch {
                        Write-Verbose "falling back to original data as name lookup failed"
                    }
                 }

                # Construct identical PSCustomObject matching your original exact property list
                [void]$MasterResponse.Add([PSCustomObject]@{
                    Nutanix_PC         = $PC
                    VMName             = $vmName
                    PowerState         = $vm.status.resources.power_state
                    HostName           = $hostName
                    MemoryGiB          = [math]::Round($allocatedMemoryMiB / 1024, 2)
                    AllocatedGB        = $totalGB
                    UsedGB             = $usedGB
                    FreeGB             = $freeGB
                    UsedPercentage     = $usedPct
                    ClusterName        = $vm.status.cluster_reference.name
                    StorageContainers  = ($containers -join ", ")
                })
            }

            if ($null -eq $totalVMsFound) {
                $totalVMsFound = $vmResponse.metadata.total_matches
            }
            
            $offsetby += $pageSize
            } while ($offsetby -lt $totalVMsFound)
        }

        # Define the output file structure with a unique timestamp
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $OutputFile = Join-Path -Path $ExportPath -ChildPath "NutanixVM_Storage_Report_$($timestamp).csv"
        
        $Report = $MasterResponse
        
        # Export the combined data to a single consolidated CSV file
        if ($Report) {
        if (-not (Test-Path $ExportPath)) {
            New-Item -ItemType Directory -Force -Path $ExportPath | Out-Null
        }
        
        $Report | Export-Csv -Path $OutputFile -NoTypeInformation
        Write-Host "Execution completed successfully! Report saved to: $OutputFile" -ForegroundColor Green
        
        # Output the report object to the pipeline in case you want to filter it dynamically
        # return $Report
        
        } else {
            Write-Warning "No virtual machine data matched your criteria."
        }
        
   }



   
<#
# Loading standalone function to Terminal if it's not part of Module
 . ./Get-NutanixVMStorageReport.ps1


# if output needs to be filtered down to contain only select list of LOB systems
$ServerList = (Get-Content "allservers.txt")

# $Secret = Read-Host -Prompt "Please enter your Secret" -AsSecureString
# $bytes = ConvertFrom-SecureString $Secret
# $bytes | out-file .\secureKey.key

# Using locally stored secret.
$secureKey = (get-content .\secureKey.key) | ConvertTo-SecureString



$Params = @{
    nxUser       = "nxUser@domain.local"
    nxPassword   = $secureKey
    ComputerName = $ServerList
   }

# Dynamically add the target list later
$Params["PrismCentral"] = @("pc01.domain.local", "pc02.domain.local")

Get-NutanixVMStorageReport @Params


#>
