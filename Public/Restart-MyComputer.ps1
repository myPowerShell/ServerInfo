
function Restart-MyComputer {

<#
.Synopsis
    This is a function to Restart Computers using WinRM Communication

.DESCRIPTION
    This is a function to Restart Computers vis WinRM, When WMI/RPC protocols are restricted in the environment

.NOTE

  File Name : Restart-MyComputer.ps1
  Author    : myPowerShell
  Requires  : PowerShell 5

.EXAMPLE

    PS> Restart-MyComputer -ComputerName localhost -Verbose
    

.EXAMPLE

    PS>  Restart-MyComputer -ComputerName (get-content servers.txt)  | ft

.LINK

#>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string[]] $ComputerName
    )


    BEGIN {
        Write-Verbose "Script execution in Progress... Please wait!"
    }

    PROCESS {
        $Max = $ComputerName.Count
        $Count = 1
       
        
        foreach ($computer in $ComputerName) {
            $Computer = $Computer.trim()

            if ($PSCmdlet.ShouldProcess($Computer, "Restart")) {

                try {
                
                    $session = New-CimSession -ComputerName $Computer  -ErrorAction Stop -Verbose:$false
                    Write-Verbose "-------------------------------"
                    Write-Verbose "Currently Processing Restart-MyComputer On $Computer ...$Count of $max"
                    Write-Log "Currently Processing Restart-MyComputer On $Computer ...$Count of $max"

                    Invoke-CimMethod -Query 'Select * from Win32_OperatingSystem' -MethodName 'Reboot' -CimSession $Session | OUt-Null
                    Remove-CimSession -CimSession $Session
                    Write-Log "Computer restart command sent Sucesfully."            
                
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
            }
            Else {

                Write-Log "User Aborted this Operation" -Severity INFO
            } 

        }# End foreach

    } #End PROCESS    
         
    END {
        Write-Log "All restart Operations Completed"
         
    }


} #End FUNCTION



