Function Get-NICInfo {

<#

.SYNOPSIS
 Get NIC details from Server or list of Servers


.DESCRIPTION
 This script check on a server or list of servers to provide Network Configuration details

.NOTE
  File Name : Get-NICInfo.ps1
  Author    : myPowerShell
  Requires  : PowerShell 5
  
  
.EXAMPLE
   Get-NICInfo

.EXAMPLE
   Get-Content ("Servers.txt") | Get-NICInfo | ft -AutoSize


#>


   [CmdletBinding()]
   param(
      [Parameter(
         Mandatory = $false,
         ValueFromPipeline = $true,
         ValueFromPipelineByPropertyName = $true

      )]
          
      [string[]] $ComputerName = $Env:ComputerName


   )

   BEGIN {}

   PROCESS {
      $ErrorActionPreference = "SilentlyContinue"
      foreach ($Computer in $ComputerName) {
               
         try {
            $Computer = $Computer.trim()
            if (New-CimSession -ComputerName $Computer  -ErrorAction SilentlyContinue) {
               $NICs = Get-NetAdapter -IncludeHidden -CimSession $Computer | Where-Object { $_.Status -eq "Up" -and $_.LinkSpeed -ne "0 bps" -and -not($_.Name.Contains("Loopback")) }
               ForEach ($NIC in $NICs) {
                  $Out = Get-NetIPConfiguration -InterfaceIndex $NIC.ifIndex -CimSession $Computer
                  $DefaultGateway = $Out.IPv4DefaultGateway
                  $Mask = ((ipconfig | findstr [0-9].\.)[1]).Split()[-1]
                  $DNS = $Out.DNSServer
                  $DNS = $Out.DNSServer | Where-Object { $_.ServerAddresses -ne "" }

                  if (!($DNS)) {
                     $DNS1 = $null
                     $DNS2 = $null

                  }
                  else {
                     $DNS1 = $DNS.ServerAddresses[0]
                     $DNS2 = $DNS.ServerAddresses[1]
                  }

                  $Properties = [Ordered] @{ ComputerName = $Computer
                     Status                               = "Connected"
                     InterfaceName                        = $NIC.Name
                     Description                          = $NIC.InterfaceDescription
                     IPAddress                            = $Out.IPv4Address[0]
                     Mask                                 = $Mask
                     GatewayAddress                       = $DefaultGateway.NextHop
                     LinkSpeed                            = $NIC.LinkSpeed
                     DNS1                                 = $DNS1
                     DNS2                                 = $DNS2
                     MAC                                  = $NIC.MacAddress
                  }

                  $Objoutput = New-Object -TypeName PSObject -Property $Properties
                  Write-output $Objoutput

               }
            }
            else {
            
               $Properties = [Ordered] @{ ComputerName = $Computer
                  Status                               = "Unable_to_Connect"
                  InterfaceName                        = $null
                  Description                          = $null
                  IPAddress                            = $null
                  Mask                                 = $null
                  GatewayAddress                       = $null
                  LinkSpeed                            = $null
                  DNS1                                 = $null
                  DNS2                                 = $null
                  MAC                                  = $null
               }

               $Objoutput = New-Object -TypeName PSObject -Property $Properties
               Write-output $Objoutput
            
            }

         }
         catch {
            Write-Error $_.Exception.Message

         }
      }
   }

   END {}

}



