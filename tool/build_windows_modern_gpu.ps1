# LLM-CONTEXT:BEGIN
# FILE: tool/build_windows_modern_gpu.ps1
# ROLE: Owns build windows modern gpu behavior within the developer-tooling subsystem.
# DOMAIN: developer-tooling
# SECURITY-INVARIANT: Preserve local-first privacy, bounded resource use, and explicit error handling.
# CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
# DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
# LLM-CONTEXT:END
[CmdletBinding()]
param(
  [switch]$SkipNativeBuild,
  [switch]$Launch,
  [switch]$StrictGpu,
  [string]$LiteRtLmRef = '6eeeb1d1195ee83f00e96da82ba1ed63e328063a'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
if (-not $isWindowsHost) { throw 'This script must run on Windows.' }

# Windows PowerShell 5 does not define the automatic $IsWindows variable that
# PowerShell 7 does. Define it for child scripts so the same command works in
# either shell without requiring a second PowerShell installation.
if (-not (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue)) {
  Set-Variable -Name IsWindows -Value $true -Scope Global
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$prepare = Join-Path $PSScriptRoot 'prepare_windows_litertlm.ps1'
$bundleRoot = Join-Path $repoRoot '.dart_tool\naza_windows_modern_bundle'
$markerPath = Join-Path $repoRoot '.dart_tool\naza_windows_litertlm_provenance.json'
$releaseRoot = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$appExe = Join-Path $releaseRoot 'naza_one.exe'

Write-Host '=== NAZA One modern Windows GPU build ===' -ForegroundColor Green
$prepareParams = @{ LiteRtLmRef = $LiteRtLmRef }
if ($SkipNativeBuild) { $prepareParams.SkipNativeBuild = $true }
& $prepare @prepareParams

if ($SkipNativeBuild -and -not (Test-Path $bundleRoot)) {
  throw 'SkipNativeBuild was requested but no previously-built modern bundle exists.'
}
if (-not (Test-Path $markerPath)) {
  throw 'Modern LiteRT-LM provenance manifest is missing.'
}

flutter build windows --release --no-pub
if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed with exit code $LASTEXITCODE" }
if (-not (Test-Path $releaseRoot)) { throw "Flutter Windows release directory is missing: $releaseRoot" }

$manifest = Get-Content $markerPath -Raw | ConvertFrom-Json
$expectedHashes = $manifest.dll_sha256
if (-not $expectedHashes) { throw 'Provenance manifest has no DLL hash table.' }

Write-Host 'Injecting repaired modern LiteRT-LM Windows runtime...' -ForegroundColor Cyan
Get-ChildItem $bundleRoot -Filter '*.dll' | ForEach-Object {
  Copy-Item $_.FullName (Join-Path $releaseRoot $_.Name) -Force
}

# Verify every runtime DLL copied into the app is byte-identical to the source-built bundle.
$failed = $false
foreach ($property in $expectedHashes.PSObject.Properties) {
  $name = $property.Name
  $expected = [string]$property.Value
  $target = Join-Path $releaseRoot $name
  if (-not (Test-Path $target)) {
    Write-Host "[FAIL] missing injected DLL: $name" -ForegroundColor Red
    $failed = $true
    continue
  }
  $actual = (Get-FileHash $target -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $expected.ToLowerInvariant()) {
    Write-Host "[FAIL] hash mismatch: $name" -ForegroundColor Red
    Write-Host "       expected=$expected"
    Write-Host "       actual  =$actual"
    $failed = $true
  } else {
    Write-Host "[PASS] $name $actual" -ForegroundColor Green
  }
}
if ($failed) { throw 'Injected modern LiteRT-LM runtime failed SHA-256 validation.' }

$runtimeManifestTarget = Join-Path $releaseRoot 'naza_litertlm_runtime.json'
Copy-Item $markerPath $runtimeManifestTarget -Force

Write-Host ''
Write-Host 'Windows build complete.' -ForegroundColor Green
Write-Host "  App: $appExe"
Write-Host "  Runtime manifest: $runtimeManifestTarget"
Write-Host "  LiteRT-LM source: $($manifest.litert_lm_source_version) @ $($manifest.litert_lm_ref)"
Write-Host "  LiteRT source: $($manifest.litert_ref)"
Write-Host "  GPU upload policy: $($manifest.windows_webgpu_weight_upload)"
Write-Host "  GPU compute: $($manifest.windows_gpu_compute)"
Write-Host "  Cache: $($manifest.windows_gpu_cache)"

if ($StrictGpu) {
  # NAZA already maps "only"/"required" to NazaModelBackendPreference.gpuOnly,
  # which rejects GPU initialization failure instead of entering the normal
  # GPU-first -> CPU fallback path. This is the definitive RTX validation mode.
  $env:NAZA_DESKTOP_GPU = 'only'
  $env:NAZA_DESKTOP_CPU = '0'
  $env:NAZA_GPU_STRICT = '1'
  Write-Host 'STRICT GPU MODE: NAZA GPU-only backend selected; CPU fallback is disabled.' -ForegroundColor Yellow
}

if ($Launch) {
  if (-not (Test-Path $appExe)) { throw "NAZA executable not found: $appExe" }
  Write-Host 'Launching NAZA One...' -ForegroundColor Cyan
  Push-Location $releaseRoot
  try {
    & $appExe
  } finally {
    Pop-Location
  }
} else {
  Write-Host ''
  Write-Host 'For your RTX test:' -ForegroundColor Cyan
  Write-Host '.\tool\build_windows_modern_gpu.ps1 -SkipNativeBuild -Launch -StrictGpu'
}
