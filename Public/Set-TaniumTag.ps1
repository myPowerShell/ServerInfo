function Set-TaniumTag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String[]]$ComputerName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Patch_NoPatch', 'SRV_MW01',
        'SRV_MW07', 'SRV_MW18', 'SRV_MW06',
        'WINSRV_PATCH_STANDARD')]
        [String]$TagName,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^CHG\d{7}$')]
        [String]$ChangeNumber
    )

    Begin {
        $CurrentTime = Get-Date -Format "MM/dd/yyyy h:mm:ss tt"
        $TagValue = "added: ${CurrentTime}_$ChangeNumber"
        $AllComputers = [System.Collections.Generic.List[String]]::new()
    }

    Process {
        foreach ($Computer in $ComputerName) {
            if (-not [String]::IsNullOrWhiteSpace($Computer)) {
                $AllComputers.Add($Computer.Trim())
            }
        }
    }

    End {
        if ($AllComputers.Count -eq 0) {
            Write-Warning "No valid computer names were provided."
            Return
        }

        Write-Verbose "Deploying tag '$TagName' to $($AllComputers.Count) servers..."

        # Pass both TagName and TagValue to the remote block using the $using: scope
        Invoke-Command -ComputerName $AllComputers -ScriptBlock {
            $Path = "HKLM:\SOFTWARE\WOW6432Node\Tanium\Tanium Client\Sensor Data\Tags"
            
            try {
                if (-not (Test-Path $Path)) {
                    $null = New-Item -Path $Path -ItemType Directory -Force
                }
                
                $null = New-ItemProperty -Path $Path -Name $using:TagName -Value $using:TagValue -PropertyType "String" -Force
                
                # Returns custom object so you know which server succeeded
                [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    Status       = "Success"
                    Detail       = "Tag applied"
                }
            }
            catch {
                [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    Status       = "Error"
                    Detail       = $_.Exception.Message
                }
            }
        }
    }
}



