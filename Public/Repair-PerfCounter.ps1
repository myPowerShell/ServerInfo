function Repair-PerfCounter {
    
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )

    process {
        # Define the block of code to run on each target machine
        $ScriptBlock = {
            # Helper to run CMD commands and grab output safely
            function Invoke-CmdCommand {
                param([string]$Command)
                try {
                    $output = cmd.exe /c $Command 2>&1 | Out-String
                    return $output.Trim()
                } catch {
                    return $_.Exception.Message
                }
            }

            # 1. Rebuild System32
            $Sys32Result = Invoke-CmdCommand "cd c:\windows\system32 && lodctr /r"

            # 2. Rebuild SysWOW64
            $SysWOW64Result = Invoke-CmdCommand "cd c:\windows\syswow64 && lodctr /r"

            # 3. Resync WMI Performance
            $ResyncResult = Invoke-CmdCommand "winmgmt.exe /resyncperf"
            if ([string]::IsNullOrEmpty($ResyncResult)) { $ResyncResult = "Success (Executed Silently)" }

            # 4. Restart PLA Service
            try {
                Start-Sleep -Seconds 20
                $OldWarningPreference = $WarningPreference
                $WarningPreference = 'SilentlyContinue'
                Get-Service -Name "pla" | Restart-Service -ErrorAction Stop
                $PlaStatus = "Success"
                $WarningPreference = $OldWarningPreference
            } catch {
                $WarningPreference = $OldWarningPreference
                $PlaStatus = "Failed: $_"
            }

            # 5. Restart WMI Service
            try {
                Start-Sleep -Seconds 20
                $OldWarningPreference = $WarningPreference
                $WarningPreference = 'SilentlyContinue'
                Get-Service -Name "winmgmt" | Restart-Service -Force -ErrorAction Stop
                $WmiStatus = "Success"
                $WarningPreference = $OldWarningPreference
            } catch {
                $WarningPreference = $OldWarningPreference
                $WmiStatus = "Failed: $_"
            }

            # Return results as a custom object
            [PSCustomObject]@{
                ComputerName   = $env:COMPUTERNAME
                System32Result = $Sys32Result
                SysWOW64Result = $SysWOW64Result
                ResyncResult   = $ResyncResult
                PlaStatus      = $PlaStatus
                WmiStatus      = $WmiStatus
            }
        }

        # Loop through each computer passed to the parameter
        foreach ($Computer in $ComputerName) {
            try {
                        
                if ($Computer -as [ipaddress]){
                Write-Verbose "Detected IP Address and converting to HostName"
                $Computer = (Resolve-DnsName -Name $Computer | Select-Object NameHost).NameHost
                }

                # Execution Logic: Local vs Remote
                if ($Computer -eq $env:COMPUTERNAME -or $Computer -eq 'localhost' -or $Computer -eq '.') {
                    Invoke-Command -ScriptBlock $ScriptBlock
                } else {
                    # Added a quick connection check to establish WinRM Connection
                    if (New-CimSession -ComputerName $Computer   -ErrorAction SilentlyContinue) {
                        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ErrorAction Stop
                    } else {
                        throw "Failed to establish WinRM Connect to $ComputerName"
                    }
                }
            } catch {
                # Return a structured error row if a machine fails to connect or execute
                [PSCustomObject]@{
                    ComputerName   = $Computer
                    System32Result = "Skipped"
                    SysWOW64Result = "Skipped"
                    ResyncResult   = "Skipped"
                    PlaStatus      = "Failed Connection"
                    WmiStatus      = "Error: $_"
                }
            }
        }
    }
}



