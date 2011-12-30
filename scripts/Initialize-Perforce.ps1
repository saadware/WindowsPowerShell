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

# setup some environment variables
if ( -not (test-path env:P4CLIENT) )
{ 
	set-item env:P4CLIENT $env:COMPUTERNAME 
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

# Other variables 
set-item env:NANT_HOME (join-path $env:P4_ROOT  '\nub\nant-0.90')
set-item env:NANT_CONTRIB (join-path $env:P4_ROOT '\nub\nantcontrib-0.85')
set-item env:CXXTEST_HOME (join-path $env:P4_ROOT '\nub\cxxtest')

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
        $branchView = "//$depot/Main/..."
        if ( $branch -ne "Main" )
        {
                $branchView = -split (p4 branch -o $branch | select-string "//.+\.\.\. //.+\.\.\." | select -ExpandProperty Line) | select -Last 1
        }
        (-split (p4 where $branchView) | select -Last 1) -replace "\\\.\.\.", ""
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

