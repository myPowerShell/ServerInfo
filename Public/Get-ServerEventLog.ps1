function Get-ServerEventLog {

<#

.SYNOPSIS
 Get Server EventLog Details for list of servers in a text file

.DESCRIPTION
 Get Server EventLog Details for list of servers in a text file


 .NOTE
  File Name : Get-ServerEventLog.ps1
  Author    : Srini Vemulapalli
  Requires  : PowerShell 5
  
  .EXAMPLE
   Get-ServerEventLog -ComputerName "YourServerName" -LogName System -EntryType Error -LastRows 20 -Hours 72 | ft -Wrap
  
  #>







    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [String[]]$ComputerName = $Env:ComputerName,

        [Parameter(Mandatory = $false)]
        [ValidateSet('System', 'Application', 'Security', 'Setup')]
        [String]$LogName = "System",

        [Parameter(Mandatory = $false)]
        [Int[]]$EventId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Error', 'Warning', 'Information', 'SuccessAudit', 'FailureAudit')]
        [String[]]$EntryType = "Error",

        [Parameter(Mandatory = $false)]
        [String]$Keywords,

        [Parameter(Mandatory = $false)]
        [Int]$LastRows = 5,

        [Parameter(Mandatory = $false)]
        [Switch]$RecentEventsOnly,

        [Parameter(Mandatory = $false)]
        [Int]$Hours = 48
    )

    Process {
        foreach ($Computer in $ComputerName) {
            Write-Verbose "Initiating CIM connection to server: $Computer"

            # 1. Map EntryTypes to structural WMI Event Types
            $TypeQueries = @()
            if ($EntryType) {
                if ($LogName -eq 'Security') {
                    if ($EntryType -contains 'FailureAudit') { $TypeQueries += "EventType = 5" }
                    if ($EntryType -contains 'SuccessAudit') { $TypeQueries += "EventType = 4" }
                } else {
                    if ($EntryType -contains 'Error') { $TypeQueries += "EventType = 1" }
                    if ($EntryType -contains 'Warning') { $TypeQueries += "EventType = 2" }
                    if ($EntryType -contains 'Information') { $TypeQueries += "EventType = 3" }
                }
            }

            # 2. Build the structural WQL query string piece by piece
            $WQL = "SELECT * FROM Win32_NTLogEvent WHERE Logfile = '$LogName'"

            if ($EventId) {
                $IdQuery = ($EventId | ForEach-Object { "EventCode = $_" }) -join " OR "
                $WQL += " AND ($IdQuery)"
            }

            if ($TypeQueries) {
                $WQL += " AND (" + ($TypeQueries -join " OR ") + ")"
            }

            if ($RecentEventsOnly) {
                # Convert the time limit target to a Management-safe UTC timestamp format
                $TargetTime = (Get-Date).AddHours(-$Hours)
                $CimTime = [Microsoft.Management.Infrastructure.CimStructure]::CreateDate($TargetTime)
                $WQL += " AND TimeGenerated >= '$CimTime'"
            }

            # 3. Execute the CIM Data Pull
            $Session = $null
            try {
                # FIX: Configured the correct parameter (-SessionOption) for New-CimSession
                $CimOptions = New-CimSessionOption -Protocol WsMan
                $Session = New-CimSession -ComputerName $Computer -SessionOption $CimOptions -ErrorAction Stop

                $Events = Get-CimInstance -CimSession $Session -Query $WQL -ErrorAction Stop

                # Apply text-based Keyword filtering client-side if specified
                if ($Keywords) {
                    $Events = $Events | Where-Object { $_.Message -match [Regex]::Escape($Keywords) }
                }

                # Output and format the resulting structures, mapping properties to your exact template
                if ($Events) {
                    $Events | Select-Object -First $LastRows | Select-Object @{Name='TimeCreated'; Expression={$_.TimeGenerated}},
                                                                             @{Name='MachineName'; Expression={$_.ComputerName}},
                                                                             @{Name='Id'; Expression={$_.EventCode}},
                                                                             @{Name='LevelDisplayName'; Expression={$_.Type}},
                                                                             @{Name='Message'; Expression={$_.Message}}
                                                                             
                }
            }
            catch {
                Write-Error "Cim Query Engine dropped pipeline processing on target $Computer. Reason: $_"
            }
            finally {
                if ($Session) { Remove-CimSession $Session }
            }
        }
    }
}








