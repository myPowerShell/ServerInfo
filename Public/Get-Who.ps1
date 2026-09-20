function Get-Who {

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )



    PROCESS {
        $User = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Write-Verbose "Script execution in Progress... Please wait"
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
                Write-Log "Gathering RDP Connection Details from $Computer" -Severity INFO
           
                if ($Env:ComputerName -eq $Computer) {
           
                    $Items = qwinsta /server:localhost | ForEach-Object {
                        # Trim external padding and replace 2 or more spaces with a single comma
                        $_.Trim() -replace '\s{2,}', ','
                    } | ConvertFrom-Csv -Header "SessionName", "Username", "Id", "State", "Type", "Device"
                    $Items = $Items | Where-Object { $_.SessionName -ne "SESSIONNAME" -and $_.Id -match '\d+' }
                
                    if ($?) {
                        Write-Log "qwinsta.exe Command Execution: Success on $Computer" -Severity INFO
                    }
                    else {
                        Write-Log "qwinsta.exe Command Execution: Failure on $Computer" -Severity ERROR
                    }
                
                    if ($null -eq $Items) {
                        Write-Log "No RDP Connections found on $Computer" -Severity WARNING
                        Write-Verbose "No RDP Connections found on $Computer"
                    }




                }
                else {
                    $Items = Invoke-Command -ComputerName $Computer {
          
                        $Items = qwinsta /server:$Env:ComputerName | ForEach-Object {
                            # Trim external padding and replace 2 or more spaces with a single comma
                            $_.Trim() -replace '\s{2,}', ','
                        } | ConvertFrom-Csv -Header "SessionName", "Username", "Id", "State", "Type", "Device"
                        $Items = $Items | Where-Object { $_.SessionName -ne "SESSIONNAME" -and $_.Id -match '\d+' }

                        Write-output $Items

                    }


                    if ($?) {
                        Write-Log "qwinsta.exe Command Execution: Success on $Computer" -Severity INFO
                    }
                    else {
                        Write-Log "qwinsta.exe Command Execution: Failure on $Computer" -Severity ERROR
                    }

                    if ($null -eq $Items) {
                        Write-Log "No RDP Connections found on $Computer" -Severity WARNING
                        Write-Verbose "No RDP Connections found on $Computer"
                    }
                }
                Foreach ($Item in $Items) {
                    $Date = Get-Date -Format "yyyyMM_dd_HH_mmss"

                    $Properties = [Ordered] @{ ComputerName = $Computer
                        Status                              = "Connected"
                        SessionName                         = $Item.SessionName
                        USERNAME                            = $Item.USERNAME
                        ID                                  = $Item.ID
                        STATE                               = $Item.STATE
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
                    SessionName                         = $null
                    USERNAME                            = $null
                    ID                                  = $Item.$null
                    STATE                               = $null
                    TimeStamp                           = [String]$Date 
                }
                   
                $Objoutput = New-Object -TypeName PSObject -Property $Properties
                Write-output $Objoutput
            } 

            $Count = $Count + 1
        
            $oresult = $Items | Select-Object SessionName, UserName, ID, State | format-table  | Out-String
            Write-Log "Output: $oresult" -Severity INFO
        }# End foreach

    } #End PROCESS    
         
    END {
        Write-Log "Script Execution Completed" -Severity INFO
    }
         
          
} # End function















