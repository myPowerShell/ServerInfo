     
   Function Get-SystemLogonLogoffReport {  

<#

.SYNOPSIS
   This function will provide Logon and Logoff report for a Server or Servers



.EXAMPLE
   Get-SystemLogonLogoffReport -DaysFromToday 10 

.EXAMPLE
   Get-SystemLogonLogoffReport -ComputerName Server01, Server02


.EXAMPLE
    Get-SystemLogonLogoffReport -ComputerName Server01  -DaysFromToday 5 -MaxEvents 5 | Sort-Object Time -Descending | ft

.PARAMETER DaysFromToday
   Specify the amount of days in the past you would like to search for


#>


     
     [CmdletBinding()]
     param(
         [Parameter(
             Mandatory = $false,
             ValueFromPipeline = $true,
             ValueFromPipelineByPropertyName = $true

          )]
          
          [string[]] $ComputerName = $env:COMPUTERNAME,
          [int]     $DaysFromToday = 7,
          [int]     $MaxEvents = 100

         )

         
            Write-Host "Script execution in Progress... Please wait" -ForegroundColor Yellow


            $Max = $Computername.Count
            $count = 1
            $Results = @(); 
            foreach ($Computer in $ComputerName) {

            $Computer = $Computer.trim()
            Write-Host ("Currently Processing Server: $Count "+"of "+ $max + "  " + $Computer)  
               
                try{
                    New-CimSession -ComputerName $Computer  -ErrorAction Stop | Out-Null

                    $remoteOutput = Invoke-Command -ComputerName $Computer { param($rDaysFromToday, $rMaxEvents)

                    $ItemList = Get-EventLog system -ComputerName $Env:ComputerName -Source Microsoft-Windows-Winlogon -After (Get-Date).AddDays(-$rDaysFromToday) -Newest $rMaxEvents
          

                    ForEach ($Item in $ItemList) {

                            if($Item.instanceid -eq 7001) {
                            $type = "Logon"
                            } Elseif ($Item.instanceid -eq 7002){
                            $type="Logoff"
                            } Else {

                            Continue
                            }
               

                        $Properties = [Ordered] @{
                        ComputerName = $Env:ComputerName
                        Status = "Connected"
                        Time = $Item.TimeWritten
                        Event = $type
                        UserID = (New-Object System.Security.Principal.SecurityIdentifier $Item.ReplacementStrings[1]).Translate([System.Security.Principal.NTAccount])
                        }

                        $Objoutput = New-Object -TypeName PSObject -Property $Properties
                        Write-output $Objoutput

                       }
                  

                  } -ArgumentList $DaysFromToday, $MaxEvents # Invoke

                  $Results += $remoteOutput

                } catch {
                        
                        Write-Verbose $_.Exception.Message
                       
                        $Properties = [Ordered] @{
                        ComputerName = $Computer
                        Status = "NotConnected"
                        Time = $null
                        Event = $null
                        UserID = $null
                        }
                        
                        $Objoutput = New-Object -TypeName PSObject -Property $Properties
                        $Results += $Objoutput

                }

        
        # Incrimenting count for interactive console text
        $Count = $Count + 1

       }

        Write-Output $Results
    } # End Function



