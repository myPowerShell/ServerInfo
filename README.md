The ServerInfo PowerShell Module empowers Platform and Systems Engineering teams by consolidating essential daily commands into a single, high-impact function or functions. By embracing this re-usable framework, Engineers can significantly boost productivity, ensure predictable and repeatable results, and maintain a perfectly consistent configuration across digital Infrastructure <br/>

- Maintain consistent function formats to enhance maintainability, simplicity <br/>
- Validated for use in Microsoft Windows Server 2016 and 2022 environments.  <br/>


### General Example usage of the functions in this Module: <br/>

1) Get-OSInfo <br/>
2) Get-Content servers.txt | Get-OSInfo <br/>
3) Get-Content servers.txt | Get-OSInfo | Export-Csv C:\Temp\Get-OSInfo_0626.csv <br/>

1) Get-Uptime <br/>
2) Get-Content servers.txt | Get-Uptime <br/>
3) Get-Content servers.txt | Get-Uptime | Export-Csv C:\Temp\Get-Content_0626.csv <br/>


### Private Functions:
- Some private functions are excluded from this module


#### Install ServerInfo Module from PowerShell Gallery:
```ps
Install-Module -Name ServerInfo -Scope CurrentUser

```
### Verify Installation and Import-Module before using Functions:
```ps
Get-Module -Name ServerInfo -ListAvailable

Import-Module -Name ServerInfo

```
### Get-OSInfo of localhost or a server by Name:
```ps
Get-OSInfo -ComputerName localhost | format-Table -AutoSize

```
### Get-InstalledSoftware from select list of servers:
```ps
Get-InstalledSoftware -ComputerName (Get-Content ".\Servers.txt") | ? {$_.DisplayName -match "Rubrik"}  | ft -AutoSize -Wrap

```
### Clear IIS Logs, Please check log at C:\Temp\Logs to monitor Job progress:
```ps
Clear-IISLog -ComputerName (Get-Content "Servers.txt")  -IISLogPath E:\Logs  -LogRetentionDays 90

```
### Display the `Logon Logoff` report for select list of servers:
```ps
Get-SystemLogonLogoffReport -ComputerName (get-content "servers.txt") -DaysFromToday 2 | format-Table -AutoSize

```
### Display Post OSUpdate, Pending Reboot Condition for select list of Servers:
```ps

Test-PendingReboot -Computername (Get-Content "Servers.txt") | format-Table -AutoSize

```
### Get Process by Memory Usage:
```ps
Get-ProcessByMemory -ComputerName (Get-Content "Servers.txt") | format-Table -AutoSize

```

### Get Folder Size:
```ps
Get-FolderSize -ComputerName localhost -Path "C:\Users" | format-Table -AutoSize

```

### Get Live Server Metrics:
```ps
Get-ServerMetrics -ComputerName (Get-Content "Servers.txt") |  format-Table -AutoSize

```
### Generate SSL Certificate report from select list of servers:
```ps
Get-SSLCertReport -ComputerName (get-content win_allservers.txt)  | Select-Object ComputerName, Status, NotAfter, Subject, Issuer, DaysRemaining, TimeStamp | Export-Csv ("Get-SSLCertReport_$(Get-Date -Format "yyyyMMdd_HHmmss").csv") -NoTypeInformation

```
### Get Okta User by Email:
```ps
Show-OktaUserbyEmail -EmailAddress firstName.lastname@company.com

```
### Get Nutanix VM list from PrismCentral UI:
```ps

# if output needs to be filtered down to contain select list of Servers
$ServerList = (Get-Content ".\servers.txt")

# nxUser name
$nxUser = Read-Host -Prompt "Please enter nxUser"

# Password for nxUser
$secureKey = Read-Host -Prompt "Please enter your Secret" -AsSecureString

$Params = @{
    nxUser       = $nxUser
    nxPassword   = $secureKey
    ComputerName = $ServerList
   }

# Dynamically add the target list to Params
$Params["PrismCentral"] = @("prism01.domain.local", "prism02.domain.local")

Get-NutanixVM @Params

```
