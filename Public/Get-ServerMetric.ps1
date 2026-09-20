Function Get-ServerMetric {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $false)]
        [int]$ThrottleLimit = 10,

        [Parameter(Mandatory = $false)]
        [string]$CSVPath
    )

    BEGIN {
        # Define the exact operational script block to execute per server inside the Runspace
        $ScriptBlock = {
            param($Computer)
            $Session = $null
            try {
                $Session = New-CimSession -ComputerName $Computer -ErrorAction Stop -OperationTimeoutSec 15
                
                # 1. Hardware Inventory Properties
                $CPUInfo = Get-CimInstance -CimSession $Session -ClassName Win32_Processor -ErrorAction Stop
                $SumCores = ($CPUInfo.NumberOfCores | Measure-Object -Sum).Sum
                
                $OSInfo = Get-CimInstance -CimSession $Session -ClassName Win32_OperatingSystem -ErrorAction Stop
                
                $MemInfo = Get-CimInstance -CimSession $Session -ClassName Win32_PhysicalMemory -ErrorAction Stop
                $PhysicalMemory = ($MemInfo | Measure-Object -Property Capacity -Sum).Sum / 1GB
                $PhysicalMemory = [math]::Round($PhysicalMemory, 2)
                
                # 2. Gather Storage & Calculate Metrics
                $RawDisks = Get-CimInstance -CimSession $Session -ClassName Win32_LogicalDisk -ErrorAction Stop | 
                    Where-Object { $_.DriveType -eq 3 }

                $TotalAllocatedRaw = ($RawDisks | Measure-Object -Property Size -Sum).Sum
                $TotalFreeRaw      = ($RawDisks | Measure-Object -Property FreeSpace -Sum).Sum
                $TotalUsedRaw      = $TotalAllocatedRaw - $TotalFreeRaw

                $TotalAllocatedGB  = [math]::Round(($TotalAllocatedRaw / 1GB), 2)
                $TotalUsedGB       = [math]::Round(($TotalUsedRaw / 1GB), 2)
                
                $TotalDiskPercentUsed = if ($TotalAllocatedRaw -gt 0) { 
                    [math]::Round(($TotalUsedRaw / $TotalAllocatedRaw * 100), 2) 
                } else { 0 }

                # 3. Live OS Performance Metrics
                $CpuSamples = for ($i = 1; $i -le 3; $i++) {
                    Get-CimInstance -CimSession $Session -ClassName Win32_PerfFormattedData_PerfOS_Processor | 
                        Where-Object { $_.Name -eq '_Total' } | 
                        Select-Object -ExpandProperty PercentProcessorTime
                    if ($i -lt 3) { Start-Sleep -Seconds 1 }
                }
                $AvgCpuUsage = [math]::Round(($CpuSamples | Measure-Object -Average).Average, 2)

                $TotalVisibleMemMB = $OSInfo.TotalVisibleMemorySize / 1KB
                $FreeMemMB         = $OSInfo.FreePhysicalMemory / 1KB
                $UsedMemMB         = $TotalVisibleMemMB - $FreeMemMB
                $RamUsagePct       = [math]::Round(($UsedMemMB / $TotalVisibleMemMB * 100), 2)

                $TimeStamp = (Get-Date).ToString("yyyy-MM-dd_HHmm")
                [PSCustomObject]@{
                    ComputerName     = $Computer
                    Status           = "Connected"
                    OS_Name          = $OSInfo.Caption
                    vCPUs            = $SumCores
                    Live_AvgCpu_Pct  = "$AvgCpuUsage%"
                    Physical_Memory  = "$PhysicalMemory GB"
                    Live_RamUsage_Pct= "$RamUsagePct%"
                    DiskAllocated_GB = $TotalAllocatedGB
                    DiskUsed_GB      = $TotalUsedGB
                    DiskPercentUsed  = "$TotalDiskPercentUsed%"
                    Time_Stamp = $TimeStamp
                }
            }
            catch {

                $TimeStamp = (Get-Date).ToString("yyyy-MM-dd_HHmm")
                [PSCustomObject]@{
                    ComputerName     = $Computer
                    Status           = "Unable_to_Connect"
                    OS_Name          = $null
                    vCPUs            = $null
                    Live_AvgCpu_Pct  = $null
                    Physical_Memory  = $null
                    Live_RamUsage_Pct= $null
                    DiskAllocated_GB = $null
                    DiskUsed_GB      = $null
                    DiskPercentUsed  = $null
                    Time_Stamp = $TimeStamp
                }
            }
            finally {
                if ($Session) {
                    Remove-CimSession -CimSession $Session -ErrorAction SilentlyContinue
                }
            }
        }

        # Initialize properties
        $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $ThrottleLimit)
        $RunspacePool.Open()
        $Jobs = New-Object System.Collections.Generic.List[PSCustomObject]
        
        # Prepare an array to hold all results for the CSV file if requested
        if ($CSVPath) { $CSVResults = New-Object System.Collections.Generic.List[PSCustomObject] }
    }

    PROCESS {
        foreach ($Computer in $ComputerName) {
            $Computer = $Computer.Trim()
            $PowerShell = [PowerShell]::Create().AddScript($ScriptBlock).AddArgument($Computer)
            $PowerShell.RunspacePool = $RunspacePool
            
            $Jobs.Add([PSCustomObject]@{
                Instance = $PowerShell
                Handle   = $PowerShell.BeginInvoke()
            })
        }
    }

    END {
        while ($Jobs.Count -gt 0) {
            $FinishedJobs = @($Jobs | Where-Object { $_.Handle.IsCompleted })
            
            foreach ($Job in $FinishedJobs) {
                $Result = $Job.Instance.EndInvoke($Job.Handle)
                
                # Always pass the results live to the console/pipeline
                Write-Output $Result

                # Collect the data for CSV writing if requested
                if ($CSVPath) { $CSVResults.Add($Result) }

                $Job.Instance.Dispose()
                [void]$Jobs.Remove($Job)
            }
            
            if ($Jobs.Count -gt 0) { Start-Sleep -Milliseconds 200 }
        }

        # Export to CSV if a path was specified
        if ($CSVPath -and $CSVResults.Count -gt 0) {
            $CSVResults | Export-Csv -Path $CSVPath -NoTypeInformation
        }

        if ($RunspacePool) {
            $RunspacePool.Close()
            $RunspacePool.Dispose()
        }
    }
}

<#

Get-ServerMetric -ComputerName (Get-Content "servers.txt") |  Export-Csv -Path "C:\Temp\ServerMetric_$(Get-Date -Format "yyyyMMdd_HHmmss").csv" -NoTypeInformation

#>
