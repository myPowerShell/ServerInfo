function Set-TaniumTag {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String[]]$ComputerName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Patch_NoPatch', 'SRV_MW01',
        'SRV_MW07', 'SRV_MW18', 'SRV_MW06',
        'WINSRV_PATCH_STANDARD','WINSRV_PATCH_SQL')]
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

        # Define descriptions for the native -WhatIf / -Confirm framework
        $TargetDescription = "$($AllComputers.Count) servers (Ticket: $ChangeNumber)"
        $ActionDescription = "Create/Overwrite Tanium registry tag '$TagName' with value '$TagValue'"

        if ($PSCmdlet.ShouldProcess($TargetDescription, $ActionDescription)) {
            Write-Verbose "Deploying tag '$TagName' to $TargetDescription..."

            # Explicitly pass TagName and TagValue via ArgumentList for reliable remote execution
            Invoke-Command -ComputerName $AllComputers -ArgumentList $TagName, $TagValue -ScriptBlock {
                param($RemoteTagName, $RemoteTagValue)

                $Path = "HKLM:\SOFTWARE\WOW6432Node\Tanium\Tanium Client\Sensor Data\Tags"
                
                try {
                    if (-not (Test-Path $Path)) {
                        $null = New-Item -Path $Path -ItemType Directory -Force
                    }
                    
                    $null = New-ItemProperty -Path $Path -Name $RemoteTagName -Value $RemoteTagValue -PropertyType "String" -Force
                    
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
}

