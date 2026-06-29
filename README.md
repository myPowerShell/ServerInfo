# The ServerInfo PowerShell Module should help manage server infrastructure by consolidating essential and frequently leveraged commands into functions/comdlets <br/>

-This Repo equips you with the skills to create a tailored module that accommodates all your elements and distinctive requirements. <br/>
-The focus of this module is to help develop the knowledge and tools to build and expand a module that fully integrates and adapts with changing needs <br/>

# List of Functions in this Module: <br/>

Get-OSInfo  <br/>
Get-Uptime <br/>
Get-DiskSpace   <br/>
Get-Patchsummary  <br/>
Get-Reboothistory <br/>
Get-NICInfo    <br/>
Restart-MyComputer  <br/>

# General Example usage for most of the functions in this Module: <br/>

1) Get-OSInfo <br/>
2) Get-Content servers.txt | Get-OSInfo <br/>
3) Get-Content servers.txt | Get-OSInfo | Export-Csv C:\Temp\Get-OSInfo_0626.csv <br/>

1) Get-Uptime <br/>
2) Get-Content servers.txt | Get-Uptime <br/>
3) Get-Content servers.txt | Get-Uptime | Export-Csv C:\Temp\Get-Content_0626.csv <br/>



