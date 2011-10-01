function New-RestoreDatabaseBuild
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		$database,
		[Parameter(Mandatory=$false)]
		$server = $((get-item env:ComputerName).Value)
		[Parameter(Mandatory=$true)]
		$productionDatabase,
		[Parameter(Mandatory=$false)]
		$productionSnapshot = $(-join ($productionDatabase, "_snap"))
		[Parameter(Mandatory=$false)],
		$productionServer = $((get-item env:ComputerName).Value)
	)
	nant /D:inProductionServer=$productionServer /D:inSourceServer=$server /D:inTablesToExclude=(TEMP_).+ /D:inDatabaseName= /D:inProductionDatabase=$productionDatabase /D:inProductionDBSnapshotName=$productionSnapshot  /D:inDynProductionDatabase=Dynamics /D:inDynamicsDBSnapshotName=Dynamics_snap /D:inGPProductionDatabase=@GP_DATABASE@ /D:inGPDBSnapshotName=@GP_DATABASE@_snap
}
