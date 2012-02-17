###############################################################################
# Initializes anything that has to do with a Perforce environment
###############################################################################
# First figure out if we're logged in
p4 login -s | out-null
if ( $LASTEXITCODE -ne 0 )
{
	"Login into perforce please..."
	p4 login
}

# determine user name
$p4User = (p4 user -o | sls -Pattern "^User:\s+(?<user>\w+)").Matches[0].Groups["user"].Value

# setup some environment variables
if ( -not (test-path env:P4CLIENT) )
{ 
	# Determine the last client this user submitted changes under
	if ( (p4 changes -m 1 -u $p4User | Measure ).Count -ne 1 )
	{
		set-item env:P4CLIENT $env:COMPUTERNAME 
	}
	else
	{
		$p4Client = (p4 changes -m 1 -u $p4User | sls -Pattern "$p4User@(?<client>\w+\b)").Matches[0].Groups["client"].Value
		set-item env:P4CLIENT $p4Client
	}
}
set-item env:P4_ROOT (p4 client -o | Select-String -Pattern "^Root:\s+(?<path>\w:.*$)").Matches[0].Groups["path"].Value

# Needs help with hard coded paths
$is64bit = ( $null -ne (get-item 'env:\ProgramFiles(x86)' -ErrorAction SilentlyContinue) )
if ( $is64bit )
{
    $gvimExe = get-item (join-path (get-item 'env:\ProgramFiles(x86)').Value 'Vim\vim73\gvim.exe')
}
else
{
    $gvimExe = get-item (join-path (get-item 'env:\ProgramFiles').Value 'Vim\vim73\gvim.exe')
}
set-item env:P4EDITOR $gvimExe.FullPath

# Setup some path shite
set-item env:Path ( $env:Path + ';' + (join-path $env:NANT_HOME '\bin') )
set-item env:Path ( $env:Path + ';' + (join-path $env:P4_ROOT 'ssaad\WindowsPowerShell\scripts') )

# Build any group files
function mkg($branch = "Main", [switch]$rebuild, $config = "Debug Build")
{
        Get-Item (Join-Path (Get-P4BranchClientView $branch) "MoversSuite\MoversSuite.groupproj") | Invoke-CppBuilderBuild.ps1 -EnableTwine -Target $( if ( $rebuild ) { "Build" } else { "Make" } ) -Config $config
}

# Build components 
function mkc($branch = "Main", [switch]$rebuild, $config = "Debug Build")
{
        Get-Item (Join-Path (Get-P4BranchClientView $branch) "Components\Borland\MssComponents.cbproj") | Invoke-CppBuilderBuild.ps1 -EnableTwine -Target $( if ( $rebuild ) { "Build" } else { "Make" } ) -Config $config
}

# Build all project files
function mkp([switch]$rebuild, $config="Debug Build")
{
	ls *.cbproj | Invoke-CppBuilderBuild.ps1 -EnableTwine -Target $( if ( $rebuild ) { "Build" } else { "Make" } ) -Config $config
}

# Retrieves the client mapping for a specific perforce branch
function Get-P4BranchClientView($branch = "Main", $depot = "asd")
{
	if ( (p4 info | sls -Pattern 'Client stream:' -quiet) )
	{
		Get-P4StreamView
	}
	else
	{
		$branchView = "//$depot/Main/..."
		if ( $branch -ne "Main" )
		{
			$branchView = -split (p4 branch -o $branch | select-string "//.+\.\.\. //.+\.\.\." | select -ExpandProperty Line) | select -Last 1
		}
		get-item ((-split (p4 where $branchView) | select -Last 1) -replace "\\\.\.\.", "")
	}
}

# Retrieves the client mapping for a specific perforce stream
function Get-P4StreamView
{
	$p4Info = p4 info
	$clientRoot = $p4Info | sls -Pattern 'Client root: (.*)'
	if ( $clientRoot -ne $null )
	{
		get-item $clientRoot.Matches[0].Groups[1].Value
	}
}


function Set-P4Stream
{
	[CmdletBinding(DefaultParameterSetName="name")]
	param
	(
		[Parameter( Position=0, Mandatory=$true, ParameterSetName="path" )]
		$path, 
		[Parameter( Position=0, Mandatory=$true, ParameterSetName="name" )]
		$name,
		[Parameter( Position=1, Mandatory=$false )]
		[switch]
		$update

	)
	if ( $PSCmdlet.ParameterSetName -eq 'path' )
	{
		p4 workspace -s -S $path
		if ( $update )
		{
			Write-Output "Updating stream $path..."
			p4 update -q
			$history = get-history -count 1
			$syncTime = ($history.EndExecutionTime - $history.StartExecutionTime).TotalMilliseconds
			Write-Verbose "Sync time took $syncTime ms"
		}
	}
	else
	{
		$stream = p4 streams -F "Name=$name"
		if ( $stream -eq $null )
		{
			throw "Stream with name, $name, not found."
		}
		$path = (-split $stream)[1]
		p4 workspace -s -S $path

		if ( $update )
		{
			Write-Output "Updating stream $path..."
			p4 update -q
			$history = get-history -count 1
			$syncTime = ($history.EndExecutionTime - $history.StartExecutionTime).Milliseconds
			Write-Verbose "Sync time took $syncTime ms"
		}
	}
}

# Generates blank ccnet config for use with building
function ccbuilds
{
        $root = ( join-path $env:P4_ROOT 'nub\ccnet-1.5.7256.1' )
	$config = "ccbuilds.crap.ccnet.config"
        push-location ( join-path $root 'server' )
         "<cruisecontrol></cruisecontrol>" | out-file -encoding UTF8 ( join-path $root $config )
        & .\ccnet.exe `-config:$config
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


        $root = ( join-path $env:P4_ROOT 'nub\ccnet-1.5.7256.1' )

        push-location ( join-path $root 'server' )
        generate-ccnet -branch $branch -gp $gp -production $production -snapshot $snapshot -template $template | out-file -encoding UTF8 ( join-path $root "server\$branch.crap.ccnet.config" )
        & .\ccnet.exe `-config:$branch.crap.ccnet.config 
}

# shortcut for main building
function cc
{
        ccnet -branch Main -production MainJohnson -gp JSM
}

