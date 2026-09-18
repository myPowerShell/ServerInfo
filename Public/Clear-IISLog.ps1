Function Clear-IISLog {

    <#

.SYNOPSIS
Script to Clear dated IIS Logs from a server or servers

.DESCRIPTION
This script will clear dated IIS Logs from server or servers by leaving logs that are created for last number of days from today

.NOTE
  File Name : Clear-IISLogs.ps1
  Author    : Srini Vemulapalli
  Requires  : PowerShell 5
  
.EXAMPLE
  Clear-IISLogs -ComputerName <YourHostName> -IISLogPath "E:\logs\W3SVC1" -DaysFromToday 60

    #>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]
        [Alias('HostName', 'cn', 'IPAddress')]
        [string[]] $ComputerName,

        [Parameter(Mandatory = $false,
            HelpMessage = "IIS Logs Path")]
        [String]$IISLogPath = "E:\logs\W3SVC1",

        [Parameter(Mandatory = $true,
            HelpMessage = "Log Retention Days, Mandatory")]
        [int]$LogRetentionDays
    )
      
    $Max = $ComputerName.Count
    $ADUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-output "Script execution in Progress...for $ADUser  Please wait!" 
    Write-output "You can check log for Status at C:\Temp\Logs on $Env:ComputerName" 
    WriteLog "Script execution in Progress...for $ADUser  Please wait!"
    $count = 1
    @(foreach ($Computer in $ComputerName) {
            $timestmp = Get-Date -Format "yyyy-MM-dd-hhmmss"
            $timestamp = $timestmp.ToString()
            $Computer = $Computer.trim()
            $cIISLogPath = $null
            WriteLog ("Currently Processing Server: $Count " + "of " + $max + "  " + $Computer)

            if (New-CimSession -ComputerName $Computer -ErrorAction SilentlyContinue) {
                
                Try {

                    # Get IIS Log location from Server to compare with user supplied path during execution
                    $cIISLogPath = Invoke-Command -ComputerName $Computer -ScriptBlock {
                        # Try_Catch Block to Suppress Errors, when server name was supplied but with no IIS 
                        try {
                            $PathLookup = Select-String -Path "C:\Windows\System32\inetsrv\config\applicationHost.config" -Pattern "logFile logFormat" | Out-String

                            if ($pathLookup -match '"([^"]+)"[^"]*$') {
                                $LogPath = $Matches[1]
                            }

                            $RemoteIISLogPath = Join-Path $LogPath  W3SVC1

                            Return  $RemoteIISLogPath
                        }
                        catch {
                            Write-Verbose "Failed to Process $Env:ComputerName`: $_" 
                        }

                    }  # invoke #1

                }
                Catch {
                
                    WriteLog "Encounterd errors while validating IIS on $Computer" -Severity ERROR
                 
                }
                      
                      
                if ($null -eq $cIISLogPath) {
                    WriteLog "Please validate IIS is installed on this Server $Computer" -Severity ERROR
                    Write-Verbose "Please validate IIS is installed on this Server $Computer"
                    $count = $count + 1 
                   
                    $Properties = [Ordered] @{ ComputerName = $Computer
                        Status                              = "Connected"
                        Cleared_IIS_Log_Path                = "noIIS"
                        Free_SpaceBefore                    = $null
                        Free_SpaceAfter                     = $null
                        TimeStamp                           = $timestamp
                    }
                    
                    $Objoutput = New-Object -TypeName PSObject -Property $Properties
                    Write-output  $Objoutput
                    $FoPath = $cIISLogPath

                    Continue
                }
                elseif (-not ($IISLogPath -eq $cIISLogPath)) {
                        
                    $FoPath = $cIISLogPath
         
                }
                else {
                        
                    $FoPath = $IISLogPath
                       
                }

                $OutputObjB = Invoke-Command -ComputerName $Computer -ScriptBlock { param($RemoteFolder)
                    # Extract the drive letter from the path
                    $driveLetter = (Get-Item $RemoteFolder).PSDrive.Name
                    # Get volume information and calculate sizes
                    $FreeSpaceB = Get-Volume -DriveLetter $driveLetter | Select-Object `
                        DriveLetter,
                    FileSystem,
                    @{Name = "TotalSize_GB"; Expression = { [Math]::Round($_.Size / 1GB, 2) } },
                    @{Name = "FreeSpace_GB"; Expression = { [Math]::Round($_.SizeRemaining / 1GB, 2) } },
                    @{Name = "PercentFree"; Expression = { [Math]::Round(($_.SizeRemaining / $_.Size) * 100, 1) } }
                    Return $FreeSpaceB
                } -ArgumentList $FoPath
               
                #Action Block
                Invoke-Command -ComputerName $Computer -ScriptBlock { param($RemoteFolder, $RemoteRetentionDays)
                    $logDate = Get-Date -Format "yyyyMMddhhmmss"
                    $LogFolder = "C:\Temp\Logs"
                    if (-not (Test-Path $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder | Out-Null }
                    $LogFile = Join-Path $LogFolder ("deleted_IIS_Logs" + "_" + $logDate + ".log")

                    Get-ChildItem $RemoteFolder -Recurse -Force -ErrorAction Silentlycontinue |
                    Where-Object { !$_.PsIsContainer -and $_.LastWriteTime -lt (Get-Date).AddDays(-$RemoteRetentionDays) } |
                    ForEach-Object {
                        $_ | Remove-Item -force
                        $_.FullName | Out-File  $LogFile -Append
                    } 

                } -ArgumentList $FoPath, $LogRetentionDays

                $OutputObjA = Invoke-Command -ComputerName $Computer -ScriptBlock { param($RemoteFolder)
                    # Extract the drive letter from the path
                    $driveLetter = (Get-Item $RemoteFolder).PSDrive.Name

                    # Get volume information and calculate sizes
                    $FreeSpaceA = Get-Volume -DriveLetter $driveLetter | Select-Object `
                        DriveLetter,
                    FileSystem,
                    @{Name = "TotalSize_GB"; Expression = { [Math]::Round($_.Size / 1GB, 2) } },
                    @{Name = "FreeSpace_GB"; Expression = { [Math]::Round($_.SizeRemaining / 1GB, 2) } },
                    @{Name = "PercentFree"; Expression = { [Math]::Round(($_.SizeRemaining / $_.Size) * 100, 1) } }
                    Return $FreeSpaceA
                } -ArgumentList $FoPath
          
           
                $Properties = [Ordered] @{ ComputerName = $Computer
                    Status                              = "Connected"
                    Cleared_IIS_Log_Path                = $FoPath
                    Free_SpaceBefore                    = $OutputObjB.FreeSpace_GB
                    Free_SpaceAfter                     = $OutputObjA.FreeSpace_GB
                    TimeStamp                           = $timestamp
                }
       
            }
            else {

                WriteLog "Unable to connect to $Computer , Please check" -Severity ERROR
                $Properties = [Ordered] @{ ComputerName = $Computer
                    Status                              = "Unable_to_Connect"
                    Cleared_IIS_Log_Path                = $null
                    Free_SpaceBefore                    = $null
                    Free_SpaceAfter                     = $null
                    TimeStamp                           = $timestamp
                }
            }

            $Objoutput = New-Object -TypeName PSObject -Property $Properties
            Write-output  $Objoutput
          
            # Incrimenting count for interactive console text
            $count = $count + 1 
      
        }) #End Foreach #1

    WriteLog "Script Execution Completed, A log files will be created on each Server at C:\Temp\Logs with deleted file Names" -Severity INFO
    Write-output "" # Adding blank line to enhance on screen output view
    Write-output "Script Execution Completed, A log files will be created on each Server at C:\Temp\Logs with deleted file Names"

} # End Function


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

