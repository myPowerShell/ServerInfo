


function Restart-MyComputer {

    <#

.Synopsis
    This is a function to Restart Computers using WinRM Communication

.DESCRIPTION
    This is a function to Restart Computers vis WinRM, When WMI/RPC protocols are restricted in the environment

.NOTE

  File Name : Restart-MyComputer.ps1
  Author    : Srini Vemulapalli
  Requires  : PowerShell 5

.EXAMPLE

    PS> Restart-MyComputer  -ComputerName ServerName01 -WhatIf
        Restart-MyComputer  -ComputerName ServerName01 -Confirm
        Restart-MyComputer  -ComputerName ServerName01 -Confirm:$false
    

.EXAMPLE

    PS>  Restart-MyComputer -ComputerName (get-content servers.txt) -WhatIf

.LINK

#>


    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]
        [Alias('HostName', 'cn', 'IPAddress')]
        [string[]] $ComputerName
    )


    BEGIN {
        Write-Verbose "Script execution in Progress...  Please wait!"
    }

    PROCESS {
        $Max = $ComputerName.Count
        $Count = 1
        $ADUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Write-Log "Script execution in Progress...for $ADUser  Please wait!"
        foreach ($Computer in $ComputerName) {
            
            if ($PSCmdlet.ShouldProcess($Computer, "Restart")) {

                try {
                    Write-Verbose "-------------------------------"
                    Write-Verbose "Currently Processing Restart-MyComputer On $Computer ...$Count of $max"
                    $Computer = $Computer.trim()

                    $session = New-CimSession -ComputerName $Computer  -ErrorAction Stop -Verbose:$false
                    Write-Log "Currently Processing Restart-MyComputer On $Computer ...$Count of $max"

                    Invoke-CimMethod -Query 'Select * from Win32_OperatingSystem' -MethodName 'Reboot' -CimSession $Session | OUt-Null
                    Remove-CimSession -CimSession $Session
                    Write-Verbose "Computer restart command sent Sucesfully."            
                
                    Write-Log "Waiting for $Computer to go Offline."
                    While (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
                        Start-Sleep -Seconds 2
                    }

                    Write-Log "Waiting for $Computer to come back Online."
                    While (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet)) {
                        Start-Sleep -Seconds 23
                    }

            
                    $properties = @{ComputerName = $Computer
                        Status                   = 'Connected'
                        IsRestarted              = "Yes"
                    }
                 
                    Write-Log "$Computer  is back Online."

            
                }
                catch {
                    
                    Write-Verbose "Couldn't Connect to $Computer"
                    Write-Log "Couldn't Connect to $Computer" -Severity ERROR
                    
                    $properties = @{ComputerName = $Computer
                        Status                   = 'Disconnected'
                        IsRestarted              = "No"
                    }

                }
                finally {
                    
                    $obj = New-Object -TypeName PSObject -Property $properties
                    $obj.psobject.typenames.insert(0, '.\formats\ServerInfo.Custom.Objectfmt0')
                    Write-Output $obj
                                     
                } #End finally

                # Incrimenting count for interactive console text
                $count = $count + 1 
            }   # if stmt
            Else {
      
                Write-Log "User aborted this Operation[$ADUser]" -Severity INFO
            }
        }# End foreach

    } #End PROCESS    
         
    END {
        Write-Log "All restart Operations Completed"
         
    }


} #End FUNCTION



