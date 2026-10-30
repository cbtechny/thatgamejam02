param(
	[switch]$Capture,
	[string]$GodotPath
)

$ErrorActionPreference = 'Stop'
$windingRepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (-not $GodotPath) {
	$GodotPath = [System.IO.Path]::GetFullPath((Join-Path $windingRepoRoot '..\Godot_v4.7.2-stable_win64.exe'))
}
$windingValidationRoot = Join-Path $windingRepoRoot '.godot\editor_winding_validation'
$windingProjectRoot = Join-Path $windingValidationRoot 'project'
$windingUtf8 = [System.Text.UTF8Encoding]::new($false)
New-Item -ItemType Directory -Force -Path $windingProjectRoot, (Join-Path $windingProjectRoot 'addons'), (Join-Path $windingProjectRoot 'dev'), (Join-Path $windingValidationRoot 'Roaming'), (Join-Path $windingValidationRoot 'Local') | Out-Null

# Use an isolated source copy: validation saves and switches editor scene tabs.
foreach ($windingFolder in @('Art', 'Level')) {
	Copy-Item -LiteralPath (Join-Path $windingRepoRoot $windingFolder) -Destination $windingProjectRoot -Recurse -Force
}
foreach ($windingFolder in @('winder_test_1_time_scroll', 'movable_object_test', 'shader test')) {
	Copy-Item -LiteralPath (Join-Path $windingRepoRoot "dev\$windingFolder") -Destination (Join-Path $windingProjectRoot 'dev') -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $windingRepoRoot 'Main.tscn') -Destination $windingProjectRoot -Force
Copy-Item -LiteralPath (Join-Path $windingRepoRoot 'addons\winding_debug') -Destination (Join-Path $windingProjectRoot 'addons') -Recurse -Force
$windingTestAddon = Join-Path $windingProjectRoot 'addons\winding_editor_validation'
New-Item -ItemType Directory -Force -Path $windingTestAddon | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor_validation.gd') -Destination $windingTestAddon -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor_validation.cfg') -Destination (Join-Path $windingTestAddon 'plugin.cfg') -Force

$windingProjectConfig = @'
config_version=5
[application]
config/name="Winding Editor Validation"
run/main_scene="res://Main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[rendering]
renderer/rendering_method="gl_compatibility"
'@
$windingProjectFile = Join-Path $windingProjectRoot 'project.godot'
[System.IO.File]::WriteAllText($windingProjectFile, $windingProjectConfig, $windingUtf8)
$windingEnvironment = @{ APPDATA = (Join-Path $windingValidationRoot 'Roaming'); LOCALAPPDATA = (Join-Path $windingValidationRoot 'Local') }
$windingImportLog = Join-Path $windingValidationRoot 'import.log'
$windingImport = Start-Process -FilePath $GodotPath -ArgumentList @('--headless', '--path', $windingProjectRoot, '--editor', '--quit', '--log-file', $windingImportLog) -Environment $windingEnvironment -WindowStyle Hidden -PassThru -Wait
if ($windingImport.ExitCode -ne 0 -or (Select-String -LiteralPath $windingImportLog -Pattern 'ERROR:|SCRIPT ERROR:')) {
	Get-Content -LiteralPath $windingImportLog
	exit 1
}
$windingProjectConfig += @'

[editor_plugins]
enabled=PackedStringArray("res://addons/winding_debug/plugin.cfg", "res://addons/winding_editor_validation/plugin.cfg")
'@
[System.IO.File]::WriteAllText($windingProjectFile, $windingProjectConfig, $windingUtf8)
$windingEditorLayout = Join-Path $windingProjectRoot '.godot\editor\editor_layout.cfg'
# Prevent old scene tabs from reopening asynchronously during the test run.
if (Test-Path -LiteralPath $windingEditorLayout) {
	[System.IO.File]::WriteAllText($windingEditorLayout, "[EditorNode]`nopen_scenes=PackedStringArray()`ncurrent_scene=`"`"`n", $windingUtf8)
}
$windingLog = Join-Path $windingValidationRoot 'validation.log'
$windingArguments = @('--path', $windingProjectRoot, '--editor', '--single-window', '--log-file', $windingLog)
if ($Capture) {
	$windingArguments += @('--windowed', '--resolution', '1920x1080', '--audio-driver', 'Dummy')
} else {
	$windingArguments += '--headless'
}
$windingValidation = Start-Process -FilePath $GodotPath -ArgumentList $windingArguments -Environment $windingEnvironment -WindowStyle Hidden -PassThru
if (-not $windingValidation.WaitForExit(55000)) {
	Stop-Process -Id $windingValidation.Id
	Get-Content -LiteralPath $windingLog -ErrorAction SilentlyContinue
	throw 'Editor winding validation did not finish within 55 seconds.'
}
Get-Content -LiteralPath $windingLog
if ($windingValidation.ExitCode -ne 0 -or (Select-String -LiteralPath $windingLog -Pattern 'ERROR:|SCRIPT ERROR:')) {
	exit 1
}
exit 0
