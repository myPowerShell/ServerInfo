
Function Get-OktaUser {

<#
.Synopsis
    This is a function to get all Okta Users in your Okta Domain

.DESCRIPTION
    This commandlet generates Okta Users in your domain and it filters out all Deprovisioned Users

.NOTE

  File Name : Get-OktaUser.ps1
  Author    : Srini Vemulapalli
  Requires  : PowerShell 5



.EXAMPLE

    PS>  $secureKey  = Read-Host "Enter API Key" -AsSecureString
         Get-OktaUser -APIKey $secureKey -Endpoint "https://yourdomain.okta.com/api/v1/users" 

.LINK


#>

    [CmdletBinding()]
    param (
      
        [Parameter(Mandatory = $true, HelpMessage="Enter your APIKey")]
        [ValidateNotNullOrEmpty()]
        [SecureString]$APIKey,  
        
        [Parameter(Mandatory = $true,
        HelpMessage="https://yourdomain.okta.com/api/v1/users")]
        [string]$Endpoint
      )

$ADUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
WriteLog "Executing Get-OktaUsers Commandlet  On $Env:ComputerName for $ADUser" -Severity INFO

# Use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$url = $Endpoint
# Converting API key to plain text for HTTP Header
$DecryptedKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($APIKey))
$MyKey = $DecryptedKey # Replace with your actual API key

$headers = @{
    "Accept" = "application/json"
    "Content-Type" = "application/json"
    "Authorization" = "SSWS $MyKey"
}

$allUsers = @()
$activeUsers = @()

# 2. Make the GET request to the API
try { WriteLog "Making a Get Request to API" -Severity INFO
    do {
      $result = Invoke-WebRequest -Headers $headers -Method Get -Uri $url
      $users = $result | ConvertFrom-Json
      $AllUsers += $users
      # Handle pagination links
      $next = (($result.headers.link -split ',')[1] -replace "[<>]"-split ";")[0]
      $url = $next

    } while ($result.Headers.Link -match "next")

   # Filter Results
   WriteLog "Filtering Results" -Severity INFO
   $activeUsers = $Allusers | Where-Object { $_.status -ne “DEPROVISIONED” }
   
    # 3. Process the results
    WriteLog "Total All users retrieved: $($allusers.Count)" -Severity INFO
    WriteLog "Total Active users retrieved: $($activeUsers.Count)" -Severity INFO
    @(foreach ($user in $activeUsers){  
    $login = $user.profile 
    $Properties = [Ordered] @{ id = $user.id
                                   smuser = $login.smuser
                                   status = $user.status
                                   login = $login.login
                                   }

           $Objoutput = New-Object -TypeName PSObject -Property $Properties
           Write-output $Objoutput
        
       }) 
    
} catch {
    if (-not [string]::IsNullOrEmpty($MyKey)) {
    WriteLog "Exception Message: Errors Encountered While Processing" -Severity ERROR
    }else{
    $Message = $($_.Exception.Message)
    WriteLog "Exception Message: $Message " -Severity ERROR
    }
}

WriteLog "Script Execution Completed  On $Env:ComputerName by $ADUser" -Severity INFO

}









