function Get-DotNetVersion {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )

    foreach ($Computer in $ComputerName) {
        if( New-CimSession -ComputerName $Computer -ErrorAction SilentlyContinue){ 
            
    $LocalScript = 
    { 
        $rel = Get-ItemPropertyValue -LiteralPath 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release 
    
        if ($rel -ge 533320) { $Version = "4.8.1" }
        elseif ($rel -ge 528040) { $Version = "4.8" }
        elseif ($rel -ge 461808) { $Version = "4.7.2" }
        else { $Version = "4.5" }

        $Properties = [Ordered] @{ 
            ComputerName = $Env:ComputerName 
            Status       = "Connected" 
            Component    = "MS.Net Framework" 
            Version      = $Version 
            Release      = $rel 
        } 
    
        $Objoutput = New-Object -TypeName PSObject -Property $Properties
    
        # Serialize the object directly to a CliXML text stream
        [System.Management.Automation.PSSerializer]::Serialize($Objoutput)
    }
            
                # Convert to UTF-16LE bytes and encode
                $bytes = [System.Text.Encoding]::Unicode.GetBytes($LocalScript.ToString())
                $Encoded = [Convert]::ToBase64String($bytes)
           
    
                $XmlStream = Invoke-Command -Computername $Computer -ScriptBlock { 
                                powershell.exe -NoProfile -EncodedCommand $using:Encoded
                            }

                # Deserialize on your host to restore your original formatted objects
                $FinalOutput = [System.Management.Automation.PSSerializer]::Deserialize($XmlStream)

                # Display the cleanly formatted table locally
                  Write-Output $FinalOutput 
       
        }
        else{
                    $Properties = [Ordered] @{ ComputerName = $Computer
                            Status = "WinRM_Connection_Failed"
                            Component= $null
                            Version= $null
                            Release = $null
                            }
                    $Objoutput = New-Object -TypeName PSObject -Property $Properties
                    Write-output $Objoutput
        }
    }

}




    <# 
        Get-DotNetVersion -ComputerName (Get-Content "Servers.txt") | Format-Table -AutoSize -Wrap
    
        $Date = Get-Date -Format "yyyyMMddhhmmss"
        Get-DotNetVersion -ComputerName (Get-Content "Servers.txt") | Export-Csv ("Get-DotNetVersion_" + $date + ".csv") -NoTypeInformation

    #>
    

