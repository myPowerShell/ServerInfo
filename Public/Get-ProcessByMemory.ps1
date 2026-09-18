function Get-ProcessByMemory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string[]]$ComputerName,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$ExportCsvPath,

        [Parameter(Mandatory = $false)]
        [double]$MinPctThreshold = 0.0,

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
            param($targetComputer, $threshold)
            try {
                # Note: CIM sessions are used here to query remote machines over standard WSMAN protocol
                $sessionParams = @{ ComputerName = $targetComputer; ErrorAction = 'Stop' }
                
                $os = Get-CimInstance Win32_OperatingSystem -Property TotalVisibleMemorySize, FreePhysicalMemory @sessionParams
                $totalMemoryBytes = $os.TotalVisibleMemorySize * 1KB
                $inUseMemoryBytes = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB
                
                $grouped = Get-CimInstance Win32_Process -Filter "Name <> 'System Idle Process'" @sessionParams | 
                    Group-Object -Property Name

                $results = foreach ($item in $grouped) {
                    $stat = $item.Group | Measure-Object -Property WorkingSetSize -Sum
                    $pct = if ($inUseMemoryBytes -gt 0) { [math]::Round(($stat.Sum / $inUseMemoryBytes) * 100, 2) } else { 0 }

                    if ($pct -ge $threshold) {
                        [pscustomobject]@{
                            ComputerName  = $targetComputer
                            ProcessName   = $item.Name
                            InstanceCount = $item.Count
                            TotalMemoryGB = [math]::Round($totalMemoryBytes / 1GB, 2)
                            WorkingSetGB  = [math]::Round($stat.Sum / 1GB, 2)
                            PctUsedMemory = $pct
                        }
                    }
                }
                # Return the top 10 for this machine
                $results | Sort-Object -Property PctUsedMemory -Descending | Select-Object -First 10
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
            $psInstance = [powershell]::Create().AddScript($scriptBlock).AddArgument($computer).AddArgument($MinPctThreshold)
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
                    if ($data) { $finalOutput.AddRange($data) }
                    
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
        } else {
            $finalOutput
        }
    }
}


