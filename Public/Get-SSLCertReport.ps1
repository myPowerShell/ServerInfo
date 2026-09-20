

function Get-SSLCertReport {

    <#
.SYNOPSIS
 Get SSL Cert report form Server

.DESCRIPTION
 This function will generate  a report of SSL Certs from a Server or Servers

 .NOTE
  File Name : Get-SSLCertReport.ps1
  Author    : Srini Vemulapalli
  Requires  : PowerShell 5

  .EXAMPLE

    PS>  Get-SSLCertReport -ComputerName <YourServerName> | ft

  .EXAMPLE

    PS>  Get-SSLCertReport -ComputerName (get-content servers.txt)  |ft

  .EXAMPLE
   
    PS>  Get-SSLCertReport -ComputerName (get-content servers.txt)  | Select-Object ComputerName, Status, NotAfter, Subject, Issuer, DaysRemaining, TimeStamp |
         Export-Csv ("Get-SSLCertReport.csv") -NoTypeInformation
  #>


    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage = "This. Computer. Name.")]
        [Alias('HostName', 'cn', 'IPAddress')]
        [String[]]$ComputerName
    )

    BEGIN { 
        Write-Verbose "Script execution in Progress... Please wait" 
    }

    PROCESS {
        $User = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Write-Log "Script Execution in Progress....for $User" -Severity INFO
        $Max = $ComputerName.Count
        $Count = 1
        
        foreach ($computer in $ComputerName) {
            $Computer = $Computer.trim()

            try {
                Write-Verbose "-------------------------------"
                Write-Verbose "Retrieving data from $Computer"
                Write-Log ("Currently Processing Server: $Count " + "of " + $max + "  " + $Computer)
                New-CimSession -ComputerName $Computer -ErrorAction Stop | out-null
                Write-Log "Gathering SSL Cert Details from $Computer" -Severity INFO
           
                if ($Env:ComputerName -eq $Computer) {
                    $certs = Get-ChildItem -Path "Cert:\LocalMachine\My" -Recurse | Select-Object NotAfter, Subject, Issuer
                }
                else {
                    $certs = Invoke-Command -ComputerName $Computer {
                        Get-ChildItem -Path "Cert:\LocalMachine\My" -Recurse | Select-Object NotAfter, Subject, Issuer
                    }
                }
                
                Foreach ($cert in $certs) {
                    $Date = Get-Date -Format "yyyyMM_dd_HH_mmss"
        
                    $issuer = ($cert.Issuer -split ",")[0].Trim()
                    $subject = ($cert.Subject -split ",")[0].Trim()
                    $daysRemaining = ($cert.NotAfter - (Get-Date)).Days
                    $Properties = [Ordered] @{ ComputerName = $Computer
                        Status                              = "Connected"
                        NotAfter                            = $cert.NotAfter
                        Subject                             = $subject
                        Issuer                              = $issuer
                        DaysRemaining                       = $daysRemaining
                        TimeStamp                           = [String]$Date 
                    }

                    $Objoutput = New-Object -TypeName PSObject -Property $Properties
                    Write-output $Objoutput

                } 
                
                
            
            }
            catch {
                    
                Write-Log $_.Exception.Message -Severity ERROR
                Write-Log "Unable to connect via WinRM to this Server $Computer" -Severity ERROR
                $Date = Get-Date -Format "yyyyMM_dd_HH_mmss"
                $Properties = [Ordered] @{ ComputerName = $Computer
                    Status                              = "NotConnected"
                    NotAfter                            = $null
                    Subject                             = $null
                    Issuer                              = $null
                    DaysRemaining                       = $null
                    TimeStamp                           = [String]$Date 
                }
                   
                $Objoutput = New-Object -TypeName PSObject -Property $Properties
                Write-output $Objoutput
            } 

            $Count = $Count + 1
        }# End foreach

    } #End PROCESS    
         
    END {
        Write-Log "Script Execution Completed" -Severity INFO
    }
         
          
} # End function





