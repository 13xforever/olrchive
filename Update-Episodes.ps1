#/usr/bin/pwsh

$useArchive = $False

$rssUrl = 'http://orangeloungeradio.com/index.php?option=com_podcast&view=feed&format=raw'
$olrchiveUrl = 'https://api.olarchive.samurailink3.com'
$files = @{}
@(Get-ChildItem *.mp3 -Recurse) | ForEach-Object { $files[$_.Name] = $_.FullName }

function Get-Episode([string]$name, [string]$link)
{
    if ($files.ContainsKey($name))
    {
        continue
    }

    if ((Split-Path $name -Extension) -ine '.mp3')
    {
        Write-Host "Not an .mp3 extension, skipping $name"
        continue
    }

    Write-Host "Downloading new episode: $name..."
    Invoke-WebRequest -Uri $link -OutFile $name
}

$response = Invoke-WebRequest -Uri $rssUrl
$xml = [xml]$response.Content
foreach ($ep in $xml.rss.channel.item)
{
    $link = $ep.enclosure.url
    $name = Split-Path $link -Leaf
    Get-Episode $name $link
}

if ($useArchive)
{
    # olrchive
    $response = Invoke-WebRequest -Uri $olrchiveUrl
    $json = $response.Content | ConvertFrom-Json
    foreach ($ep in $json.episodes)
    {
        Get-Episode $ep.Name $ep.Link
    }
}