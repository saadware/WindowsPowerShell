###############################################################################
# Initializes anything that has to do with a Perforce environment
###############################################################################
# setup some environment variables
set-item env:P4CLIENT env:COMPUTERNAME
set-item env:P4_ROOT (join-path $env:UserProfile 'Perforce')

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
