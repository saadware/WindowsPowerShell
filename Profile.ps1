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

###############################################################################
# Alias
###############################################################################
if ( -not (Test-Path alias:sls) )
{
	new-alias sls select-string -Option "AllScope,Constant"
}

# Path to include scripts directory
$scriptsDir = (Resolve-Path (Join-Path (get-item $PROFILE).Directory 'scripts') ).Path
set-item env:Path ( $env:Path + ';' + $scriptsDir )

# location
set-location $env:USERPROFILE 

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
	param([string]$machine, [switch]$fullscreen)
	Invoke-Expression "mstsc /v:$machine $( if($fullscreen) { '/fullscreen' } else { '/w:1280 /h:720' } )"
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

function Get-CustomerBuilds
{

	if ( (Get-Module Mssql) -eq $null )
	{
		Import-Module Mssql
	}
	Invoke-Sqlcmd -ServerInstance lion-o -Database CustomerBuilds -Query "
	select
		s.Name as StartName,
		s.Version + '.' + ltrim(rtrim(s.Number)) as StartVersion,
		--s.Number as StartNumber,
		e.Name as EndName,
		--e.Number as EndNumber,
		e.Version + '.' + ltrim(rtrim(e.Number)) as EndVersion
	from BuildAdjList b
	join Build s on s.BuildID = b.BeginBuildFID
	join Build e on e.BuildID = b.EndBuildFID
	"
}

function Get-GeoIPLocation
{
	$wc = New-Object System.Net.WebClient
	$key = "e691624bc74862d640d62e26327d73211d3a616ff283a3f96c357d3993b49bb7" 
	[xml]$loc = $wc.DownloadString( "http://api.ipinfodb.com/v3/ip-city/?key=$key&format=xml" )
	"$($loc.Response.cityName) $($loc.Response.regionName)"
}

#
# Returns weather information for the given place (city, zip, state, whatever)
#
function Get-Weather
{
	param($place = $(Get-GeoIPLocation))
	$safePlace = (-split $place) -join "+"

	$wc = New-Object System.Net.WebClient
	[xml]$x = $wc.DownloadString( "http://www.google.com/ig/api?weather=$($safePlace)" )

	if ( (Select-Object -InputObject $x.xml_api_reply.weather.problem_cause -Property data) -eq $null )
	{
		$info = $x.xml_api_reply.weather.forecast_information
		$condition = $x.xml_api_reply.weather.current_conditions
		Write-Host -ForegroundColor DarkCyan "Weather for $($info.city.data) as of $([DateTime]::Parse( $info.current_date_time.data) )"
		Write-Host -ForegroundColor DarkCyan "Conditions: $($condition.condition.data)"
		Write-Host -ForegroundColor DarkCyan "$($condition.wind_condition.data)"
		Write-Host -ForegroundColor DarkCyan "Temperature: $($condition.temp_f.data) F | $($condition.temp_c.data) C"
	}
	else
	{
		throw "$($place) is not a valid place with weather info. Please correct and try again."
	}
}
