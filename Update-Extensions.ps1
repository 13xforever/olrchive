#/usr/bin/pwsh

$files = @(Get-ChildItem *.mp3 -Recurse)
foreach ($f in $files)
{
    $ext = "$(Split-Path $f.Name -Extension)"
    $lowerExt = $ext.ToLower()
    if ($ext -ceq $lowerExt)
    {
        continue
    }

    $newName = Split-Path $f.Name -LeafBase
    Rename-Item $f.FullName "$newName$lowerExt"
}