$ErrorActionPreference = 'Stop'

# NAZA One Windows LiteRT-LM compatibility preparation.
#
# Why this exists:
# - flutter_gemma_litertlm 1.2.0+ moved to LiteRT-LM v0.14+, where upstream
#   issue #2957 reports a Windows WebGPU/D3D12 engine_create regression.
# - flutter_gemma_litertlm 1.0.2 bundles LiteRT-LM 0.13.1-a.
# - upstream LiteRT-LM #2572 reproduces on Windows + RTX 3080 + Gemma 4 E2B
#   and confirms GPU works when the MlDrift disk weight cache is disabled
#   (cache_dir=':nocache').
#
# We DO NOT modify the global Pub cache. We download 1.0.2, copy it into this
# project's .dart_tool directory, patch that isolated copy, then resolve the
# Windows build against the local package. Linux/macOS/Android/iOS continue to
# use the modern package declared in pubspec.yaml.

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$compatVersion = '1.0.2'
$localPackageDir = Join-Path $repoRoot '.dart_tool\naza_windows_litertlm'
$overrideFile = Join-Path $repoRoot 'pubspec_overrides.yaml'
$packageConfig = Join-Path $repoRoot '.dart_tool\package_config.json'
$markerFile = Join-Path $repoRoot '.dart_tool\naza_windows_litertlm_patch.json'

Write-Host "Preparing Windows LiteRT-LM GPU compatibility package $compatVersion"

# Phase 1: resolve exact upstream compatibility package so we can copy it.
@"
dependency_overrides:
  flutter_gemma_litertlm: $compatVersion
"@ | Set-Content -Path $overrideFile -Encoding utf8

flutter pub get
if ($LASTEXITCODE -ne 0) { throw "Initial flutter pub get failed with exit code $LASTEXITCODE" }

if (-not (Test-Path $packageConfig)) {
  throw '.dart_tool/package_config.json was not generated.'
}

$config = Get-Content $packageConfig -Raw | ConvertFrom-Json
$entry = $config.packages | Where-Object { $_.name -eq 'flutter_gemma_litertlm' } | Select-Object -First 1
if (-not $entry) { throw 'flutter_gemma_litertlm was not found in package_config.json.' }

$rootUri = [Uri]$entry.rootUri
if (-not $rootUri.IsAbsoluteUri) {
  $configUri = [Uri](Resolve-Path $packageConfig).Path
  $rootUri = [Uri]::new($configUri, $rootUri)
}
$sourceDir = $rootUri.LocalPath
if (-not (Test-Path $sourceDir)) { throw "Resolved package directory does not exist: $sourceDir" }

$sourcePubspec = Join-Path $sourceDir 'pubspec.yaml'
$sourcePubspecText = Get-Content $sourcePubspec -Raw
if ($sourcePubspecText -notmatch '(?m)^version:\s*1\.0\.2\s*$') {
  throw "Expected flutter_gemma_litertlm $compatVersion, but resolved package metadata did not match."
}

Remove-Item -Path $localPackageDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $localPackageDir -Force | Out-Null
Copy-Item -Path (Join-Path $sourceDir '*') -Destination $localPackageDir -Recurse -Force

# Verify the compatibility package really carries the 0.13.1-a native bundle.
$hookPath = Join-Path $localPackageDir 'hook\build.dart'
$hookText = Get-Content $hookPath -Raw
if ($hookText -notmatch "version:\s*'0\.13\.1-a'") {
  throw 'Compatibility package does not contain the expected LiteRT-LM 0.13.1-a native bundle.'
}

# Patch only the project-local copy. The stock engine always points cacheDir at
# application support. For Windows GPU this can collide between Gemma 4 E2B's
# main model and MTP drafter (#2572). :nocache bypasses that mmap collision.
$enginePath = Join-Path $localPackageDir 'lib\src\litert_lm_engine.dart'
$engineText = Get-Content $enginePath -Raw
$needle = 'final cacheDir = (await getApplicationSupportDirectory()).path;'
$replacement = "final cacheDir = ':nocache'; // NAZA Windows GPU: LiteRT-LM #2572"
if (-not $engineText.Contains($needle)) {
  throw 'Could not find the expected LiteRT-LM cacheDir assignment; refusing an unsafe blind patch.'
}
$engineText = $engineText.Replace($needle, $replacement)
Set-Content -Path $enginePath -Value $engineText -Encoding utf8

# Phase 2: resolve against the patched project-local package.
$relativePackage = '.dart_tool/naza_windows_litertlm'
@"
dependency_overrides:
  flutter_gemma_litertlm:
    path: $relativePackage
"@ | Set-Content -Path $overrideFile -Encoding utf8

flutter pub get
if ($LASTEXITCODE -ne 0) { throw "Patched flutter pub get failed with exit code $LASTEXITCODE" }

# Resolve again and prove the app is actually compiling against our isolated copy.
$config = Get-Content $packageConfig -Raw | ConvertFrom-Json
$entry = $config.packages | Where-Object { $_.name -eq 'flutter_gemma_litertlm' } | Select-Object -First 1
if (-not $entry) { throw 'Patched flutter_gemma_litertlm package entry is missing.' }
$resolvedRoot = [Uri]$entry.rootUri
if (-not $resolvedRoot.IsAbsoluteUri) {
  $configUri = [Uri](Resolve-Path $packageConfig).Path
  $resolvedRoot = [Uri]::new($configUri, $resolvedRoot)
}
$resolvedPath = [IO.Path]::GetFullPath($resolvedRoot.LocalPath).TrimEnd('\')
$expectedPath = [IO.Path]::GetFullPath($localPackageDir).TrimEnd('\')
if ($resolvedPath -ne $expectedPath) {
  throw "Windows package resolution is not using the patched local copy. Resolved: $resolvedPath Expected: $expectedPath"
}

$patchedEngine = Get-Content $enginePath -Raw
if ($patchedEngine -notmatch "cacheDir = ':nocache'") {
  throw 'Windows LiteRT-LM no-cache GPU patch verification failed.'
}

$marker = [ordered]@{
  flutter_gemma_litertlm = $compatVersion
  litert_lm_native = '0.13.1-a'
  windows_gpu_cache = ':nocache'
  upstream_gpu_evidence = @('LiteRT-LM#2572', 'LiteRT-LM#2957')
  generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
}
$marker | ConvertTo-Json -Depth 4 | Set-Content -Path $markerFile -Encoding utf8

Write-Host 'Windows LiteRT-LM compatibility preparation complete.'
Write-Host "  Dart bridge: $compatVersion"
Write-Host '  Native runtime: LiteRT-LM 0.13.1-a'
Write-Host '  Windows GPU cache: :nocache'
Write-Host "  Local package: $localPackageDir"
