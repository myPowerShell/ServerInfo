<#

.Synopsis
    This is a function to Download Monthly OSUpdates from Microsoft for Windows Servers

.DESCRIPTION
    This is a function to Download Monthly OSUpdates to a target folder with MMyyyy format

.NOTE

  File Name : Import-OSUpdate.ps1
  Author    : Srini Vemulapalli
  Requires  : PowerShell 5

.EXAMPLE

    PS> Import-OSUpdate -Path "F:\OSUpdates"

    
.EXAMPLE

    PS> Import-OSUpdate -Path "F:\OSUpdates" -Verbose


#>

Function Import-OSUpdate {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True,
            ValueFromPipeline = $False,
            ValueFromPipelineByPropertyName = $False)]
        [String[]]$Path
    )


    $ImportPath = $Path
    Write-Log "Script execution in Progress... Please wait!"

    #Pre-Checks
    $Url = "https://download.microsoft.com"
    try {
        $Response = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -ErrorAction Stop
        if ($Response.StatusCode -eq 200) {
            Write-Log "Success: Access to $Url is validated. Status: 200 OK"
            Write-Verbose "Success: Access to $Url is validated. Status: 200 OK"
   
            #Post (Pre-Checks)
            Write-Log "Import-OSUpdate function execution in Progress...at $Env:ComputerName"  

            # Required Module for this Function
            If (-not(Get-InstalledModule -Name MSCatalogLTS -ErrorAction silentlycontinue)) {
                Write-Log "Installing MSCatalogLTS PowerShell Module"
                Install-Module -Name MSCatalogLTS -Scope CurrentUser -Confirm:$False -Force
                Import-Module -Name MSCatalogLTS
            }
            else {
                Write-Log "MSCatalogLTS PowerShell Module Already Installed"
            }

            
            # Monthly OSUpdates folder this month
            $subfolderName = (Get-Date -Format MMyyyy).ToString()

            # Windows Server 2016
            $win2k16 = Join-Path $ImportPath ("Win2k16\" + $subfolderName)
            if (-not (Test-Path  $win2k16)) { New-Item -ItemType Directory -Path  $win2k16 | Out-Null }
            $Updates = Get-MSCatalogUpdate -Search "Windows Server 2016"  -Lastdays 25 
            @(foreach ($Update in $Updates) {
                    Write-Log "Donwloading 2016 OSUpdates: $Update"
                    Save-MSCatalogUpdate -Update $Update -Destination $win2k16
                })

            # Windows Server 2019
            $win2k19 = Join-Path $ImportPath ("Win2k19\" + $subfolderName)
            if (-not (Test-Path  $win2k19)) { New-Item -ItemType Directory -Path  $win2k19 | Out-Null }
            $Updates = Get-MSCatalogUpdate -Search "Windows Server 2019"   -Lastdays 25 
            @(foreach ($Update in $Updates) {
                    Write-Log "Donwloading 2019 OSUpdates: $Update"
                    Save-MSCatalogUpdate -Update $Update -Destination $win2k19
                })

            # Windows Server 2022
            $win2k22 = Join-Path $ImportPath ("Win2k22\" + $subfolderName)
            if (-not (Test-Path  $win2k22)) { New-Item -ItemType Directory -Path  $win2k22 | Out-Null }
            $Updates = Get-MSCatalogUpdate -Search "Windows Server 2022"  -Lastdays 25 
            @(foreach ($Update in $Updates) {
                    Write-Log "Donwloading 2022 OSUpdates: $Update"
                    Save-MSCatalogUpdate -Update $Update -Destination $win2k22
                })

            # Windows Server 2025
            $win2k25 = Join-Path $ImportPath ("Win2k25\" + $subfolderName)
            if (-not (Test-Path  $win2k25)) { New-Item -ItemType Directory -Path  $win2k25 | Out-Null }
            $Updates = Get-MSCatalogUpdate -Search "Windows Server 2025"  -Lastdays 25
            @(foreach ($Update in $Updates) {
                    Write-Log "Donwloading 2025 OSUpdates: $Update"
                    Save-MSCatalogUpdate -Update $Update -Destination $win2k25
                })
        
        }
 
    }
    catch {
        Write-Log "Failed to connect to $Url. Error: $_"
        Write-Verbose "Failed to connect to $Url. Error: $_"
    }

    Write-Log "Completed Download of all Updates"

}



