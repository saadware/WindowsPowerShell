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

.PARAMETER BDSVersion
The version of BDS installed (default to XE)

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
		$BDSVersion = "XE",
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

	# attempt to see if we can find it in program files
	$programFilesDir = $Env:ProgramFiles
	if ( Test-Path 'Env:\ProgramFiles(x86)' )
	{
		$programFilesDir = ${env:ProgramFiles(x86)} 
	}

	# Find the msbuild target file for twine
	if ( $EnableTwine )
	{
		$TwineTargetFile = ls $programFilesDir -Recurse -Filter TCTargets*.targets -ErrorAction SilentlyContinue | ? {
			$_.BaseName.EndsWith( $BDSVersion )
		}

		if ( $TwineTargetFile -eq $null )
		{
			Write-Warning "Invalid twine target file $($TwineTargetFile.FullName): disabling twine option"
			$EnableTwine = $false
		}
		else
		{
			Write-Verbose "Found twine target file $($TwineTargetFile.FullName)."
		}
	}
	else
	{
		Write-Verbose "Twine disabled."
	}

	# setup environment/pathing
	if ( -not (Test-Path env:BDS) )
	{
		$bdsVersionNumber = "15.0"
		switch ( $BDSVersion )
		{
			"XE"  { $bdsVersionNumber = "15.0"; break }
			"XE2" { $bdsVersionNumber = "16.0"; break }
			"XE3" { $bdsVersionNumber = "17.0"; break }
		}
		Write-Verbose "Found BDS version $bdsVersionNumber."

		# get bds that matches our version (probably in path)
		$bds = Get-Command bds.exe -ErrorAction SilentlyContinue | ? { $_.FileVersionInfo.ProductVersion -eq $bdsVersionNumber }
		if ( $bds -eq $null )
		{
			$bds = ls -Filter bds.exe -Path (join-path $programFilesDir 'Embarcadero') -Recurse | ? { $_.VersionInfo.ProductVersion -eq $bdsVersionNumber }
			if ( $bds -eq $null )
			{
				throw "bds.exe could not be found in your path. Ensure it is."
			}
		}
		else
		{
			$bds = (Get-Item $bds.Path)
		}
		Set-Item env:BDS $bds.Directory.Parent.FullName
		Set-Item env:CG_BOOST_ROOT (join-path $bds.Directory.Parent.FullName 'include\boost_1_39')
		write-verbose "Using bds: $($bds.FullName)"
	}
	if ( $BDSVersion -eq "XE3" )
	{
		Set-Item env:FrameworkDir "C:\Windows\Microsoft.NET\Framework\v3.5"
		Set-Item env:FrameworkVersion "v3.5"
		Set-Item env:FrameworkSDKDir ""

	}
	else
	{
		Set-Item env:FrameworkDir "C:\Windows\Microsoft.NET\Framework\v2.0.50727"
		Set-Item env:FrameworkVersion "v2.0.50727"
	}
	if ( (Get-Command msbuild.exe -ErrorAction SilentlyContinue).Path -ne "$env:FrameworkDir\MSBuild.exe")
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
				#$twineOptions = "/p:CoreCompileDependsOnTargets=`"RidlCompile;PasCompile;TCBuildFileList;TCCompile;AsmCompile;RcCompile`""

				# generate temporary project file that has the twine options punched in
				$tmpBuildFile = -join ($projectPath + ".tmp")

				# remove temporary generated twine files (if any)
				rm (join-path $fileObject.Directory 'twfiles.@@@') -ErrorAction SilentlyContinue

				Write-Verbose "adding twine msbuild target to project"
				[xml]$projXml = Get-Content $projectPath
				$projXml.Project.InnerXml = ($projXml.Project.InnerXml + "<Import Project=`'$($TwineTargetFile.FullName)`' />")
				$projXml.OuterXml | Out-File -FilePath $tmpBuildFile -Encoding UTF8
			}
			# Run cmd so that options get sent it properly.
			$theFileOutputName = $fileObject.BaseName
			cmd.exe /c "msbuild.exe /nologo $tmpBuildFile $twineOptions /t:$Target /p:Platform=`"Win32`" /p:Config=`"$Config`" /p:BCC_WarningIsError=$WarningsAsError /p:OutputName=$theFileOutputName $(if ( $Diagnose ) {'/verbosity:diagnostic' } elseif( $VerbosePreference -eq 'Continue' ) { '/verbosity:detailed' } elseif ( $Quiet ) { '/verbosity:quiet' } else { '/verbosity:normal' }) /p:ForceRebuild=$Rebuild"
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
