$script:ErrorActionPreference = "Stop"

$downloadedFile = join-path ([System.IO.Path]::GetTempPath()) "KeePassHttp.plgx"
if ( Test-Path $downloadedFile )
{
	rm $downloadedFile -Force
}
$keepassDir = "C:\Program Files (x86)\KeePass Password Safe 2\"
if ( -not (Test-Path $keepassDir) )
{
	throw "KeePass directory not found: $keepassDir"
}


$url = "https://raw.github.com/pfn/keepasshttp/master/KeePassHttp.plgx"
$wc = new-object System.Net.WebClient
$wc.DownloadFile($url, $downloadedFile)

try
{
	mv -Force $downloadedFile $keepassDir
}
catch [System.UnauthorizedAccessException]
{
	Write-Warning "Hmmm... unable to update existing plugin. Are you running as Admin?"
	throw
}

# Restart KeePass if already running
$proc = ps KeePass -ErrorAction SilentlyContinue
if ( $proc -ne $null )
{
	$keepassApp = $proc.Path
	$proc.CloseMainWindow()
	Invoke-Item $keepassApp
}
