function Get-ProcessByCPU {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string[]]$ComputerName,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$ExportCsvPath,

        [Parameter(Mandatory = $false)]
        [string]$ProcessName,

        [Parameter(Mandatory = $false)]
        [int]$Top = 5,

        [Parameter(Mandatory = $false)]
        [int]$MaxThreads = 10
    )

    begin {
        $allComputers = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($computer in $ComputerName) {
            $allComputers.Add($computer)
        }
    }

    end {
        Write-Verbose "Initializing Multi-Threaded Runspace Pool with a maximum of $MaxThreads threads..."

        # 1. Define the code that each thread will execute
        $scriptBlock = {
            param($targetComputer, $procFilterName, $topCount)
            
            try {
                $sessionParams = @{ ComputerName = $targetComputer; ErrorAction = 'Stop' }

                # 1a. Gather server-side filtered performance metrics
                $filter = "Name != '_Total' AND Name != 'Idle' AND PercentProcessorTime > 0"
                if ($procFilterName) {
                    $sanitizedName = $procFilterName -replace "'", "''"
                    $filter += " AND Name LIKE '%$sanitizedName%'"
                }

                $perfInstances = Get-CimInstance -ClassName 'Win32_PerfFormattedData_PerfProc_Process' -Filter $filter @sessionParams
                if (-not $perfInstances) { return }

                # 1b. Query all processes at once to avoid WQL string length limits
                $processDetails = Get-CimInstance -ClassName 'Win32_Process' @sessionParams

                # 1c. Build a lookup table containing both Owner and Memory metrics
                $processLookup = @{}
                foreach ($proc in $processDetails) {
                    $ownerInfo = Invoke-CimMethod -InputObject $proc -MethodName GetOwner -ErrorAction SilentlyContinue
                    
                    $memoryMb = if ($proc.WorkingSetSize) { [math]::Round($proc.WorkingSetSize / 1MB, 2) } else { 0 }
                    $ownerName = if ($ownerInfo.ReturnValue -eq 0) { "$($ownerInfo.Domain)\$($ownerInfo.User)" } else { "N/A" }

                    $processLookup[$proc.ProcessId] = @{
                        Owner  = $ownerName
                        Memory = $memoryMb
                    }
                }

                # 1d. Synthesize and merge the performance data
                $results = foreach ($instance in $perfInstances) {
                    $processId = $instance.IDProcess
                    $extraData = $processLookup[$processId]

                    [pscustomobject]@{
                        PSComputerName       = $targetComputer
                        Name                 = $instance.Name
                        PercentProcessorTime = $instance.PercentProcessorTime
                        Memory_MB            = if ($extraData) { $extraData.Memory } else { 0 }
                        IDProcess            = $processId
                        OwnerID              = if ($extraData) { $extraData.Owner } else { "N/A" }
                    }
                }

                # Sort and return the requested top subset per machine
                $results | Sort-Object -Property PercentProcessorTime -Descending | Select-Object -First $topCount
            }
            catch {
                Write-Error "Thread failed for $targetComputer. Error: $_"
            }
        }

        # 2. Setup the Runspace Pool
        $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
        $runspacePool.Open()

        # 3. Create tracking objects for our running threads
        $threads = [System.Collections.Generic.List[pscustomobject]]::new()
        $finalOutput = [System.Collections.Generic.List[pscustomobject]]::new()

        # 4. Launch a thread for every computer in parallel
        foreach ($computer in $allComputers) {
            $psInstance = [powershell]::Create().AddScript($scriptBlock).AddArgument($computer).AddArgument($ProcessName).AddArgument($Top)
            $psInstance.RunspacePool = $runspacePool
            
            # BeginInvoke starts the thread asynchronously
            $handle = $psInstance.BeginInvoke()
            
            $threads.Add([pscustomobject]@{
                    Instance = $psInstance
                    Handle   = $handle
                    Computer = $computer
                })
        }

        Write-Verbose "All threads spun up. Collecting data as they complete..."

        # 5. Monitor and collect results from the threads
        while ($threads.Count -gt 0) {
            $completedThreads = [System.Collections.Generic.List[pscustomobject]]::new()
            
            foreach ($thread in $threads) {
                if ($thread.Handle.IsCompleted) {
                    # Extract the collected custom objects from the thread
                    $data = $thread.Instance.EndInvoke($thread.Handle)
                    if ($data) {
                        $finalOutput.AddRange($data)
                    }
                    
                    # Clean up the system memory for this thread
                    $thread.Instance.Dispose()
                    $completedThreads.Add($thread)
                }
            }

            # Remove completed tasks from active tracking loop
            foreach ($completed in $completedThreads) {
                [void]$threads.Remove($completed)
            }

            # Tiny pause to prevent CPU spiking while waiting
            Start-Sleep -Milliseconds 100
        }

        # 6. Tear down the pool safely
        $runspacePool.Close()
        $runspacePool.Dispose()

        # 7. Output processing logic
        if ($PSBoundParameters.ContainsKey('ExportCsvPath') -and $finalOutput.Count -gt 0) {
            $finalOutput | Export-Csv -Path $ExportCsvPath -NoTypeInformation -Encoding utf8 -Append
            Write-Verbose "Thread results successfully merged and exported to $ExportCsvPath"
        }
        else {
            $finalOutput
        }
    }
}