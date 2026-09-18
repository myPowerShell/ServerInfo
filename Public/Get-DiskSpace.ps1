function Get-DiskSpace {
  
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]
        [Alias('HostName', 'cn', 'IPAddress')]
        [string[]] $ComputerName = $Env:ComputerName,

        [Parameter(Mandatory = $false,
        HelpMessage="Disk space Threshold")]
        [decimal]$threshold = 101
    )

    begin {
        Write-Verbose "Script execution in Progress... Please wait"
        # Safely mock-check or clear if Write-Log exists
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log "Script execution in Progress... Please wait"
        }
        
        # This runs ONCE at the very beginning of the pipeline lifecycle
        $results = @()
    }

    process {
        # This runs ONCE per item streaming down the pipeline
        $Max = $ComputerName.Count
        $count = 1
  
        foreach ($Computer in $ComputerName) {
    
            $Computer = $Computer.trim()
            Write-Verbose ("Currently Processing Server: $Count " + "of " + $max + "  " + $Computer) 
            if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                Write-Log ("Currently Processing Server: $Count " + "of " + $max + "  " + $Computer) -Severity INFO
            }
          
            Try {   
                $Items = Get-CimInstance -ComputerName $Computer cim_logicaldisk -ErrorAction Stop | 
                    Select-Object SystemName, DriveType, VolumeName, Name, 
                        @{n='Size_Gb' ; e={"{0:n2}" -f ($_.size/1gb)}}, 
                        @{n='FreeSpace_Gb' ; e={"{0:n2}" -f ($_.freespace/1gb)}}, 
                        @{n='PercentFree' ; e={"{0:n2}" -f ($_.freespace/$_.size*100)}} | 
                    Where-Object {$_.DriveType -eq 3 -and [decimal]$_.PercentFree -lt [decimal]$threshold}
                
                foreach ($Item in $Items) {   
                    $Properties = [Ordered] @{ 
                        ComputerName = $Computer
                        Status                              = "Connected"
                        Drive_Letter                        = $Item.Name
                        Volume_Name                         = $Item.VolumeName
                        Size_Gb                             = $Item.Size_Gb
                        FreeSpace_Gb                        = $Item.FreeSpace_Gb
                        PercentFree                         = $Item.PercentFree
                    }

                    $results += New-Object -TypeName PSObject -Property $Properties
                }
            }
            catch {
                $Message = $($_.Exception.Message)
                if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                    Write-Log "Unable to Connect to $Computer , $Message Please check" -Severity ERROR
                }
                Write-Verbose "Entered Disconnected Hosts Section"
                $Properties = [Ordered] @{ 
                    ComputerName = $Computer
                    Status                              = "Unable_to_Connect"
                    Drive_Letter                        = $null
                    Volume_Name                         = $null
                    Size_Gb                             = $null
                    FreeSpace_Gb                        = $null
                    PercentFree                         = $null
                }
                
                # FIXED TYPO HERE (from $resluts to $results)
                $results += New-Object -TypeName PSObject -Property $Properties
            }
          
            $count = $count + 1 
        } # foreach
    }

    end {
        # This runs ONCE after all pipeline operations conclude
        Write-Output $results
        Write-Verbose "Completed Processing this command" 
    }
}
