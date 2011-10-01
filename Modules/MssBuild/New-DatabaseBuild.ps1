function New-DatabaseBuild
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		$database,
		[Parameter(Mandatory=$false)]
		$server = $((get-item env:ComputerName).Value)
	)
	nant /D:inDatabaseName=$database /D:inSourceServer=$server createdatabase
}
