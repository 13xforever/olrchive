#/usr/bin/pwsh

$monthMap = @{
    'January'   = '01'
    'February'  = '02'
    'March'     = '03'
    'April'     = '04'
    'May'       = '05'
    'June'      = '06'
    'July'      = '07'
    'August'    = '08'
    'September' = '09'
    'October'   = '10'
    'November'  = '11'
    'December'  = '12'
    'Jan'       = '01'
    'Feb'       = '02'
    'Mar'       = '03'
    'Apr'       = '04'
    'Jun'       = '06'
    'Jul'       = '07'
    'Aug'       = '08'
    'Sep'       = '09'
    'Sept'      = '09'
    'Oct'       = '10'
    'Nov'       = '11'
    'Dec'       = '12'
}

$files = @(Get-ChildItem *.mp3)
foreach ($f in $files)
{
    if ("$($f.Name)" -match '.+_ ?\d{6}\.mp3')
    {
        $dateStr = ((Split-Path $f.Name -LeafBase) -split '_')[-1].Trim()
        $m = $dateStr.Substring(0, 2)
        $d = $dateStr.Substring(2, 2)
        $y = $dateStr.Substring(4, 2)
    }
    elseif ("$($f.Name)" -match '.+ - \d+_\d+_\d+\.mp3')
    {
        $dateStr = ((Split-Path $f.Name -LeafBase) -split ' ')[-1]
        $parts = @($dateStr -split '_')
        $m = $parts[0].PadLeft(2, '0')
        $d = $parts[1].PadLeft(2, '0')
        $y = $parts[2].PadLeft(2, '0')
    }
    elseif ("$($f.Name)" -match '.+ \w+ \d+(st|nd|rd|th)?, \d+\.mp3')
    {
        $match = [Regex]::Match($f.Name, '.+ (?<month>\w+) (?<day>\d+)(st|nd|rd|th)?, (?<year>\d+)\.mp3', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $m = $monthMap[$match.Groups['month'].Value]
        $d = $match.Groups['day'].Value.PadLeft(2, '0')
        $y = $match.Groups['year'].Value.PadLeft(2, '0')
        if ($y.Length -eq 4)
        {
            $y = $y.Substring(2, 2)
        }        
    }
    else
    {
        #Write-Output "Skipping $($f.Name)"
        continue
    }
    if (($y -eq '00') -or ($m -eq '00') -or ($d -eq '00'))
    {
        Write-Warning "Skipping $($f.Name)"
        continue
    }
    if (($y -eq '02') -and ($f.Name -like 'Episode 4*'))
    {
        $y = '03'
    }

    $folder = "20$y/$m"
    if (-not (Test-Path $folder -PathType Container))
    {
        mkdir $folder
    }
    Move-Item $f.FullName "20$y/$m/$($f.Name)"
}