<# Gather Logs for Windows and SQL Server
 # Script Version 2.0.0
 # Script Create Date: 8 Oct 2018
 # Script Created By: Rob L. (RyderOfTheVeil)
 # Script Last Modified By: Rob L.
 # Script Last Mod Date: 10 Oct 2018
 # This script gathers logs required to find Root Cause for many types of issues.
 # It also doubles as a log collector for opening cases with Microsoft.
 # The Logs this script gathers are:
 #    Windows Cluster Logs (if Applicable)
 #    Windows Event Viewer Logs (Application,System,Security) (as one .txt file)
 #    Windows Memory Dump (if applicable)
 #    SQL Server Error Logs
 #    SQL Server Dump Files
 #    SQL Server Default Trace Files
 #    SQL Agent Logs
 #
 # CURRENT Version (V2.0.0) Notes:
 # 
 # Complete re-write from Version 1.
 # Now handles Multiple Instances and the main gathering works on PS Version 2.
 # Checks for PS V2. 
 # The only function not supported in PS V2 in this script is the compression. 
 # 
 # Future revision will have improved logic and possible V2 compression function. 
 #>

$ErrorActionPreference = "silentlycontinue"
$ServerName = $env:computername
$localInstances = (get-itemproperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances
Write-Output $localInstances
$VerVal = New-Object System.Collections.Generic.List[System.Object]
$InstanceDir = New-Object System.Collections.Generic.List[System.Object]
$InstFldr = New-Object System.Collections.Generic.List[System.Object]
$LocErrorLog = New-Object System.Collections.Generic.List[System.Object]
$LocAgentLog = New-Object System.Collections.Generic.List[System.Object]
$LocSQLDMP = New-Object System.Collections.Generic.List[System.Object]
$LocDefTrc = New-Object System.Collections.Generic.List[System.Object]

foreach ($i in $localInstances)
{
   $p = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').$i
   $version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$p\Setup").Version
   $SP = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$p\Setup").SP
   #write-output $p $version $SP #testing only
   $V = $version
   #write-output $Ver #tesing only
   
   $VerVal.Add($V) 
   write-output $VerVal
 }
 #$VerVal = "" #testing only
   Write-Output "Test $VerVal"
   Write-Output $VerVal.Count
 #$localInstances.Count #used for testing
  
  if ($localInstances.Count -gt 1) {
   Write-Output "Multiple Instances Found"
   $inst1 = $localInstances[0]
   #write-output $inst1 
   $inst2 = $localInstances[1]
   #write-output $inst2
   $inst3 = $localInstances[2]
   #write-output $inst3
   $inst4 = $localInstances[3]
   #write-output $inst4
        
   }
   Else {
   Write-Output "Singular Instance Found"
   $inst1 = $localInstances[0]
   $ConnectName = $ServerName
   #write-output "Hmmmm there's a problem.." #used for testing
   }
   Write-Output $VerVal
   Write-Output "Your Instance(s):" $inst1, $inst2, $inst3, $inst4


#Function to trim what we don't need from the version#
function Trim-Length {
param (
    [parameter(Mandatory=$True,ValueFromPipeline=$True)] [string] $Str
  , [parameter(Mandatory=$True,Position=1)] [int] $Length
)
    $Str[0..($Length-1)] -join ""
}

ForEach($z in $VerVal){
    #Get Version number
    $Vers = $z| Trim-Length 4
    Write-Output "$Vers"
    $SQL2016 = 
    $VerNum = $Vers
    switch -w ($VerNum){
        "13.?"{$InstP1 = "MSSQL13."
            Write-Output "SQL 2016"
            }
        "12.?"{$InstP1 = "MSSQL12."
            Write-Output "SQL 2014"
            }
        "11.?"{$InstP1 = "MSSQL11."
            Write-Output "SQL 2012"
            }
        "10.5"{$InstP1 = "MSSQL10_50."
            Write-Output "SQL 2008R2"
            }
        "10.0"{$InstP1 = "MSSQL10."
            Write-Output "SQL 2008"
            }
        }

    $InstFldr.Add($InstP1)
    Write-Output "Your Instance Version(s) is/are $InstFldr" #use me for testing
#End Get Version/InstName
    
}

#Get Concatenated Folder for use later
For ($x = 0; $x -lt $localInstances.Count; $x++){

$InstanceDir.Add($InstFldr[$x] + $localInstances[$x])
Write-Output $InstanceDir
}
#End Get Concat Folder


#Check to see if Clustered
#Function to check for clustered/not
function IsCluster { 
    param([string]$serverName) 
     
    if (($serverName -eq "") -or $serverName -eq $null) { 
        write-host "INPUT ERROR:  serverName value can not be blank" -foregroundcolor RED 
        return "Failed" 
    } else { 
      
            $sObj = Get-WmiObject -Class Win32_SystemServices -ComputerName $ServerName

            if ($sObj | select PartComponent | where {$_ -like "*ClusSvc*"})
                {
                return $true     
                }
            Else {return $false}
           }
} 
#Call Function to get answer, Is clustered? t/f
$ClusBOOL = (IsCluster $env:computername)
    #Write-Output "Clusters are fun. $ClusBOOL" #Use me for testing
    <# #For Testing Only
    #If ($ClusBOOL)
    #{ write-output "Yup"}
    #Else{ write-output "Houston we have a problem"}
    #>
#End Cluster Check

#Folder to Drop files in
$logDest = "\\Servername\h$\DBALogs"  #CHANGE FOR YOUR REPOSITORY LOCATION (Can use any type of repository you can connect to)
$myFile = $Env:COMPUTERNAME
$fso = new-object -ComObject scripting.filesystemobject
#will dump to respository. CHANGE FOR YOUR REPOSITORY LOCATION (3 spots to change in)
if (-not(Test-Path "\\Servername\h$\DBALogs\$myFile")){
$logDrec = $fso.CreateFolder("\\Servername\h$\DBALogs\$myFile")
$logDir = $logDrec.Path
}
ELSE{ $logDrec = "\\Servername\h$\DBALogs\$myFile"
#write-output $logDrec #use me to test
$logDir = $logDrec
}

#write-output $logDir #use me to test

#Begin Event Viewer Log Gather

$Path = "$logDir\EventViewLogs.txt"
Write-Output $Path
[String[]]$LogName = ("Application", "System", "Security")
Write-Output "Grabbing $LogName" #use me to test Function
    try
    {
    $TempPath=Split-Path $Path
			if (-not (Test-Path $TempPath))
			{
                #create Directory if not exist				
                New-Item -ItemType directory -Path $TempPath -ErrorAction Stop  |Out-Null
                
                #Set folder Permisisons
                $acl = Get-Acl "$logDir"
                $args = "everyone","FullControl","ContainerInherit,ObjectInherit","None","Allow"
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $args
                $acl.SetAccessRule($accessRule)
                $acl | Set-Acl "$logDir"
			}
		}
		catch
		{
			Write-Error -Message "Could not create path '$Path'. Please make sure you have enough permission and the format is correct."
			return
		}
    #export a certain eventlog with specified log name and event ID for last 24 hours. 
        Get-WinEvent -LogName $LogName -MaxEvents 1000 -EA SilentlyContinue | Where-Object {$_.Timecreated -gt (Get-date).AddHours(-24)} | Sort TimeCreated -Descending | Out-File $Path    #Export-Csv $Path -NoTypeInformation #Use me for csv format
	Write-Output "Logs to pull, $LogName sending to $Path" #Use me to test

#End Event Viewer Log Gather

#Begin Gather of SQL Logs and Cluster Log

########## Need to loop through $InstanceDir and create Location Arrays #########################################

#Grab the Error Log Location(s)

ForEach ($d in $InstanceDir){

$LocErrLg = & { (Get-ItemProperty `
      -LiteralPath "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$d\MSSQLServer\Parameters" `
      -Name $args `
    ).$args } 'SQLArg1'
  #Write-Output $d  #use for testing

#Trim the path to our needs
  $LocErrLg = $LocErrLg.trimstart("-").trimstart("e")
    #Write-Output "The log location is $LocErrLg" #Use me to test

#Stage the Agent Log Location
$LocAgnt = $LocErrLg
$LocAgnt = $LocAgnt -replace "ERRORLOG", "SQLAGENT"
    #Write-Output "The log location is $LocAgentLog" #Use me to test

#Stage the SQL Dump Log Location
$LocDMP = $LocErrLg
$LocDMP = $LocDMP -replace "ERRORLOG", "SQLDump"
$DMPExist = Test-Path -Path $LocDMP* 
    #write-output $DMPExist.ToString() #Use to test
    #Write-Output "The log location is $LocSQLDMP" #Use me to test

#Stage the SQL Default Trace File Location
$LocTrc = $LocErrLg
$LocTrc = $LocTrc -replace "ERRORLOG", "Log_"
    #Write-Output "The log location is $LocDefTrc" #Use me to test
    #Set-Location -Path $LocErrorLog #Handy for certain test cases

$LocErrorLog.Add($LocErrLg)
$LocAgentLog.Add($LocAgnt)
$LocSQLDMP.Add($LocDMP)
$LocDefTrc.Add($LocTrc)

}
################################ Stage the Server level logs #################################
#Stage Cluster Log Location
$LocClusLog = "C:\Windows\Cluster\Reports\Cluster.log"
    #Write-Output "Cluster Log Location is $LocClusLog" #Use me to test

#Stage Mem Dump Location
$LocMemDMP = "C:\Windows\MEMORY.DMP"
    Write-Output "Memory Dump Location is $LocMemDMP" #Use me to test


################################ Setup Directory for Copy ####################################
#Setup Directory to put all files in

$CopyDir = Test-Path -Path $logDir
    #Write-Output $CopyDir #Use me to test
#If the directory exists Copy the logs to it       
If ($CopyDir)
  {
    #ErrorLogs Copy

    <#ForEach($e in $LocErrorLog){
    $LogPath = Copy-Item -Path $e* -Destination $logDir -PassThru
        Write-Output "The log location is $LogPath"
        #>

    For ($g = 0;$g -lt $LocErrorLog.Count; $g++ ){
        $ePath = $LocErrorLog[$g]
        $aPath = $LocAgentLog[$g] 
        $dPath = $LocSQLDMP[$g] 
        $tPath = $LocDefTrc[$g]
        Write-Output $ePath 
        Write-Output $aPath
        Write-Output $dPath
        Write-Output $tPath
          
        $LogPath = ""
        $SDir = "$LogDir\Instance$g"
        #Write-Output $SDir

        $FDir = Test-Path -Path $SDir
            If ($FDir){
            Write-Output "Exists"
            $Dest = $SDir
            Write-output $Dest
            }
        
            Else{
            $Folder = $fso.CreateFolder("$LogDir\Instance$g")
            Write-output $Folder.Path
            #$Dest = ""
            $Dest = $SDir
            Write-Output $Dest
            }
      
    
        $LogPath = Copy-Item -Path $ePath* -Destination "$Dest" -PassThru
            Write-Output "The log location is $LogPath"
        
        #AgentLogs Copy
        $AgentPath = Copy-Item -Path $aPath* -Destination $Dest -PassThru
        Write-Output "The log location is $AgentPath"
        
        #SQLDumps Copy (If Exist)
        IF(($DMPExist)){$SQLDPath = Copy-Item -Path $dPath* -Destination $Dest -PassThru
            Write-Output "The log location is $SQLDPath"}
        Else {Write-Output "No SQL Dump is Present"}
    
        #Default Trace Copy
        $DefTrcPath = Copy-Item -Path $tPath* -Destination $Dest -PassThru
            Write-Output "The log location is $DefTrcPath"

     }
}

    
#If the directory doesn't exist (It should as we create it at the beginning but Just in case), create it then copy files
Else
  {
    MD $logDir
   
    #Stage the Copy

    For ($g = 0;$g -lt $LocErrorLog.Count; $g++ ){
        $ePath = $LocErrorLog[$g]
        $aPath = $LocAgentLog[$g] 
        $dPath = $LocSQLDMP[$g] 
        $tPath = $LocDefTrc[$g]
       # Write-Output $ePath 
       # Write-Output $aPath
       # Write-Output $dPath
       # Write-Output $tPath
          
        $LogPath = ""
        $SDir = "$LogDir\Instance$g"
        #Write-Output $SDir

        $FDir = Test-Path -Path $SDir
            If ($FDir){
            Write-Output "Exists"
            $Dest = $SDir
            Write-output $Dest
            }
        
            Else{
            $Folder = $fso.CreateFolder("$LogDir\Instance$g")
            Write-output $Folder.Path
            #$Dest = ""
            $Dest = $SDir
            Write-Output $Dest
            }
      
        #ErrorLogs Copy
        $LogPath = Copy-Item -Path $ePath* -Destination "$Dest" -PassThru
            Write-Output "The log location is $LogPath"
        
        #AgentLogs Copy
        $AgentPath = Copy-Item -Path $aPath* -Destination $Dest -PassThru
        Write-Output "The log location is $AgentPath"
        
        #SQLDumps Copy (If Exist)
        IF(($DMPExist)){$SQLDPath = Copy-Item -Path $dPath* -Destination $Dest -PassThru
            Write-Output "The log location is $SQLDPath"}
        Else {Write-Output "No SQL Dump is Present"}
    
        #Default Trace Copy
        $DefTrcPath = Copy-Item -Path $tPath* -Destination $Dest -PassThru
            Write-Output "The log location is $DefTrcPath"

     }
}

#If clustered, check for cluster log. If not, skip.

If ($ClusBOOL)
{
    #Check the file exists
    $CluDir = Test-Path -Path $LocClusLog
    
    #If the file exists, Copy it to the DBALog directory, Else spawn the log file and copy it       
    If ($CluDir)
        {
        $ClusLogPath = Copy-Item -Path $LocClusLog* -Destination $logDir -PassThru
            Write-Output "The log location is $ClusLogPath"
        }
    Else
        {
        Get-ClusterLog
        $ClusLogPath = Copy-Item -Path $LocClusLog* -Destination $logDir -PassThru
            Write-Output "The log location is $ClusLogPath"
        }
}
Else
{Write-Output "Node is not Clustered, therefore there is no cluster log."}

#Check the file exists
$DmpDir = Test-Path -Path $LocMemDMP
    
#If the file exists, Copy it to the DBALog directory, Else no mem dump exists so nothing to copy       
If ($DmpDir)
    {
    $MemDMPPath = Copy-Item -Path $LocMemDMP -Destination $logDir -PassThru
        Write-Output "The log location is $MemDMPPath"
    }
Else
    {
    #Do Nothing if not exist
        Write-Output "No Memory Dumps Present" #use for testing
    }
#End SQL Log and Cluster Log Gather


#If PS 2.0 we cannot use the compression algorithm. Check and Skip or Compress and finish.
$PSV = $PSVersionTable.PSVersion.ToString()
Write-Output $PSV
    If ($PSV -eq '2.0')
    {
    write-output "Powershell Version 2.0 Installed here. This Script is not fully compatible."
    }
    Else{
    #Package the logs
    $source = "$logDir"
    $Hostname = $env:computername
    $Hostname = $Hostname + "_RCALogs" + $(get-date -f yyy-mm-dd)
    write-output $Hostname
    $destination = "$logDest\$Hostname.zip"

     If(Test-path $destination) {Remove-item $destination}

    Add-Type -assembly "system.io.compression.filesystem"

    [io.compression.zipfile]::CreateFromDirectory($Source, $destination)
    Write-Output "Your file is located at $destination"
    #end Package of Logs

    #Remove the directory so as not to take up unnecessary space
    $FolderPath = "$logDir" 
    #write-output $FolderPath #Use me for testing
    Remove-Item $FolderPath -Force  -Recurse -ErrorAction SilentlyContinue
    #End Directory Deletion
    }
