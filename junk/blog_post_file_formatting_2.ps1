# Script for blog post formatting

# First remove all spaces in png filenames
<#
$Files = Get-ChildItem -Path ".\Screenshots" -File

ForEach ($File in $Files){
    Write-Host "Processing File: $($File.Name)"
    $NewFileName = $File.Name.Replace(' ', '_')
    Rename-Item -Path ".\Screenshots\$($File.Name)" -NewName "$($NewFileName)"
}
#>

# Then replace the filenames in the markdown file

$MarkDownFilePath = ".\WriteUp.md"

$MarkDownContent = Get-Content -Path $MarkDownFilePath

$regex = ".*\.png\]\]"

ForEach ($line in $MarkDownContent){
    if ($line -match $regex){
        Write-Host "Line match: $($line)"
        $filename = $line.split("/")[-1].split("[[")[-1].split("]]")[0]
        $newline = "![Screenshots](./Screenshots/$filename)"
        #Write-Host $newline
        $new_content = $(Get-Content -Path $MarkDownFilePath).replace($line, $newline)
        $new_content | Set-Content -Path $MarkDownFilePath
    }
}