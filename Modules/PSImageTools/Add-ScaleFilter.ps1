#requires -version 2.0
function Add-ScaleFilter {    
    <#
    .Synopsis
    Creates a filter for resizing images.

    .Description
    The Add-ScaleFilter function adds a scale filter to an image filter collection.
    It creates a new filter collection if none exists. 

    An image filter is Windows Image Acquisition (WIA) concept.
    Each filter represents a change to an image. 

    Add-ScaleFilter does not resize images; it only creates a filter.
    To resize images, use the Resize method of the Get-Image function, or use the 
    Set-ImageFilter function, which applies the filters.

    The Width and Height parameters of this function are required and the Image 
    parameter is optional. If you specify an image, you can specify Width and Height 
    as percentages (values less than 1). If you do not specify an image, you 
    must specify the Width and Height in pixels (values greater than 1).

    .Parameter Image
    Creates a scale filter for the specified image.
    Enter an image object, such as one returned by the Get-Image function.
    This parameter is optional.
    If you do not specify an image, Add-ScaleFilter creates a scale filter that is not image-specific.

    If you do not specify an image, you cannot specify percentage values (values less than 1) for the
    Width or Height parameters.

    .Parameter Filter
    Enter a filter collection (Wia.ImageProcess COM object).
    Each filter in the collection represents a unit of modification to a WiA ImageFile object.
    This parameter is optional. If you do not submit a filter collection, Add-ScaleFilter creates one for you.

    .Parameter Width
    [Required] Enter the desired width of the resized image.
    To specify pixels, enter a value greater than one (1).
    To specify a percentage, enter a value less than one (1), such as ".25".
    Percentages are valid only when the command includes the Image parameter.

    .Parameter Height
    [Required] Enter the desired height of the resized image.
    To specify pixels, enter a value greater than one (1).
    To specify a percentage, enter a value less than one (1), such as ".25".
    Percentages are valid only when the command includes the Image parameter.

    .Parameter DoNotPreserveAspectRatio
    The filter does not preserve the aspect ratio when resizing. By default, the aspect ratio is preserved.

    .Parameter Passthru
    Returns an object that represents the scale filter. By default, this function does not generate output.

    .Notes
    Add-ScaleFilter uses the Wia.ImageProcess object.

    .Example
    # Creates a scale filter that resizes an image to 100 x 100 pixels.
    Add-ScaleFilter –width 100 –height 100 –passthru

    .Example
    $i = get-image .\Photo01.jpg
    Add-ScaleFilter –image $i –witdh .5 –height .3  -DoNotPreserveAspectRatio -passthru

    .Example
    C:\PS> $sf = Add-ScaleFilter –width 100 –height 100 –passthru
    C:\PS> ($sf.filters | select properties).properties | format-table Name, Value –auto

    Name                Value
    ----                -----
    MaximumWidth          100
    MaximumHeight         100
    PreserveAspectRatio  True
    FrameIndex              0

    .Example
    $image = Get-Image .\Photo01.jpg            
    $NewImage = $image | Set-ImageFilter -filter (Add-ScaleFilter -Width 200 -Height 200 -passThru) -passThru                    
    $NewImage.SaveFile(".\Photo01_small.jpg")

    .Link
    Get-Image

    .Link
    Set-ImageFilter

    .Link
    Image Manipulation in PowerShell:
    http://blogs.msdn.com/powershell/archive/2009/03/31/image-manipulation-in-powershell.aspx

    .Link
    "ImageProcess object" in MSDN
    http://msdn.microsoft.com/en-us/library/ms630507(VS.85).aspx

    .Link
    "Filter Object" in MSDN 
    http://msdn.microsoft.com/en-us/library/ms630501(VS.85).aspx

    .Link
    "How to Use Filters" in MSDN
    http://msdn.microsoft.com/en-us/library/ms630819(VS.85).aspx
    #>

    param(
    [Parameter(ValueFromPipeline=$true)]
    [__ComObject]
    $filter,
    
    [__ComObject]
    $image,
        
    [Double]$width,
    [Double]$height,
    
    [switch]$DoNotPreserveAspectRatio,
    
    [switch]$passThru                      
    )
    
    process {
        if (-not $filter) {
            $filter = New-Object -ComObject Wia.ImageProcess
        } 
        $index = $filter.Filters.Count + 1
        if (-not $filter.Apply) { return }
        $scale = $filter.FilterInfos.Item("Scale").FilterId                    
        $isPercent = $true
        if ($width -gt 1) { $isPercent = $false }
        if ($height -gt 1) { $isPercent = $false } 
        $filter.Filters.Add($scale)
        $filter.Filters.Item($index).Properties.Item("PreserveAspectRatio") = "$(-not $DoNotPreserveAspectRatio)"
        if ($isPercent -and $image) {
            $filter.Filters.Item($index).Properties.Item("MaximumWidth") = $image.Width * $width
            $filter.Filters.Item($index).Properties.Item("MaximumHeight") = $image.Height * $height
        } else {
            $filter.Filters.Item($index).Properties.Item("MaximumWidth") = $width
            $filter.Filters.Item($index).Properties.Item("MaximumHeight") = $height
        }
        if ($passthru) { return $filter }         
    }
}
