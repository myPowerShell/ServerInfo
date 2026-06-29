  
function Get-DiskSpace {

<#
.SYNOPSIS
 Get DiskSpace details from Server or Servers


.DESCRIPTION
 This script check on a server or list of servers to provide Disk Space by target % free less than 20% on a Drive, you can set your own threshold

.NOTE
  File Name : Get-DiskSpace.ps1
  Author    : myPowerShell
  Requires  : PowerShell 5
  
  
.EXAMPLE
   Get-DiskSpace

.EXAMPLE
   Get-Content ("Servers.txt") | Get-Diskspace | ft -AutoSize

.EXAMPLE
   Get-DiskSpace -ComputerName mylocalhost| ? {$_.PercentFree -lt 20}| select ComputerName, status, Drive_Letter, Freespace_GB, PercentFree |  Export-Csv C:\temp\test.csv -NoTypeInformation

#>
  
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]
        [Alias('CN', 'Computer', 'IPAddress')]
        [string[]] $ComputerName

    )




    Write-Verbose "Script execution in Progress... Please wait"
    WriteLog "Script execution in Progress... Please wait"
    $Max = $ComputerName.Count
    $count = 1

    $results = @()

    foreach ($Computer in $ComputerName) {
    
        $Computer = $Computer.trim()
        Write-Verbose ("Currently Processing Server: $Count " + "of " + $max + "  " + $Computer) 
        WriteLog ("Currently Processing Server: $Count " + "of " + $max + "  " + $Computer) -Severity INFO
      
        Try {   
            $session = New-CimSession -ComputerName $Computer  -ErrorAction Stop
            $Items = Get-CimInstance -CimSession $session cim_logicaldisk -ErrorAction stop | Select-Object SystemName, DriveType, VolumeName, Name, @{n = 'Size_Gb' ; e = { "{0:n2}" -f ($_.size / 1gb) } }, @{n = 'FreeSpace_Gb' ; e = { "{0:n2}" -f ($_.freespace / 1gb) } }, @{n = 'PercentFree' ; e = { "{0:n2}" -f ($_.freespace / $_.size * 100) } } | Where-Object { $_.DriveType -eq 3 } #-and [decimal]$_.PercentFree -lt [decimal]$PercentFree}

            @(foreach ($Item in $Items) {   
                    $Properties = [Ordered] @{ ComputerName = $Computer
                        Status                              = "Connected"
                        Drive_Letter                        = $Item.Name
                        Volume_Name                         = $Item.VolumeName
                        Size_Gb                             = $Item.Size_Gb
                        FreeSpace_Gb                        = $Item.FreeSpace_Gb
                        PercentFree                         = $Item.PercentFree
                    }

                    $Objoutput = New-Object -TypeName PSObject -Property $Properties
                    $results += $Objoutput
     
                }) # end 2nd foreach
       

        }
        catch {

            $Message = $($_.Exception.Message)
            WriteLog "Unable to Connect to $Computer , $Message Please check" -Severity ERROR
            Write-Verbose "Entered Disconnected Hosts Section"
            $Properties = [Ordered] @{ ComputerName = $Computer
                Status                              = "Unable_to_Connect"
                Drive_Letter                        = $null
                Volume_Name                         = $null
                Size_Gb                             = $null
                FreeSpace_Gb                        = $null
                PercentFree                         = $null
            }
            $Objoutput = New-Object -TypeName PSObject -Property $Properties
            $results += $Objoutput

        }
      
        
 
        Remove-CimSession -Name $session
        # Incrimenting count for interactive console text
        $count = $count + 1 


      
    } # foreach
    Write-output $results
    Write-Verbose "Completed Processing this command" 

} #Function Closing


function WriteLog {
      
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
    $LogFile = Join-Path $LogFolder ("$CallingFunction" + "_" + $logDate + ".log")
     
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$Timestamp] [$Severity] $Message"
     
    # Append to the dedicated log file
    $LogLine | Add-Content -Path $LogFile
    # $LogLine | Tee-Object -FilePath $LogFile -Append
              
} #End FUNCTION


