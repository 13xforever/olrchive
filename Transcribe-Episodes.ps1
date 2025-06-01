#!/usr/bin/pwsh

# Prerequisites: CUDA, cuDNN 8.x, ffmpeg
#   winget install Gyan.FFmpeg

# pip install git+https://github.com/openai/whisper.git
# pip install --upgrade --no-deps --force-reinstall git+https://github.com/openai/whisper.git
# set-alias whisper "$($env:localappdata)\packages\pythonsoftwarefoundation.python.3.10_qbz5n2kfra8p0\localcache\local-packages\python310\scripts\whisper.exe"

# pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
# pip3 install git+https://github.com/m-bain/whisperx.git
# pip3 install --upgrade git+https://github.com/m-bain/whisperx.git
#
# fix ctranslate2 version dependency: no packages for python 3.13+, use 3.12
#
# fix onnxruntime for diarization (see https://github.com/m-bain/whisperX/issues/540)
#   pip3 uninstall onnxruntime
#   pip3 install --force-reinstall onnxruntime-gpu
#
# if pyannote complains about missing cudnn_ops_infer64_8.dll, copy cuDNN 8 libs to torch\lib (they upgraded to cuDNN 9 in 2.5)

$useWhisperX = ($null -ne $env:hf_token) -and ($env:hf_token -ne '')
#$useWhisperX = $False

$model = 'large-v3-turbo'
if ($useWhisperX)
{
    $model = 'large-v3'
}
$conditionOnPreviousText = $False

#Clear-Host
$files = @(Get-ChildItem -Include *.mp3,*.mp4 -Recurse)
$num = -1
if ($host.Name -eq 'ConsoleHost')
{
    [Console]::TreatControlCAsInput = $True
    $defaultTitle = $host.UI.RawUI.WindowTitle
    $Host.UI.RawUI.FlushInputBuffer()
}
#$PSStyle.Progress.View = "Classic"
foreach ($f in $files)
{
    $num += 1
    $status = "File $($num + 1) out of $($files.Length): $($f.Name)"
    $percentPerFile = 100.0 / $files.Count
    $percent = $num * $percentPerFile
    # Write-Progress -Activity "Transcribing" -Status $status -PercentComplete ([int]$percent)
    $consoleTitle = "$($num + 1)/$($files.Length) ($($percent.ToString('0.000'))%): $($f.Name)"
    if ($host.Name -eq 'ConsoleHost')
    {
        $host.UI.RawUI.WindowTitle = $consoleTitle
    }
    
    Write-Progress -Id 1 -Activity 'Transcribing' -Status $status -PercentComplete ([int]$percent)
    $dir = Split-Path $f.FullName -Parent
    $name = Split-Path $f.Name -LeafBase
    $expectedSubs = Join-Path $dir "$name.vtt"
    if (Test-Path -LiteralPath $expectedSubs -PathType Leaf)
    {
        continue
    }

    $startTime = Get-Date -AsUTC
    $job = Start-Job -ScriptBlock {
        # whisper .\OLR_930_091822.mp3 --task transcribe --model large --device cuda
        $useWhisperX = $args[0]
        $mp3Path = $args[1]
        $model = $args[2]
        $dir = $args[3]
        $conditionOnPreviousText = $args[4]

        # --compression_ratio_threshold 2.0 --no_speech_threshold 0.5
        $initialPrompt = "Skie, DarkSakura, Loki, VOG Network, DJ Ranma S, Actdeft, Drew, Carameldansen"
        if ($useWhisperX)
        {
            # test: $model = 'large-v3-turbo'; $conditionOnPreviousText = $False; $initialPrompt = ''; $dir = '.\2025\05'; $mp3Path = '.\2025\05\OLR_1048_052525.mp3'
            #  --print_progress True (currently broken)
            whisperx "$mp3Path" --task transcribe --device cuda --model $model --language en --output_dir "$dir" --verbose False --initial_prompt $initialPrompt --condition_on_previous_text $conditionOnPreviousText --align_model WAV2VEC2_ASR_LARGE_LV60K_960H --diarize --hf_token "$($env:hf_token)" *>&1
        }
        else
        {
            whisper "$mp3Path" --task transcribe --device cuda --model $model --language en --output_dir "$dir" --verbose False --initial_prompt $initialPrompt  --condition_on_previous_text $conditionOnPreviousText 2>&1
        }

        #$PSStyle.Progress.View = "Minimal"
        # rename all file.mp3.txt to just file.txt
        @(Get-ChildItem -LiteralPath $dir -Include '*.mp3.*') | ForEach-Object { Rename-Item "$($_.FullName)" "$($_.Name.Replace('.mp3', '', $true, (Get-Culture 'en-US')))" }
        @(Get-ChildItem -LiteralPath $dir -Include '*.mp4.*') | ForEach-Object { Rename-Item "$($_.FullName)" "$($_.Name.Replace('.mp4', '', $true, (Get-Culture 'en-US')))" }
    } -ArgumentList $useWhisperX, "$($f.FullName)", "$model", "$dir", "$conditionOnPreviousText"

    $requestToAbort = $false
    $hadData = $false
    do
    {
        Start-Sleep -Seconds 1
        Write-Progress -Id 1 -Activity 'Transcribing' -Status $status -PercentComplete ([int]$percent)
        if ($job.HasMoreData)
        {
            $jobData = Receive-Job -Job $job -ErrorAction SilentlyContinue
            # whisper (writes in error stream)
            #   1%|          | 7548/740916 [00:09<14:19, 853.28frames/s]
            #  1%|█▋         | 2732/374130 [00:07<17:57, 344.60frames/s]

            # whisperx (writes in ?? stream)
            # Progress: 47.73%...
            $ts = (Get-Date -AsUTC) - $startTime
            if ($ts.TotalSeconds -gt 3599)
            {
                $realElapsed = $ts.ToString('hh\:mm\:ss')
            }
            else
            {
                $realElapsed = $ts.ToString('mm\:ss')
            }
            $m = [Regex]::Matches("$jobData", '\s*(?<percent>\d+)%.+?(?<frame>\d+)/(?<frames>\d+) \[(?<elapsed>(\d+:)?\d+:\d+)<(?<remaining>((\d+:)?\d+:\d+)|\?), (?<speed>((\d|[.,])+|\?))frame.+\]')
            $mX = [Regex]::Matches("$jobData", '\s*Progress: (?<percent>\d*\.\d*)%...')
            if ($m.Count -gt 0)
            {
                $jobPercent = $m[-1].Groups['percent'].Value
                $jobRem = $m[-1].Groups['remaining'].Value
                $elapsed = $m[-1].Groups['elapsed'].Value
                $frame = $m[-1].Groups['frame'].Value
                $frames = $m[-1].Groups['frames'].Value
                $speed = $m[-1].Groups['speed'].Value
                if ($jobRem -eq '?')
                {
                    $remainingSeconds = -1
                }
                else
                {
                    if ($jobRem.Length -lt 6)
                    {
                        $ts = [TimeSpan]"00:$jobRem"
                    }
                    else
                    {
                        $ts = [TimeSpan]$jobRem
                    }
                    $remainingSeconds = $ts.TotalSeconds
                }
                $hadData = $true
                Write-Progress -Id 2 -Activity '  Progress' -ParentId 1 -Status "Elapsed: $elapsed ($realElapsed), Frame: $frame/$frames, $speed fps, Remaining: $jobRem" -PercentComplete $jobPercent -SecondsRemaining $remainingSeconds
            }
            elseif ($mX.Count -gt 0)
            {
                $jobPercent = [double]$mX[-1].Groups['percent'].Value
                $elapsedMs = $ts.TotalMilliseconds / $jobPercent * 100.0
                $remainingSeconds = [int]($elapsedMs * (100 - $jobPercent) / 100)
                Write-Progress -Id 2 -Activity '  Progress' -ParentId 1 -Status "Elapsed: $realElapsed" -PercentComplete $jobPercent -SecondsRemaining $remainingSeconds
            }
            elseif (-not $hadData)
            {
                if ($useWhisperX)
                {
                    Write-Progress -Id 2 -Activity '  Progress' -ParentId 1 -Status 'Transcribing…' -PercentComplete 0 -SecondsRemaining -1
                }
                else
                {
                    Write-Progress -Id 2 -Activity '  Progress' -ParentId 1 -Status 'Preparing model' -PercentComplete 0 -SecondsRemaining -1
                }
            }
            else
            {
                if (-not [string]::IsNullOrWhiteSpace("$jobData"))
                {
                    Write-Warning $jobData
                }
                Write-Progress -Id 2 -Activity '  Progress' -ParentId 1 -Status "Elapsed: $elapsed ($realElapsed), Frame: $frame/$frames, $speed fps, Remaining: $jobRem" -PercentComplete $jobPercent -SecondsRemaining $remainingSeconds
                $fileProgress = $percentPerFile * $frame / $frames
                if ($host.Name -eq 'ConsoleHost')
                {
                    $newConsoleTitle = "$($num + 1)/$($files.Length) ($(($percent+$fileProgress).ToString('0.000'))%): $($f.Name)"
                    if ($newConsoleTitle -ne $consoleTitle)
                    {
                        $consoleTitle = $newConsoleTitle
                        $host.UI.RawUI.WindowTitle = $consoleTitle
                    }
                }
            }
        }
        if (($host.Name -eq 'ConsoleHost') -and $Host.UI.RawUI.KeyAvailable -and ($Key = $Host.UI.RawUI.ReadKey('AllowCtrlC,NoEcho,IncludeKeyUp')))
        {
            if ([Int]$Key.Character -eq 3)
            {
                if ($requestToAbort)
                {
                    Stop-Job -Job $job
                }
                else
                {
                    Write-Host 'Will stop when the current task is finished. Press Ctrl-C again to abort immediately.'
                    $requestToAbort = $true
                }
            }
            $Host.UI.RawUI.FlushInputBuffer()
        }
    } while ($job.State -eq 'Running')
    Write-Progress -Activity '  Progress' -Completed
    Remove-Job $job

    if ($requestToAbort)
    {
        break
    }
}
Write-Progress -Activity 'Transcribing' -Completed
if ($host.Name -eq 'ConsoleHost')
{
    $host.UI.RawUI.WindowTitle = $defaultTitle
    [Console]::TreatControlCAsInput = $False
}