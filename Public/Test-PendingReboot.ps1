function Test-PendingReboot {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$ComputerName
    )

    process {
        foreach ($Computer in $ComputerName) {
            $Status = [PSCustomObject]@{
                ComputerName      = $Computer
                PendingReboot     = $false
                ComponentBased    = $false
                WindowsUpdate     = $false
                PendingRename     = $false
                SCCM              = $false
                Error             = $null
            }

            if (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet)) {
                $Status.Error = "Offline / Unreachable"
                $Status
                continue
            }

            try {
                # 1. Check Component-Based Servicing
                $CBS = Invoke-Command -ComputerName $Computer -ScriptBlock {
                    Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
                } -ErrorAction Stop
                if ($CBS) { $Status.ComponentBased = $true; $Status.PendingReboot = $true }

                # 2. Check Windows Update Agent
                $WU = Invoke-Command -ComputerName $Computer -ScriptBlock {
                    Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
                }
                if ($WU) { $Status.WindowsUpdate = $true; $Status.PendingReboot = $true }

                # 3. Check Pending File Rename Operations
                $Rename = Invoke-Command -ComputerName $Computer -ScriptBlock {
                    (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Session Manager").PendingFileRenameOperations
                }
                if ($Rename) { $Status.PendingRename = $true; $Status.PendingReboot = $true }

                # 4. Check CCM / SCCM Client (If applicable)
                $CCM = Invoke-Command -ComputerName $Computer -ScriptBlock {
                    if (Test-Path "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData") { $true }
                    elseif (Get-WmiObject -Namespace "root\ccm\ClientSDK" -Class "CCM_ClientUtilities" -ErrorAction SilentlyContinue) {
                        ([wmiclass]"root\ccm\ClientSDK:CCM_ClientUtilities").DetermineIfRebootPending().RebootPending
                    } else { $false }
                }
                if ($CCM) { $Status.SCCM = $true; $Status.PendingReboot = $true }

            } catch {
                $Status.Error = $_.Exception.Message
            }

            $Status
        }
    }
}



