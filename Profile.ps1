###############################################################################
# Configure PSCX based on the settings above (or their defaults).
###############################################################################
if ( (Get-PSSnapin Pscx -ErrorAction SilentlyContinue) -eq $null -and (Get-PSSnapin Pscx -reg -ErrorAction SilentlyContinue) -ne $null )
{
        Add-PSSnapin Pscx
        . "$Pscx:ProfileDir\PscxConfig.ps1"
}

###############################################################################
# Start Personal Customization
###############################################################################

# Path to include scripts directory
$scriptsDir = (Resolve-Path (Join-Path (get-item $PROFILE).Directory 'scripts') ).Path

set-item env:Path ( $env:Path + ';' + $scriptsDir )
# Perforce (if available)
if ( $null -ne ( Get-Command p4.exe -ErrorAction SilentlyContinue ) )
{
    . "$scriptsDir\Initialize-Perforce.ps1"
}

# Path
set-item env:Path "$env:Path;c:\Python25;c:\MinGW\bin;c:\Ruby\bin;x:\Tools;x:\mysql\bin;X:\tools\chromium_depot_tools"

# If we have perforce then set our location to that
if ( $null -ne ( Get-Item env:P4_ROOT -ErrorAction SilentlyContinue ))
{
    set-location $env:P4_ROOT
}
else
{
    set-location $env:USERPROFILE 
}

###############################################################################
# Functions
###############################################################################

# override prompt
function prompt
{
        $(if (test-path variable:/PSDebugContext) { '[DBG]: ' } else { '' }) + 'PS:' + $((Get-Location).Path -split "\\" | select -last 1) + $(if ($nestedpromptlevel -ge 1) { '>>' }) + '> '
}

# Exposes the environment vars in a batch and sets them in this PS session
function Get-Batchfile ($file) 
{
    $theCmd = "`"$file`" & set" 
    cmd /c $theCmd | % {
        $thePath, $theValue = $_.split('=')
        Set-Item -path env:$thePath -value $theValue
    }
}

# Sets the VS variables for this PS session to use
function VsVars32($version = "9.0")
{
    $theKey = "HKLM:SOFTWARE\Microsoft\VisualStudio\" + $version
    $theVsKey = get-ItemProperty $theKey
    $theVsInstallPath = [System.IO.Path]::GetDirectoryName($theVsKey.InstallDir)
    $theVsToolsDir = [System.IO.Path]::GetDirectoryName($theVsInstallPath)
    $theVsToolsDir = [System.IO.Path]::Combine($theVsToolsDir, "Tools")
    $theBatchFile = [System.IO.Path]::Combine($theVsToolsDir, "vsvars32.bat")
    Get-Batchfile $theBatchFile
}


# Runs a remote desktop connection to the specified machine
function rdc
{
        param([string] $machine, [switch]$fullscreen)
        #Invoke-Expression "mstsc /v:$machine $(if($fullscreen){ /fullscreen } else{ /w:1280 /h:1024 })"
        "mstsc /v:$machine $(if($fullscreen){ /fullscreen } else{ /w:1280 /h:1024 })"
}

# restore a database from snapshot
function Restore-DatabaseFromSnapshot
{
        param
        (
                $Server = $( [Environment]::MachineName ),
                [Parameter(Mandatory=$true, Position=0)]
                $Database,
                $Snapshot = $Database + "_snap"
        )
        sqlcmd -S $Server -Q "restore database $Database from database_snapshot = `'$Snapshot`'"
}
set-alias rds Restore-DatabaseFromSnapshot

# create new database snapshot
function New-DatabaseSnapshot
{
        param
        (
                [Parameter(Mandatory=$true)]
                $Database,
                $Server = $( [Environment]::MachineName ),
                $Filename,
                $Logical,
                $Snapshot = $Database + "_snap"
        )
        if ( ( Get-PSSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue ) -eq $null )
        {
                if ( (Get-Module mssql) -eq $null )
                {
                        throw "The sql cmdlet needs to be loaded (possibly with Import-Module Mssql)"
                }
        }
        $helpFile = Invoke-Sqlcmd -ServerInstance $Server -Database $Database "exec sp_helpfile" | ? { $_.filename.Endswith( ".mdf" )} 
        if ( $Logical -eq $null )
        {
                $Logical = $helpFile | select -ExpandProperty name
        }
        if ( $Filename -eq $null )
        {
                $FileName = ($helpFile | select -ExpandProperty filename) -replace "\..*", "_snap.ss"
        }

        Invoke-Sqlcmd -ServerInstance $Server "create database $Snapshot on ( name = `'$logical`' , filename= `'$Filename`') as snapshot of $Database"
}

# drop a database
function Remove-Database
{
        param
        (
                $Server = $( [Environment]::MachineName ),
                [Parameter(Mandatory=$true)]
                $Database
        )
        sqlcmd -S $Server -Q "drop database $Database"
}

# add user
function Grant-DatabaseUser
{
        param
        (
                $Server = $( [Environment]::MachineName ),
                [Parameter(Mandatory=$true)]
                $Database,
                [Parameter(Mandatory=$true)]
                $User
        )

        sqlcmd -S $Server -d $Database -Q "exec sp_grantdbaccess `'$User`'"
}

# add user to role
function Add-DatabaseRoleMember
{
        param
        (
                $Server = $( [Environment]::MachineName ),
                [Parameter(Mandatory=$true)]
                $Database,
                [Parameter(Mandatory=$true)]
                $User,
                [Parameter(Mandatory=$true)]
                $Role
        )

        sqlcmd -S $Server -d $Database -Q "exec sp_addrolemember `'$Role`', `'$User`'"
}

# A function to help find stuff in files
function fif
{
        param([string]$include, [string]$search)
        get-childitem -include $include -recurse | where-object{(select-string -inputObject $_ -pattern $search )}
}

# Search and replace files
function search-and-replace
{
        param([string]$include, 
                [string]$pattern, 
                [string]$replace, 
                [bool]$p4edit=$false,
                [bool]$simulate=$false)

        $theNumFilesModified = 0
        $theFilesToInclude = get-childitem -include $include -recurse | where-object{(select-string -inputObject $_ -pattern $pattern )}
        foreach( $theFile in $theFilesToInclude )
        {
                if ( $theFile -ne $null )
                {
                        write-output $theFile.FullName

                        # Only modify things if requested
                        if ( $simulate -ne $true )
                        {
                                # Check out the file from perforce if desired
                                if ( $p4edit )
                                {
                                        p4 edit $theFile.FullName
                                }

                                $theContent = get-content -path $theFile.FullName
                                $theContent | foreach{ $_ -replace $pattern, $replace } | set-content -path $theFile.FullName
                                $theNumFilesModified += 1
                        }
                }
        }

        $theOutput = "There were " + "$theNumFilesModified" + " files modified."
        write-output $theOutput
}

# Locates the execution path(s) of the specified file
function get-exepath
{
        param([string]$name)

        [System.IO.FileInfo[]]$theFindings = $() 
        foreach( $thePathDir in Get-EnvPath )
        {
                if ( $thePathDir -ne "" -and [System.IO.Directory]::Exists( $thePathDir ) )
                {
                        $thePotentialFile = Join-Path $thePathDir $name
                        if ( [System.IO.File]::Exists( $thePotentialFile ) ) 
                        {
                                $theFindings += new-object System.IO.FileInfo $thePotentialFile
                        }
                }

        }
        $theFindings
}

function which
{
        param([string]$name)
        Get-ChildItem -path (Get-EnvPath) -filter $name
}

########################################################
# Aliases
########################################################
set-alias ssh putty.exe
#
# Returns 32 or 64 bit of currently running powershell
#
function Get-PowerShellBitNess
{
    ps powershell | ? { $PID -eq $_.id } | ls | % { 
        if ( $_.DirectoryName -notlike "*syswow64*" )
        { 
            "x64"
        } 
        else 
        {
            "x86"
        }
    }
}
set-alias poshbit Get-PowerShellBitNess

# list the path env var in an easy to read format
function Get-EnvPath 
{
        $env:Path.Split(";") | where {[System.IO.Directory]::Exists($_)}
}
set-alias lsp Get-EnvPath

# Set the CSVROOT for sourceforge nant project
function Set-CVSNantEnv {set-item -Path env:CVSROOT -Value ':pserver:anonymous@nant.cvs.sourceforge.net:/cvsroot/nant'}
set-alias cvs-nant Set-CVSNantEnv

# Function to kill sql connections
function Kill-Sql
{
        param
        ( 
                $Server = $( [Environment]::MachineName ), 
                [Parameter(Mandatory=$true)]
                $Database
        )
        
        $theKillSql = "
                use master
                declare @theSql varchar(max)
                set @theSql = ''
                select @theSql = @theSql + 'kill ' + convert(varchar, SPId) + ';' from SysProcesses where DBId = DB_ID('$Database') and SPId != @@SPId
                exec(@theSql)
                "
        sqlcmd -E -S $Server -Q $theKillSql
}

function New-Zip
{
        param([string]$Path)
        Set-Content $Path ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
        (Get-Item $Path).IsReadOnly = $false
}

function Add-Zip
{
        param([string]$Path)

        Begin {
                if ( -not (Test-Path $Path) )
                {
                        New-Zip $Path
                }
                $shell = New-Object -ComObject Shell.Application
                $Path = Resolve-Path $Path
                $zip = $shell.NameSpace( $Path )
        }

        Process {
                $file = ( -join ('"', $_.FullName, '"') )
                if ( $zip -ne $null )
                {
                        $zip.CopyHere( $file, 0 )
                }
                else { "ASS $_" }
                sleep -milliseconds 500 
        }
}

function sysint { cd \\live.sysinternals.com\Tools }

function Add-CodeGuard($path)
{
        resolve-path $path | select -ExpandProperty Path -OutVariable project
        $x = ([xml](get-content $path)).Project.PropertyGroup | ? { $_.HasAttribute( "Condition" ) -and $_.Condition -eq "'`$(Base)'!=''" -and $_.BCC_AllCodeguardOptions -eq $null }
        if ( $x -ne $null )
        {
                $x.InnerXml = "<BCC_AllCodeguardOptions>true</BCC_AllCodeguardOptions>$($x.InnerXml)"
                $x.ParentNode.ParentNode.Save( $path )
        }
}

function cc
{
        ccnet -branch Main -production MainJohnson -gp JSM
}

function Get-CustomerBuilds
{

        if ( (Get-Module Mssql) -eq $null )
        {
                Import-Module Mssql
        }
        Invoke-Sqlcmd -ServerInstance lion-o -Database CustomerBuilds -Query "
select
        s.Name as StartName,
        s.Number as StartNumber,
        e.Name as EndName,
        e.Number as EndNumber
from BuildAdjList b
join Build s on s.BuildID = b.BeginBuildFID
join Build e on e.BuildID = b.EndBuildFID
"
}

function Enter-Build05
{
        Enter-PSSession -ComputerName build05.moverssuite.internal -Credential (Get-Credential moverssuite\build) -Authentication CredSSP
}
