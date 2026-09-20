Function Get-FolderSize {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]
        [Alias('HostName', 'cn', 'IPAddress')]
        [string[]] $ComputerName,

        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )

    Write-Host "Script execution in Progress... Please wait" -ForegroundColor Yellow
    Write-Log "Script execution in Progress... Please wait" -Severity INFO

        $RemoteFolder = $Path

        if ($ComputerName -as [ipaddress]){
        Write-Log "Detected IP Address and converting to HostName" -Severity INFO
        $ComputerName = (Resolve-DnsName -Name $ComputerName|select-object NameHost).NameHost
        }

        if ($ComputerName -eq $Env:ComputerName){
        
          Write-Log "IsRemote ComputerName: No"
          Write-Host ("Work thread completed on [ComputerName: $ComputerName]"+" "+"$(Get-Date)") -ForegroundColor Cyan
            $RootPath = $Path

            $localresults = Get-ChildItem -Path $RootPath -Directory | ForEach-Object {
            $UserFolder = $_.FullName
            $FolderSize = (Get-ChildItem -Path $UserFolder -File -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    
                     [PSCustomObject]@{
                     "Folder_Name" = $_.Name
                     "Size_GB"    = if ($FolderSize) { [Math]::Round($FolderSize / 1GB, 2) } else { 0 }
                    }
               } 
        
         $allresults = $localresults
         }else{

                Write-Log "IsRemote ComputerName: Yes"
                $SessionArgs = @{ ComputerName = $ComputerName }
                if ($PSBoundParameters.ContainsKey('Credential')) {
                $SessionArgs.Add('Credential', $Credential)
                }
                Try{
                $session = New-PSSession @SessionArgs -ErrorAction Stop
                }catch{
                Write-Log "Encounterd errors while Connecting to $ComputerName" -Severity ERROR
                Write-Host "Encounterd errors while Connecting to $ComputerName" -ForegroundColor Red
                Continue
                }
                Write-Log "Established Remote Session with ID: $session"
                Write-Host ("Waiting on work thread to complete on [ComputerName: $ComputerName]"+" "+"$(Get-Date)") -ForegroundColor Cyan

     $remoteresults =  Invoke-Command -Session $session -Command { param($Folder)
            Get-ChildItem -Path $Folder -Directory | ForEach-Object {
                    $UserFolder = $_.FullName
                    $FolderSize = (Get-ChildItem -Path $UserFolder -File -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    
                    $Properties = [Ordered] @{
                    "Folder_Name" = $_.Name
                    "Size_GB"    = if ($FolderSize) { [Math]::Round($FolderSize / 1GB, 2) } else { 0 }
                    }

                    $Objoutput = New-Object -TypeName PSObject -Property $Properties
                    Write-output $Objoutput

                }  


        } -ArgumentList $RemoteFolder 
        
        $allresults = $remoteresults
   }


    Write-Host ("Work thread completed on [ComputerName: $ComputerName]"+" "+"$(Get-Date)") -ForegroundColor Cyan
    Write-Log "[ComputerName: $ComputerName]" -Severity INFO
 
    Write-Log "File System Path: $RemoteFolder" -Severity INFO
    
    if($null -eq $allresults){
    Write-Log "Output: No Folders Found at this Path: $RemoteFolder" -Severity ERROR
    Write-Host "No Folders Found at this Path: $RemoteFolder" -ForegroundColor Red
    }else{
    Write-Log "Sorting results and presenting top 10 folders by Size" -Severity INFO
    $oresult = $allresults | Sort-Object Size_GB -Descending | select-object Folder_Name, Size_GB -First 10 |format-table  | Out-String
    Write-Log "Output: $oresult" -Severity INFO
    Write-Host "Sorting results and presenting top 10 folders by Size" -ForegroundColor Gray
    Write-output $oresult
    }

    Write-Host "Script Execution Completed... Done!"  -ForegroundColor Green
    Write-Log "Script Execution Completed... Done!" -Severity INFO

}



