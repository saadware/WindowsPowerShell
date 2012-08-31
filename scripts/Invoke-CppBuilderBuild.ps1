<#
.SYNOPSIS 
Builds an Embarcadero C++ Builder project or group of projects.

.DESCRIPTION
Enables the building of an Embarcadero C++ Builder project or project group.

.PARAMETER Path
Path of project (cbproj) or group project (groupproj) file.

.PARAMETER Target
Build target like 'Make' or 'Build' or 'Clean'

.PARAMETER Config
Build configuration to use like 'Debug' or 'Debug Build' or 'Release', etc.

.PARAMETER TwineTargetFile
The msbuild target file for TwineCompile

.PARAMETER BDSVersion
The version of BDS installed (default to '15.0').

.PARAMETER WarningAsError
Enables the build option to treat any compile warnings as build errors.

.PARAMETER Rebuild
Forces a rebuild, regardless of the Target specified.

.PARAMETER Diagnose
Turns the verbosity of output to a diagnostic level.

.PARAMETER Quiet
Turns the verbosity of output to quiet where only errors are displayed.

.PARAMETER EnableTwine
Turns the JomiTech, TwineCompile options on (if installed) to dramatically increase compile times.

.INPUTS
System.IO.FileInfo

.OUTPUTS
None.
#>

[CmdletBinding()]
param(
		[Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
		[Alias("PSPath")]
		[string[]]$Path,
		[Parameter(Position=1)]
		$Target = "Make",
		[Parameter(Position=2)]
		$Config = "Debug Build",
		$TwineTargetFile = "C:\Program Files (x86)\JomiTech\TwineCompile\TCTargetsXE.targets",
		$BDSVersion = "15.0",
		[switch]$WarningsAsError,
		[switch]$Rebuild,
		[switch]$Diagnose,
		[switch]$Quiet,
		[switch]$EnableTwine
     )
Begin
{
	Write-Verbose "Starting..."

	# stop on any errors
	#$ErrorActionPreference = "Stop"

	# enable debug if requested
	if ( $Debug )
	{
		$DebugPreference = "Continue"
	}

	# if twine is enabled, ensure the target script exists
	if ( $EnableTwine -and -not (Test-Path $TwineTargetFile) )
	{
		Write-Warning "Invalid twine target file $($TwineTargetFile): disabling twine option"
		$EnableTwine = $false
	}

	# setup environment/pathing
	if ( -not (Test-Path env:BDS) )
	{
		$bds = Get-Command bds.exe -ErrorAction SilentlyContinue | ? { $_.FileVersionInfo.ProductVersion -eq $BDSVersion }
		if ( $bds -eq $null )
		{
			throw "bds.exe could not be found in your path. Ensure it is."
		}
		Set-Item env:BDS (Get-item $bds.Path).Directory.Parent.FullName
		Set-Item env:CG_BOOST_ROOT (join-path (Get-item $bds.Path).Directory.Parent.FullName 'include\boost_1_39')
	}
	Set-Item env:FrameworkDir "C:\Windows\Microsoft.NET\Framework\v2.0.50727"
	Set-Item env:FrameworkVersion "v2.0.50727"
	if ( (Get-Command msbuild.exe -ErrorAction SilentlyContinue) -eq $null )
	{
		Set-Item env:Path "$env:FrameworkDir;$env:Path"
	}
}
Process
{
	function Build-Project
	{
		Process
		{
			$fileObject = $_
			$projectPath = $fileObject.FullName
			$tmpBuildFile = $projectPath 
			Write-Verbose $projectPath
			$twineOptions = ""
			if ( $EnableTwine )
			{
				Write-Verbose "Twine build enabled..."
				$twineOptions = "/p:CoreCompileDependsOnTargets=`"RidlCompile;PasCompile;TCBuildFileList;TCCompile;AsmCompile;RcCompile`""

				# generate temporary project file that has the twine options punched in
				$tmpBuildFile = -join ($projectPath + ".tmp")

				# remove temporary generated twine files (if any)
				rm (join-path $fileObject.Directory 'twfiles.@@@') -ErrorAction SilentlyContinue

				Write-Verbose "adding twine msbuild target to project"
				[xml]$projXml = Get-Content $projectPath
				$projXml.Project.InnerXml = ($projXml.Project.InnerXml + "<Import Project=`'$TwineTargetFile`' />")
				$projXml.OuterXml | Out-File -FilePath $tmpBuildFile -Encoding UTF8
			}

			# Run cmd so that options get sent it properly.
			$theFileOutputName = $fileObject.BaseName
			cmd.exe /c "msbuild.exe /nologo $tmpBuildFile $twineOptions /t:$Target /p:Config=`"$Config`" /p:BCC_WarningIsError=$WarningsAsError /p:OutputName=$theFileOutputName $(if ( $Diagnose ) {'/verbosity:diagnostic' } elseif( $VerbosePreference -eq 'Continue' ) { '/verbosity:detailed' } elseif ( $Quiet ) { '/verbosity:quiet' } else { '/verbosity:normal' }) /p:ForceRebuild=$Rebuild"
			if ( $LASTEXITCODE -ne 0 )
			{
				throw "Failed to compile $projectPath..."
			}
		}
	} # function Build-Project

	$file = $_
	Write-Verbose $file.FullName
	if ( $file.Extension -eq ".groupproj" )
	{
		# A group project contains multiple projects inside of it. Build each one.
		Write-Verbose "processing project group..."
		[xml]$groups = Get-Content $file
		Push-Location $file.Directory
		($groups.Project.ItemGroup | ? { $_.Projects -ne $null }).Projects | 
			Select-Object -Property @{Name="Path"; Expression = {$file.Directory.FullName}},@{Name="ChildPath"; Expression = {$_.Include}} | 
				Join-Path -Resolve | Get-Item | Build-Project
		Pop-Location
	}
	elseif( $file.Extension -eq ".cbproj" )
	{
		Write-Verbose "processing project..."
		$file | Build-Project
	}
	else
	{
		Write-Error ("invalid project file " + $file.FullName)
	}
}
End
{
	Write-Verbose "All Done"
}
