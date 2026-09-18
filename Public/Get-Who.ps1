function Get-Who {

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )



  PROCESS{
        $User = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Write-Verbose "Script execution in Progress... Please wait"
        WriteLog "Script Execution in Progress....for $User" -Severity INFO
        $Max = $ComputerName.Count
        $Count = 1
        
        foreach ($computer in $ComputerName) {
                $Computer = $Computer.trim()

            try{
            Write-Verbose "-------------------------------"
            Write-Verbose "Retrieving data from $Computer"
            WriteLog ("Currently Processing Server: $Count "+"of "+ $max + "  " + $Computer)
            New-CimSession -ComputerName $Computer -ErrorAction Stop | out-null
            WriteLog "Gathering RDP Connection Details from $Computer" -Severity INFO
           
            if($Env:ComputerName -eq $Computer){
           
            $Items = qwinsta /server:localhost | ForEach-Object {
            # Trim external padding and replace 2 or more spaces with a single comma
             $_.Trim() -replace '\s{2,}', ','
            } | ConvertFrom-Csv -Header "SessionName", "Username", "Id", "State", "Type", "Device"
            $Items = $Items | Where-Object { $_.SessionName -ne "SESSIONNAME" -and $_.Id -match '\d+' }
                
                if ($?) {
                     WriteLog "qwinsta.exe Command Execution: Success on $Computer" -Severity INFO
                        } else {
                        WriteLog "qwinsta.exe Command Execution: Failure on $Computer" -Severity ERROR
                        }
                
                if ($null -eq $Items){
                 WriteLog "No RDP Connections found on $Computer" -Severity WARNING
                 Write-Verbose "No RDP Connections found on $Computer"
                }




            }else{
               $Items = Invoke-Command -ComputerName $Computer {
          
            $Items = qwinsta /server:$Env:ComputerName | ForEach-Object {
            # Trim external padding and replace 2 or more spaces with a single comma
             $_.Trim() -replace '\s{2,}', ','
            } | ConvertFrom-Csv -Header "SessionName", "Username", "Id", "State", "Type", "Device"
            $Items = $Items | Where-Object { $_.SessionName -ne "SESSIONNAME" -and $_.Id -match '\d+' }

             Write-output $Items

                }


                 if ($?) {
                            WriteLog "qwinsta.exe Command Execution: Success on $Computer" -Severity INFO
                            } else {
                                WriteLog "qwinsta.exe Command Execution: Failure on $Computer" -Severity ERROR
                            }

                 if ($null -eq $Items){
                 WriteLog "No RDP Connections found on $Computer" -Severity WARNING
                 Write-Verbose "No RDP Connections found on $Computer"
                }
             }
                    Foreach ($Item in $Items){
                    $Date = Get-Date -Format "yyyyMM_dd_HH_mmss"

                    $Properties = [Ordered] @{ ComputerName = $Computer
                                   Status = "Connected"
                                   SessionName = $Item.SessionName
                                   USERNAME=$Item.USERNAME
                                   ID=$Item.ID
                                   STATE =  $Item.STATE
                                   TimeStamp= [String]$Date 
                                   }

                    $Objoutput = New-Object -TypeName PSObject -Property $Properties
                    Write-output $Objoutput

                    } 
                
                
            
               }  catch {
                    
                    WriteLog $_.Exception.Message -Severity ERROR
                    WriteLog "Unable to connect via WinRM to this Server $Computer" -Severity ERROR
                    $Date = Get-Date -Format "yyyyMM_dd_HH_mmss"
                    $Properties = [Ordered] @{ ComputerName = $Computer
                                   Status = "NotConnected"
                                   SessionName = $null
                                   USERNAME=$null
                                   ID=$Item.$null
                                   STATE =  $null
                                   TimeStamp= [String]$Date 
                                   }
                   
                    $Objoutput = New-Object -TypeName PSObject -Property $Properties
                    Write-output $Objoutput
                    } 

        $Count = $Count + 1
        
        $oresult = $Items |Select-Object SessionName, UserName, ID, State | ft  | Out-String
        WriteLog "Output: $oresult" -Severity INFO
        }# End foreach

     } #End PROCESS    
         
         END{
             WriteLog "Script Execution Completed" -Severity INFO
            }
         
          
} # End function



function WriteLog{
      
      Param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR')]
        [string]$Severity = 'INFO'
        )
    
    $CallStack = Get-PSCallStack
    $CallingFunction = $CallStack[1].Command

        if ($CallingFunction -eq '<ScriptBlock>') {
        $CallingFunction = "Module_MainScript"
    }
    
    $logDate = Get-Date -Format "yyyyMMdd"

    $LogFolder = "C:\Temp\Logs"
    if (-not (Test-Path $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder | Out-Null }
    $LogFile = Join-Path $LogFolder ("$CallingFunction" +"_"+$logDate+".log")
     
     $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
     $LogLine = "[$Timestamp] [$Severity] $Message"
     
    # Append to the dedicated log file
    $LogLine | Add-Content -Path $LogFile
    # $LogLine | Tee-Object -FilePath $LogFile -Append
              
} #End Sub Function (WriteLog)











