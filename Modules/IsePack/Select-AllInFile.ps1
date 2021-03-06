function Select-AllInFile {
    <#
    .Synopsis
        Selects all of the text within a given file in the ISE
    .Description
        Selects all of the text within a given file in the Windows PowerShell
        Integrated Scripting Environment
    .Example
        Select-AllInFile $psise.CurrentFile
    #>
    param(
    # The file from the integrated scripting editor (i.e. $psise.CurrentFile)
    [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
    [Microsoft.PowerShell.Host.ISE.ISEFile]
    $File
    )
    
    process {
        $file.Editor.Select(1,
            1,
            $file.Editor.LineCount,
            $file.Editor.GetLineLength($file.Editor.LineCount) + 1
        )
    }
}