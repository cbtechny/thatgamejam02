param(
    [string]$GodotPath,
    [string]$TemplatesDirectory,
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $repo
if (-not $GodotPath) {
    $settings = Get-Content -Raw -LiteralPath '.vscode\settings.json' | ConvertFrom-Json
    $GodotPath = $settings.'godotTools.editorPath.godot4'
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw 'Pass -GodotPath with the Godot 4.7.2 console executable.' }
if ($GodotPath.EndsWith('_win64.exe')) {
    $console = $GodotPath.Replace('_win64.exe', '_win64_console.exe')
    if (Test-Path -LiteralPath $console) { $GodotPath = $console }
}
$version = (& $GodotPath --version | Out-String).Trim()
if (-not $version.StartsWith('4.7.2.stable.')) { throw "Expected Godot 4.7.2 stable; found $version" }

$originalAppData = $env:APPDATA
$originalLocalAppData = $env:LOCALAPPDATA
try {
    if (-not $TemplatesDirectory) {
        $TemplatesDirectory = Join-Path $originalAppData 'Godot\export_templates\4.7.2.stable'
        if (-not (Test-Path -LiteralPath (Join-Path $TemplatesDirectory 'windows_release_x86_64.exe'))) {
            $localTemplates = Join-Path $repo '.godot\release-tools'
            if (Test-Path -LiteralPath (Join-Path $localTemplates 'windows_release_x86_64.exe')) { $TemplatesDirectory = $localTemplates }
        }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $TemplatesDirectory 'windows_release_x86_64.exe'))) {
        throw 'Install matching Godot 4.7.2 export templates, or pass -TemplatesDirectory containing windows_release_x86_64.exe.'
    }
    $runtime = Join-Path $repo '.godot\release-runtime'
    $env:APPDATA = Join-Path $runtime 'Roaming'
    $env:LOCALAPPDATA = Join-Path $runtime 'Local'
    $templates = Join-Path $env:APPDATA 'Godot\export_templates\4.7.2.stable'
    $logs = Join-Path $repo '.godot\release-logs'
    $output = Join-Path $repo 'builds\windows'
    New-Item -ItemType Directory -Force -Path $templates,$env:LOCALAPPDATA,$logs,$output | Out-Null
    [IO.File]::WriteAllText((Join-Path $repo 'builds\.gdignore'), '')
    foreach ($name in @('windows_release_x86_64.exe','windows_debug_x86_64.exe','version.txt')) {
        $source = Join-Path $TemplatesDirectory $name
        $destination = Join-Path $templates $name
        if ((Test-Path -LiteralPath $source) -and ([IO.Path]::GetFullPath($source) -ne $destination)) {
            Copy-Item -LiteralPath $source -Destination $destination
        }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $templates 'version.txt'))) {
        [IO.File]::WriteAllText((Join-Path $templates 'version.txt'), "4.7.2.stable`n")
    }
    function Invoke-Godot([string[]]$EngineArguments, [string]$LogName, [int]$TimeoutSeconds = 55) {
        $log = Join-Path $logs ($LogName + '.log')
        $launch = New-Object Diagnostics.ProcessStartInfo
        $launch.FileName = $GodotPath
        $launch.WorkingDirectory = $repo
        $launch.UseShellExecute = $false
        $launch.CreateNoWindow = $true
        $launch.RedirectStandardOutput = $true
        $launch.RedirectStandardError = $true
        $launch.Arguments = ((@('--log-file',$log) + $EngineArguments) | ForEach-Object {
            if ($_.Contains('"')) { throw 'Unexpected quote in a build argument.' }
            '"' + $_ + '"'
        }) -join ' '
        $process = [Diagnostics.Process]::Start($launch)
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
        while (-not $process.WaitForExit(1000)) {
            if ([DateTime]::UtcNow -ge $deadline) {
                $process.Kill()
                throw "Godot timed out: $LogName"
            }
        }
        [IO.File]::WriteAllText((Join-Path $logs ($LogName + '.stdout.log')), $stdout.Result)
        [IO.File]::WriteAllText((Join-Path $logs ($LogName + '.stderr.log')), $stderr.Result)
        Write-Output ($stdout.Result.Trim())
        if ($process.ExitCode -ne 0) { throw "Godot failed: $LogName ($($process.ExitCode))" }
        # Root certificate access can be denied by the Codex sandbox. It does not
        # affect this offline game. Every other runtime/export error is fatal.
        $unexpected = Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR:' |
            Where-Object { $_.Line -notmatch 'Failed to read the root certificate store|resources still in use at exit' }
        if ($unexpected) { throw "Godot reported errors in $log" }
    }
    Invoke-Godot -EngineArguments @('--headless','--path',$repo,'--editor','--quit') -LogName 'import'
    if (-not $SkipTests) {
        foreach ($test in @(
            'tests/level_1_polish/run_level_1_polish.gd',
            'tests/level_2_ocean/run_ocean_tests.gd',
            'tests/level_3_ocean/run_level3_tests.gd',
            'tests/campaign/run_campaign_tests.gd',
            'tests/campaign/run_level1_input_tests.gd',
            'tests/campaign/run_level1_restart.gd',
            'tests/campaign/run_level1_presentation.gd',
            'tests/campaign/run_fullscreen_menus.gd',
            'tests/campaign/run_fullscreen_scale.gd',
            'tests/campaign/run_background_ornaments.gd',
            'tests/campaign/run_ocean_ornaments.gd',
            'tests/campaign/run_release_tests.gd',
            'tests/campaign/run_ocean_fragments.gd',
            'tests/campaign/run_ocean_space_input.gd',
            'tests/campaign/run_keycaps.gd',
            'tests/campaign/run_restart_cues.gd',
            'tests/campaign/run_playthrough.gd'
        )) {
            # The timed four/five-shot route plus both retries outlasts the old
            # 55-second limit. Keep that bound for the smaller regressions.
            $timeout = if ($test -eq 'tests/campaign/run_playthrough.gd') { 120 } else { 55 }
            Invoke-Godot -EngineArguments @('--headless','--path',$repo,'--script',('res://' + $test)) -LogName ([IO.Path]::GetFileNameWithoutExtension($test)) -TimeoutSeconds $timeout
        }
    }
    Invoke-Godot -EngineArguments @('--headless','--path',$repo,'--export-release','Windows Desktop') -LogName 'export'
    if (-not $SkipTests) {
        # A PCK launched from the project directory can silently use missing
        # resources from local source. Check all campaign scenes in isolation.
        $packedCheck = Join-Path $repo '.godot\release-packed-check'
        New-Item -ItemType Directory -Force -Path $packedCheck | Out-Null
        Invoke-Godot -EngineArguments @('--headless','--path',$packedCheck,'--main-pack',(Join-Path $output 'ClocksInOrange.pck'),'--script',(Join-Path $repo 'tests\campaign\run_release_tests.gd')) -LogName 'packed-release'
    }
    Invoke-Godot -EngineArguments @('--headless','--path',$repo,'--script','res://dev/release/write_notices.gd','--',(Join-Path $output 'Godot-NOTICES.txt')) -LogName 'notices'
    Copy-Item -LiteralPath 'docs\release\PLAYER-README.txt' -Destination (Join-Path $output 'README.txt')
    Copy-Item -LiteralPath 'docs\release\CREDITS.txt' -Destination $output

    $sourceLines = foreach ($relative in (git -c core.quotepath=false ls-files --cached --others --exclude-standard | Sort-Object -Unique)) {
        $path = Join-Path $repo $relative
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            '{0}  {1}' -f (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant(), $relative.Replace('\','/')
        }
    }
    $sourceManifest = Join-Path $repo 'builds\source-files.sha256'
    [IO.File]::WriteAllLines($sourceManifest, [string[]]$sourceLines, (New-Object Text.UTF8Encoding $false))
    $base = (git rev-parse HEAD).Trim()
    $dirty = [bool](git status --porcelain)
    $sourceHash = (Get-FileHash -LiteralPath $sourceManifest -Algorithm SHA256).Hash.ToLowerInvariant()
    $themeHash = (Get-FileHash -LiteralPath 'dev\winder_test_1_time_scroll\assets\thatgamejam_theme_mp3_medium_audio_track.mp3' -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest = [ordered]@{
        candidate = 'Windows x86_64'; engine = $version; base_commit = $base
        uncommitted_changes = $dirty; source_manifest_sha256 = $sourceHash
        theme_recording_sha256 = $themeHash; tests_skipped = [bool]$SkipTests
        human_playtest = 'Pending'; listening_pass = 'Pending'; uploaded = $false
    }
    $manifest | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $output 'BUILD.json')
    $zip = Join-Path $repo 'builds\ClocksInOrange-Windows-candidate.zip'
    $files = @('ClocksInOrange.exe','ClocksInOrange.pck','README.txt','CREDITS.txt','Godot-NOTICES.txt','BUILD.json') |
        ForEach-Object { Join-Path $output $_ }
    Compress-Archive -LiteralPath $files -DestinationPath $zip -Force
    Get-FileHash -LiteralPath $zip -Algorithm SHA256 | Format-List
    Write-Output "Candidate: $zip"
    Write-Output 'Human playtesting, listening and itch upload/download verification remain separate acceptance steps.'
} finally {
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalAppData
}
