<#
.SYNOPSIS 
Backup open Perforce files.

.DESCRIPTION
Creates a 7-Zip archive of all files that the perforce client has opened. The 
client directory structure is maintained in the 7-Zip archive.

.PARAMETER OutputPath
Specifies the name and path for the 7-Zip archive. By default, 
Backup-P4Opened.ps1 generates a name for the archive, and saves it to the 
current directory.

.PARAMETER 7z
Specifies the location of 7z.exe. By default, Backup-P4Opened.ps1 looks for it 
in C:\Program Files\7-Zip\7z.exe.

.INPUTS
None. You cannot pipe objects to Backup-P4Opened.ps1.

.OUTPUTS
None. Backup-P4Opened.ps1 does not generate any output.

.EXAMPLE
C:\PS> .\Backup-P4Opened.ps1

.EXAMPLE
C:\PS> .\Backup-P4Opened.ps1 -outputpath C:\Backup\myCode.7z
#>

param
( 
	$OutputPath = ( Join-Path $pwd "p4opened_$(Get-Date -format yyyyMMddHHmmss).7z" ),
	$7z = 'C:\Program Files\7-Zip\7z.exe'
)

# ensure 7z exists
if ( -not ( Test-Path $7z ) )
{
	$ex = New-Object System.ArgumentException "The path specified ($7z) is not found."
	throw $ex
}

Write-Verbose "7-Zip being used from $7z"

# find the p4 client root
$clientRoot = -split (p4 info | select-string "Client root:" -List | select -ExpandProperty Line ) | select -Last 1
Push-Location $clientRoot

Write-Verbose "7-Zip archive will be saved to $OutputPath"

# parse all open p4 files and add them to the 7z archive
p4 opened //... | % { 
	$i = $_.IndexOf( '#' )
	$b = $_.Substring( 0, $i ) 
	$b } | % { 
		$n = (-split (p4 where $_)) | select -Last 1 | Resolve-Path -Relative
		& $7z a $OutputPath $n.SubString(2) 
	}

Pop-Location
