###############################################################################
# Configure PSCX based on the settings above (or their defaults).
###############################################################################
if ( (Get-PSSnapin Pscx -ErrorAction SilentlyContinue) -eq $null )
{
	Add-PSSnapin Pscx
	. "$Pscx:ProfileDir\PscxConfig.ps1"
}

###############################################################################
# Start Personal Customization
###############################################################################

# setup some environment variables
set-item env:P4_ROOT (join-path $env:UserProfile 'Perforce')
set-item env:P4CLIENT vedanta
set-item env:P4EDITOR 'C:\Program Files (x86)\Vim\vim73\gvim.exe' 
set-item env:NANT_HOME (join-path $env:P4_ROOT  '\nub\nant-0.90')
set-item env:NANT_CONTRIB (join-path $env:P4_ROOT '\nub\nantcontrib-0.85')

# C++Builder
set-item env:BDS (join-path (get-item 'env:\ProgramFiles(x86)').Value 'Embarcadero/RAD Studio/8.0')
set-item env:MADEXCEPT (join-path (get-item 'env:\ProgramFiles(x86)').Value 'madCollection')
set-item env:CXXTEST_HOME (join-path $env:P4_ROOT '\nub\cxxtest')

# Setup some path shite
set-item env:Path ( $env:Path + ';' + (join-path $env:NANT_HOME '\bin') )
set-item env:Path ( $env:Path + ';' + (join-path $env:P4_ROOT 'ssaad\WindowsPowerShell\scripts') )
set-item env:Path "$env:Path;c:\Python25;c:\MinGW\bin;c:\Ruby\bin;x:\Tools;x:\mysql\bin;X:\tools\chromium_depot_tools"

# Change to the all famous x drive
set-location $env:P4_ROOT


###############################################################################
# Functions
###############################################################################

# Build any project files
function mkp([switch]$rebuild)
{
	ls *.cbproj | TwineBuild.ps1 -Target $( if ( $rebuild ) { "Build" } else { "Make" } )
}

# Build any group files
function mkg($branch = "Main", [switch]$rebuild)
{
	Get-Item (Join-Path (Get-P4BranchClientView $branch) "MoversSuite\MoversSuite.groupproj") | TwineBuild.ps1 -Target $( if ( $rebuild ) { "Build" } else { "Make" } )
}

# Build components 
function mkc($branch = "Main", [switch]$rebuild)
{
	Get-Item (Join-Path (Get-P4BranchClientView $branch) "Components\Borland\MssComponents.cbproj") | TwineBuild.ps1 -Target $( if ( $rebuild ) { "Build" } else { "Make" } )
}

# Retrieves the client mapping for a specific perforce branch
function Get-P4BranchClientView($branch = "Main", $depot = "asd")
{
	$branchView = "//$depot/Main/..."
	if ( $branch -ne "Main" )
	{
		$branchView = -split (p4 branch -o $branch | select-string "//.+\.\.\. //.+\.\.\." | select -ExpandProperty Line) | select -Last 1
	}
	(-split (p4 where $branchView) | select -Last 1) -replace "\\\.\.\.", ""
}

# Prompt
function prompt
{
	$(if (test-path variable:/PSDebugContext) { '[DBG]: ' } else { '' }) + 'PS:' + $((Get-Location).Path -split "\\" | select -last 1) + $(if ($nestedpromptlevel -ge 1) { '>>' }) + '> '
}

# Create a tiny url
function New-TinyUrl($url)
{
    (new-object net.webclient).downloadString("http://tinyurl.com/api-create.php?url=$url")
}

# Generates a config based off the branch specified and runs ccnet
function ccnet
{
	param
	(
		[Parameter(Mandatory=$true)]
		$branch, 

		[Parameter(Mandatory=$true)]
		$production,

		$snapshot = "$($production)_snap",

		[Parameter(Mandatory=$true)]
		$gp,

		$template = $null
	)


	$theCcnetRoot = ( join-path $env:P4_ROOT 'nub\ccnet-1.5.7256.1' )

	push-location ( join-path $theCcnetRoot 'server' )
	generate-ccnet -branch $branch -gp $gp -production $production -snapshot $snapshot -template $template | out-file -encoding UTF8 ( join-path $theCcnetRoot "server\$branch.crap.ccnet.config" )
	& .\ccnet.exe `-config:$branch.crap.ccnet.config 
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
	param([string] $machine)
	mstsc /w:1280 /h:1024 /v:$machine
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

# change over to diff nant env
function Set-NAntEnv
{
	param([string]$name)
	
	$theNAntPath = ''
	$thePathEnv = ';'
	lsp | Where-Object { $_ -notlike "*nant*" } | ForEach-Object -Process { $thePathEnv += $_ + ';' } -End { $theNewPath = $thePathEnv.TrimEnd(';') }

    if ( $name -eq 'cvs' )
    {	
        $theNAntPath = 'C:\Users\ssaad\Perforce\ssaad\nant-work\nant\build\net-2.0.win32\nant-0.86-debug'
    }
    elseif ( $name -eq 'dev' )
    {
        $theNAntPath = 'C:\Users\ssaad\Perforce\nub\nant-0.85'
    }
    else 
    {
        Write-Error "invalid specification: $name"
    }
	
	if ( $theNAntPath -ne '' )
	{	
        Set-Item -Path env:NANT_HOME -Value $theNAntPath
		Set-Item -Path env:PATH -Value (Join-String @( (Join-Path $theNAntPath '\bin'), $thePathEnv))
		"Path now: `n$env:Path"
	}
}

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

# Setup the test mq stuff for unigroup
function Setup-TestUniGroupMQ
{
	Add-PSSnapin IBM*
	#[IBM.WMQ.MQEnvironment]::SSLKeyRepository = 'C:\tmp\utqm_unigroup\MQKeys'
	#[IBM.WMQ.MQEnvironment]::SSLCipherSpec = 'TRIPLE_DES_SHA_US'
	#$conn = New-WMQQmgrConnDef -name UTQX -HostName devagentmq01.unigroupinc.com -Port 14145 -Channel MOVER.CLIENT.LN72T33
	#Get-WMQQueueManager -Name UTQX -Connections $conn
	
	#set-item env:MQCHLLIB 'C:\tmp\utqm_unigroup'
	#set-item env:MQCHLTAB 'UTQXClient.tab'
	#set-item env:MQSSLKEYR 'C:\tmp\utqm_unigroup\MQKeys'

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
