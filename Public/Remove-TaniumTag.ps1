function Remove-TaniumTag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string[]]$ComputerName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Patch_NoPatch', 'SRV_MW01',
        'SRV_MW07', 'SRV_MW18', 'SRV_MW06',
        'WINSRV_PATCH_STANDARD','WINSRV_PATCH_SQL')]
        [string]$TagName,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^CHG\d{7}$')]
        [String]$ChangeNumber
    )

    Begin {
        # Initialize an array to collect pipeline inputs
        $AllComputers = [System.Collections.Generic.List[string]]::new()
    }

    Process {
        # Collect and trim names from parameter or pipeline
        foreach ($Computer in $ComputerName) {
            if (-not [string]::IsNullOrWhiteSpace($Computer)) {
                $AllComputers.Add($Computer.Trim())
            }
        }
    }

    End {
        if ($AllComputers.Count -eq 0) {
            Write-Warning "No valid computer names were provided."
            return
        }

        Write-Verbose "Removing tag from $($AllComputers.Count) servers..."

        # Pass $TagName into the ArgumentList for the remote session
        Invoke-Command -ComputerName $AllComputers -ArgumentList $TagName -ScriptBlock {
            param($TagName)
            
            $Path = "HKLM:\SOFTWARE\WOW6432Node\Tanium\Tanium Client\Sensor Data\Tags"
            
            try {
                if (Test-Path $Path) {
                    # Check if the specific tag registry property exists before deleting
                    if ((Get-ItemProperty -Path $Path -Name $TagName -ErrorAction SilentlyContinue)) {
                        Remove-ItemProperty -Path $Path -Name $TagName -Force | Out-Null
                        Write-Output "[$env:COMPUTERNAME] [Success] Tag '$TagName' removed successfully."
                    }
                    else {
                        Write-Output "[$env:COMPUTERNAME] [Info] Tag '$TagName' did not exist on this server."
                    }
                }
                else {
                    Write-Output "[$env:COMPUTERNAME] [Info] Tanium tags path does not exist."
                }
            }
            catch {
                Write-Error "[$env:COMPUTERNAME] [Error] Failed to remove tag. Details: $_"
            }
        }
    }
}



