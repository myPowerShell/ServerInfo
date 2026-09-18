
<#

.Synopsis
    This is a function to generate System Privileged Admin Report on Select Server(s)

.DESCRIPTION
    This is a function to generate System Privileged Admin Report for select list of servers

.NOTE

  File Name : Get-SystemPrivilegedAdmin.ps1
  Author    : Srini Vemulapalli
  Requires  : PowerShell 5

.EXAMPLE

    PS> Get-SystemPrivilegedAdmin -ComputerName mylocalhost

.EXAMPLE

    PS> Get-SystemPrivilegedAdmin -ComputerName mylocalhost -Verbose
    

.EXAMPLE

    PS>  Get-SystemPrivilegedAdmin -ComputerName (get-content servers.txt)  |ft -AutoSize 


 .EXAMPLE

    PS>  Get-SystemPrivilegedAdmin -ComputerName mylocalhost -Verbose | ft -AutoSize

.LINK


#>



function Get-SystemPrivilegedAdmin {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]
        [Alias('CN', 'Computer', 'IPAddress')]
        [string[]] $ComputerName

    )


    BEGIN {
        Write-Verbose "Script execution in Progress...for  Please wait!"


    }

    PROCESS {
        $Max = $ComputerName.Count
        $Count = 1
        Write-Verbose "Script execution in Progress... Please wait!"
        
        $RequiredModules = @('ServerInfo', 'ActiveDirectory')
        foreach ($module in $RequiredModules) {
            if (-not (Get-Module -Name $module -ListAvailable)) {
                throw "Validation Failed: The module $module is not installed on this system."
            }
            else {
    
                Write-Host " Succesfully validated $Module PS Module is Present"
            }

        }
        
        foreach ($computer in $ComputerName) {

            try {
                Write-Verbose "-------------------------------"
                Write-Verbose "Executing Get-SystemPrivilegedAdmin List On $Computer ...$Count of $max"
                $Computer = $Computer.trim()

                New-CimSession -ComputerName $Computer  -ErrorAction Stop -Verbose:$false | out-null
                Write-Log "Executing Get-SystemPrivilegedAdmin function On $Computer ...$Count of $max" -Severity INFO

                #Get Local Admin group from current server
                $admGroup = [ADSI]("WinNT://$Computer/Administrators,group")
                #Extract the members of the group
                $GroupMembers = $admGroup.psbase.invoke("Members") 
           
                #Loop through the members
                foreach ($GroupMember in $GroupMembers) {
		
                    $MemberName = $GroupMember.GetType().InvokeMember("Name", 'GetProperty', $null, $GroupMember, $null)
                    $Path = $GroupMember.GetType().InvokeMember("ADsPath", 'GetProperty', $Null, $GroupMember, $Null)
                    
                    #EXCLUSION FILTER: Skip IIS Application Pools and the IIS_IUSRS group
                    if ($Path -like "*IIS APPPOOL*" -or $MemberName -eq "IIS_IUSRS") {
                    Write-Verbose "Skipping IIS identity: $MemberName"
                    continue # Skip to the next member in the loop
                    }
                    
                    $isGroup = ($GroupMember.GetType().InvokeMember("Class", 'GetProperty', $Null, $GroupMember, $Null) -eq "group")
                    $TimeStamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        
                    #Setting AccountType 
                    If (($Path -like "*/$Computer/*") -and ($isGroup -eq $false)) {
                        $AccountType = 'LocalAccount'
                    }
                    elseif (($Path -like "*/$Computer/*") -and ($isGroup -eq $true)) {
                        $AccountType = 'LocalGroup'
                    }
                    elseif (-not(($Path -like "*/$Computer/*")) -and ($isGroup -eq $false)) {
                        $AccountType = 'DomainAccount'
                    }
                    else { $AccountType = 'DomainGroup' }

                    if (($isGroup -eq $true) -and ($AccountType -eq "DomainGroup")) {
                        $oGroup = $MemberName
                        $gMembers = Get-ADGroupMember -Identity $oGroup # -Recursive

                        foreach ($gMember in $gMembers) {
                            if ($gMember.objectClass -eq "user") {
                                $isGroup = $false
                            }
                            else {
                                $isGroup = $true
                            }

                            $Properties = [Ordered] @{ ComputerName = $Computer
                                Status                              = "Connected"
                                UserID                              = $gMember.SamAccountName
                                MemberOfDomainGroup                 = $oGroup
                                AccountType                         = $gMember.objectClass
                                IsGroup                             = $isGroup
                                TimeStamp                           = $TimeStamp
                            }
                       
                            $Objoutput = New-Object -TypeName PSObject -Property $Properties
                            Write-output $Objoutput

             
                        }
                    }
                    else {
                        
                        $TimeStamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
                        $Properties = [Ordered] @{ ComputerName = $Computer
                            Status                              = "Connected"
                            UserID                              = $MemberName
                            MemberOfDomainGroup                 = "NA"
                            AccountType                         = $AccountType
                            IsGroup                             = $isGroup
                            TimeStamp                           = $TimeStamp
                        }
                        $Objoutput = New-Object -TypeName PSObject -Property $Properties
                        Write-output $Objoutput

       
                    }
    
  
                }

            
            }
            catch {
                    
                Write-Verbose "Couldn't Connect to $Computer"
                $Message = $($_.Exception.Message)
                Write-Log "Exception Message: $Message on Server $Computer" -Severity ERROR
                    
                $Properties = [Ordered] @{ ComputerName = $Computer
                    Status                              = "NotConnected"
                    UserID                              = $null
                    MemberOfDomainGroup                 = $null
                    AccountType                         = $null
                    IsGroup                             = $null
                    TimeStamp                           = $TimeStamp
                }
                $Objoutput = New-Object -TypeName PSObject -Property $Properties
                Write-output $Objoutput

                    
            } 
            finally {
                    
                Write-Log "Completed Processing Get-SystemPrivilegedAdmin On $Computer ...$Count of $max" -Severity INFO             
            } #End finally

            # Incrimenting count for interactive console text
            $count = $count + 1 
      
        }# End foreach 


            

    } #End PROCESS    
  
    END {
        Write-Verbose "Succesfully Completed Processing Systems on this list"
        Write-Log "Succesfully Completed Processing Systems on this list" -Severity INFO
    }


} #End FUNCTION