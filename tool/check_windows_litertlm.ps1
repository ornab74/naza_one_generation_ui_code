param(
  [switch]$RequirePrepared
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$markerPath = Join-Path $repoRoot '.dart_tool\naza_windows_litertlm_patch.json'
$packageConfigPath = Join-Path $repoRoot '.dart_tool\package_config.json'
$localPackageDir = Join-Path $repoRoot '.dart_tool\naza_windows_litertlm'

function Write-Check([string]$Name, [bool]$Ok, [string]$Detail) {
  $status = if ($Ok) { 'PASS' } else { 'FAIL' }
  Write-Host ("[{0}] {1}: {2}" -f $status, $Name, $Detail)
  if (-not $Ok) { $script:Failed = $true }
}

$script:Failed = $false
Write-Host 'NAZA One Windows LiteRT-LM diagnostics'
Write-Host '---------------------------------------'
Write-Host "Repository: $repoRoot"

$prepared = Test-Path $markerPath
Write-Check 'compatibility marker' $prepared $(if ($prepared) { $markerPath } else { 'not prepared' })
if (-not $prepared) {
  Write-Host 'Run: powershell -ExecutionPolicy Bypass -File tool\prepare_windows_litertlm.ps1'
  if ($RequirePrepared) { exit 2 }
  exit 0
}

$marker = Get-Content $markerPath -Raw | ConvertFrom-Json
Write-Check 'Dart bridge' ($marker.flutter_gemma_litertlm -eq '1.0.2') "resolved=$($marker.flutter_gemma_litertlm), expected=1.0.2"
Write-Check 'native LiteRT-LM' ($marker.litert_lm_native -eq '0.13.1-a') "resolved=$($marker.litert_lm_native), expected=0.13.1-a"
Write-Check 'MlDrift weight cache' ($marker.windows_gpu_cache -eq ':nocache') "policy=$($marker.windows_gpu_cache), expected=:nocache"

$enginePath = Join-Path $localPackageDir 'lib\src\litert_lm_engine.dart'
$hookPath = Join-Path $localPackageDir 'hook\build.dart'
Write-Check 'local engine source' (Test-Path $enginePath) $enginePath
Write-Check 'native bundle hook' (Test-Path $hookPath) $hookPath

if (Test-Path $enginePath) {
  $engine = Get-Content $enginePath -Raw
  Write-Check 'engine no-cache patch' ($engine -match "cacheDir = ':nocache'") 'LiteRT-LM #2572 mitigation'
}
if (Test-Path $hookPath) {
  $hook = Get-Content $hookPath -Raw
  Write-Check '0.13.1-a bundle declaration' ($hook -match "version:\s*'0\.13\.1-a'") 'pre-v0.14 Windows runtime'
  foreach ($library in @('LiteRtWebGpuAccelerator', 'LiteRtTopKWebGpuSampler', 'dxcompiler', 'dxil')) {
    Write-Check "bundle component $library" ($hook -match [regex]::Escape($library)) 'declared in Windows native bundle'
  }
}

if (Test-Path $packageConfigPath) {
  $config = Get-Content $packageConfigPath -Raw | ConvertFrom-Json
  $entry = $config.packages | Where-Object { $_.name -eq 'flutter_gemma_litertlm' } | Select-Object -First 1
  Write-Check 'package_config entry' ($null -ne $entry) $(if ($entry) { $entry.rootUri } else { 'missing' })
  if ($entry) {
    $root = [Uri]$entry.rootUri
    if (-not $root.IsAbsoluteUri) {
      $configUri = [Uri](Resolve-Path $packageConfigPath).Path
      $root = [Uri]::new($configUri, $root)
    }
    $actual = [IO.Path]::GetFullPath($root.LocalPath).TrimEnd('\')
    $expected = [IO.Path]::GetFullPath($localPackageDir).TrimEnd('\')
    Write-Check 'isolated package selected' ($actual -eq $expected) "actual=$actual"
  }
} else {
  Write-Check 'package_config' $false 'missing; run prepare script'
}

Write-Host ''
Write-Host 'GPU interpretation:'
Write-Host '  * PASS here proves the Windows BUILD contains the intended D3D12/WebGPU compatibility runtime.'
Write-Host '  * It does NOT prove a physical NVIDIA GPU executed inference.'
Write-Host '  * On your RTX machine, verify Task Manager GPU Engine / dedicated GPU memory while generating,'
Write-Host '    and capture NAZA backend status so we can distinguish GPU from CPU fallback.'
Write-Host '  * Closest upstream validation: LiteRT-LM #2572, Windows + RTX 3080 + Gemma 4 E2B,'
Write-Host '    where v0.13.1 GPU works with cache_dir=:nocache.'

if ($script:Failed) { exit 1 }
Write-Host ''
Write-Host 'Windows LiteRT-LM compatibility diagnostics passed.'
