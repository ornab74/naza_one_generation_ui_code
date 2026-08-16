# LLM-CONTEXT:BEGIN
# FILE: tool/check_windows_litertlm.ps1
# ROLE: Owns check windows litertlm behavior within the developer-tooling subsystem.
# DOMAIN: developer-tooling
# SECURITY-INVARIANT: Preserve local-first privacy, bounded resource use, and explicit error handling.
# CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
# DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
# LLM-CONTEXT:END
param(
  [switch]$RequirePrepared,
  [switch]$RequireInjectedBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$markerPath = Join-Path $repoRoot '.dart_tool\naza_windows_litertlm_provenance.json'
$packageConfigPath = Join-Path $repoRoot '.dart_tool\package_config.json'
$localPackageDir = Join-Path $repoRoot '.dart_tool\naza_windows_litertlm_1_3_1'
$bundleRoot = Join-Path $repoRoot '.dart_tool\naza_windows_modern_bundle'
$releaseRoot = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$runtimeManifestTarget = Join-Path $releaseRoot 'naza_litertlm_runtime.json'

function Write-Check([string]$Name, [bool]$Ok, [string]$Detail) {
  $status = if ($Ok) { 'PASS' } else { 'FAIL' }
  $color = if ($Ok) { 'Green' } else { 'Red' }
  Write-Host ("[{0}] {1}: {2}" -f $status, $Name, $Detail) -ForegroundColor $color
  if (-not $Ok) { $script:Failed = $true }
}

function Test-RealBinary([string]$Path) {
  if (-not (Test-Path $Path)) { return $false }
  if ((Get-Item $Path).Length -lt 1024) { return $false }
  $firstLine = Get-Content $Path -TotalCount 1 -ErrorAction SilentlyContinue
  return $firstLine -ne 'version https://git-lfs.github.com/spec/v1'
}

$script:Failed = $false
Write-Host 'NAZA One modern Windows LiteRT-LM diagnostics'
Write-Host '---------------------------------------------'
Write-Host "Repository: $repoRoot"

$prepared = Test-Path $markerPath
Write-Check 'modern provenance marker' $prepared $(if ($prepared) { $markerPath } else { 'not prepared' })
if (-not $prepared) {
  Write-Host 'Run: powershell -ExecutionPolicy Bypass -File tool\prepare_windows_litertlm.ps1'
  if ($RequirePrepared) { exit 2 }
  exit 0
}

$marker = Get-Content $markerPath -Raw | ConvertFrom-Json
Write-Check 'manifest schema' ($marker.schema -eq 'naza-windows-litertlm-modern-v1') "schema=$($marker.schema)"
Write-Check 'modern Dart bridge' ($marker.flutter_gemma_litertlm -eq '1.3.1') "resolved=$($marker.flutter_gemma_litertlm), expected=1.3.1"
Write-Check 'Flutter native baseline' ($marker.flutter_native_baseline -eq '0.14.0') "published baseline=$($marker.flutter_native_baseline)"
Write-Check 'repaired LiteRT-LM source' ($marker.litert_lm_source_version -eq '0.16.0') "source=$($marker.litert_lm_source_version), expected=0.16.0"
Write-Check 'pinned fork commit' ($marker.litert_lm_ref -eq '6eeeb1d1195ee83f00e96da82ba1ed63e328063a') "ref=$($marker.litert_lm_ref)"
Write-Check 'pinned LiteRT dependency' ($marker.litert_ref -eq 'b0f6c12088df229f6342f1af164caa66ffa7b010') "ref=$($marker.litert_ref)"
Write-Check 'C API compatibility' ($marker.litert_c_api_version -eq '0.1.0') "C API=$($marker.litert_c_api_version)"
Write-Check 'Windows WebGPU upload repair' ($marker.windows_webgpu_weight_upload -eq 'serialized') "policy=$($marker.windows_webgpu_weight_upload)"
Write-Check 'Windows GPU compute' ($marker.windows_gpu_compute -eq 'enabled') "compute=$($marker.windows_gpu_compute)"
Write-Check 'Gemma 4 MTP cache mitigation' ($marker.windows_gpu_cache -eq ':nocache') "cache=$($marker.windows_gpu_cache)"

$enginePath = Join-Path $localPackageDir 'lib\src\litert_lm_engine.dart'
$hookPath = Join-Path $localPackageDir 'hook\build.dart'
Write-Check 'local modern bridge source' (Test-Path $enginePath) $enginePath
Write-Check 'modern Native Assets hook' (Test-Path $hookPath) $hookPath
if (Test-Path $enginePath) {
  $engine = Get-Content $enginePath -Raw
  Write-Check 'bridge no-cache patch' ($engine -match "cacheDir = ':nocache'") 'project-local Windows 1.3.1 bridge'
}
if (Test-Path $hookPath) {
  $hook = Get-Content $hookPath -Raw
  Write-Check 'modern 0.14 baseline declaration' ($hook -match "version:\s*'0\.14\.0'") 'published 1.3.1 bundle baseline'
  foreach ($library in @('LiteRtWebGpuAccelerator', 'LiteRtTopKWebGpuSampler', 'webgpu_dawn', 'dxcompiler', 'dxil')) {
    Write-Check "Native Assets component $library" ($hook -match [regex]::Escape($library)) 'declared by bridge hook'
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
    Write-Check 'project-local modern bridge selected' ($actual -eq $expected) "actual=$actual"
  }
} else {
  Write-Check 'package_config' $false 'missing; run prepare script'
}

$requiredBundleDlls = @(
  'LiteRtLm.dll',
  'libLiteRt.dll',
  'LiteRt.dll',
  'libLiteRtWebGpuAccelerator.dll',
  'LiteRtWebGpuAccelerator.dll',
  'libLiteRtTopKWebGpuSampler.dll',
  'LiteRtTopKWebGpuSampler.dll',
  'libwebgpu_dawn.dll',
  'webgpu_dawn.dll'
)
foreach ($name in $requiredBundleDlls) {
  $path = Join-Path $bundleRoot $name
  Write-Check "modern bundle $name" (Test-RealBinary $path) $path
  if (Test-Path $path -and $marker.dll_sha256.PSObject.Properties.Name -contains $name) {
    $actualHash = (Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = [string]$marker.dll_sha256.$name
    Write-Check "SHA256 $name" ($actualHash -eq $expectedHash.ToLowerInvariant()) $actualHash
  }
}

if ($RequireInjectedBuild) {
  Write-Check 'injected runtime manifest' (Test-Path $runtimeManifestTarget) $runtimeManifestTarget
  foreach ($property in $marker.dll_sha256.PSObject.Properties) {
    $name = $property.Name
    $target = Join-Path $releaseRoot $name
    $exists = Test-RealBinary $target
    Write-Check "app bundle $name" $exists $target
    if ($exists) {
      $actualHash = (Get-FileHash $target -Algorithm SHA256).Hash.ToLowerInvariant()
      $expectedHash = ([string]$property.Value).ToLowerInvariant()
      Write-Check "app SHA256 $name" ($actualHash -eq $expectedHash) $actualHash
    }
  }
}

Write-Host ''
Write-Host 'GPU interpretation:'
Write-Host '  * PASS proves NAZA was prepared against the repaired modern LiteRT-LM source bundle.'
Write-Host '  * It proves the Windows package uses flutter_gemma_litertlm 1.3.1, not the old 1.0.2 bridge.'
Write-Host '  * It does NOT prove a physical NVIDIA GPU executed inference on a GitHub-hosted runner.'
Write-Host '  * On an RTX machine launch with -StrictGpu and require NAZA telemetry to report actual GPU active.'
Write-Host '  * The repair serializes initialization weight upload only; D3D12/WebGPU inference remains enabled.'

if ($script:Failed) { exit 1 }
Write-Host ''
Write-Host 'Modern Windows LiteRT-LM diagnostics passed.' -ForegroundColor Green
