# Naza One

[![Build Naza One](https://github.com/ornab74/naza_one_generation_ui_code/actions/workflows/flutter-release.yml/badge.svg)](https://github.com/ornab74/naza_one_generation_ui_code/actions/workflows/flutter-release.yml)
[![Build Microsoft Store MSIX](https://github.com/ornab74/naza_one_generation_ui_code/actions/workflows/windows-store-msix.yml/badge.svg)](https://github.com/ornab74/naza_one_generation_ui_code/actions/workflows/windows-store-msix.yml)

**Naza One is a private, local-first Flutter AI workstation built around on-device Gemma + LiteRT-LM.** It combines chat, vision, scanner workflows, food intelligence, encrypted local memory, advanced recovery/security controls, model-integrity enforcement, and multi-source model distribution without requiring a cloud chat backend.

> **Microsoft Store:** https://apps.microsoft.com/detail/9nm382wsvsvn

![Naza One demo](./demo.png)

## What Naza One is

Naza One is designed around a simple idea: the assistant, its working context, its saved history, and its model should live as close to the user as practical.

The application runs model inference locally through `flutter_gemma` / LiteRT-LM, keeps user-created state in an encrypted SQLite-backed record store, verifies its model before use, and exposes specialized local workflows for chat, image understanding, road/safety scanning, food/fridge analysis, baking analysis, history, and memory.

There is **no developer-operated cloud chat backend**, no advertising SDK, no behavioral analytics SDK, no required user account, no microphone pipeline, and no voice-generation model pack. Network access is primarily used to obtain the local model when a verified copy is not already installed.

## Highlights

| Area | What is included |
| --- | --- |
| Local AI | Gemma 4 E2B LiteRT-LM inference on device |
| Chat | Streaming responses, continuation engine, vision attachments, history, local context |
| Smart Memory | Encrypted persistent memory plus embedded hybrid vector retrieval |
| Vision | User-selected image input with bounded preprocessing and local inference |
| Scanner | Evidence-bounded local road / safety / structured scanner workflows |
| Food | Fridge analysis, shelf scanning, bake analysis/simulation, encrypted food history |
| Security | Argon2id, AES-256-GCM, HMAC record identifiers, key hierarchy, rotation, tamper detection |
| Post-quantum recovery | Hybrid ML-KEM-1024 + X25519, ML-DSA-87, HKDF-SHA-512, AES-256-GCM |
| Model trust | Immutable model revision, SHA-256 pinning, per-part GitHub hashes, encrypted model attestation |
| Distribution | Hugging Face, GitHub Release parts, IPFS/Pinata mirror topology, resumable multi-plane transport module |
| Runtime diagnostics | GPU/CPU backend preference, explicit fallback visibility, Windows GPU diagnostics |
| Platforms | Android, Linux, Windows, Microsoft Store MSIX, macOS, iOS; Web UI build is experimental |
| CI | One main cross-platform build workflow plus one dedicated Microsoft Store workflow |

---

# Architecture

The current application entrypoint launches a verified-model bootstrap before mounting the main app shell:

```text
lib/main.dart
    |
    v
NazaModelBootstrap
    |
    +-- verify an existing managed model
    |
    +-- install a verified model when needed
    |     +-- pinned Hugging Face full artifact
    |     `-- pinned GitHub Release parts fallback
    |
    v
lib/app.dart
    |
    +-- local Gemma / LiteRT-LM runtime
    +-- chat + continuation system
    +-- image / vision input
    +-- road / safety scanner workflows
    +-- food / fridge / bake workflows
    +-- encrypted vault + history
    +-- local memory
    +-- runtime settings / diagnostics
    `-- recovery / security controls
```

The repository also contains newer modular subsystems under `lib/chat/`, `lib/memory/`, `lib/model/`, `lib/onboarding/`, `lib/settings/`, and `lib/security/`. These split major capabilities out of the large application shell and are independently regression tested.

## Runtime stack

- **Flutter 3.44.4** in CI
- **Dart SDK ^3.12.0**
- `flutter_gemma 1.5.2`
- `flutter_gemma_litertlm 1.3.1` as the normal dependency line
- `sqlite3` for the local encrypted-record container
- `cryptography` + `crypto` for symmetric cryptography, hashing, and derivation helpers
- `pqcrypto` for post-quantum recovery primitives
- `flutter_secure_storage` for platform-backed secure credential storage when enabled
- `image_picker` / `file_selector` for explicit user-selected image/file access

---

# Local model and inference

Naza One currently targets:

```text
gemma-4-E2B-it.litertlm
```

Canonical immutable Hugging Face revision:

```text
7fa1d78473894f7e736a21d920c3aa80f950c0db
```

Pinned final model SHA-256:

```text
ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42
```

Expected full size:

```text
2,583,085,056 bytes  (~2.41 GiB)
```

The model is public model data, so Naza One protects it for **integrity**, not confidentiality.

## First-install model bootstrap

`lib/model_bootstrap.dart` is the shipping first-install path.

`Automatic` currently behaves as:

1. check the managed verified-model cache;
2. try the revision-pinned Hugging Face full artifact;
3. if the Hugging Face source is unavailable, fall back to the GitHub `v1` release;
4. verify downloaded bytes before promotion;
5. atomically move only a verified artifact into the managed model location;
6. launch the main app.

The GitHub fallback is split into three strictly ordered parts. Every part is checked for exact size and SHA-256 before it is joined, and the complete joined model is checked again against the final application trust pin.

| Part | Bytes | SHA-256 |
| --- | ---: | --- |
| `part00.bin` | 861,028,352 | `b4ba4432650a1d767736b4139d9d94ab0ebb2e084a9c1fcca3824e691b4cb995` |
| `part01.bin` | 861,028,352 | `5f27ca28d693292298ce9bff48c641458af2994466cc1809576380b947861bc8` |
| `part02.bin` | 861,028,352 | `00e9d3b99151f41afe9cbc2e99cd3d684b62d67238859285ec89d1cf5a94c2f3` |

GitHub release:

https://github.com/ornab74/naza_one_generation_ui_code/releases/tag/v1

## Local model override

Desktop builds can use a local model explicitly:

```bash
export NAZA_MODEL_PATH=/absolute/path/to/gemma-4-E2B-it.litertlm
```

A local file is not trusted merely because it exists. The application trust path still requires the pinned model identity.

---

# Advanced multi-plane model distribution

The repository includes a second, more aggressive transport layer in:

```text
lib/model/model_distribution_manifest.dart
lib/model/multiplane_model_downloader.dart
lib/model/runtime_mirror_catalog.dart
mirrors.md
```

This subsystem is designed to provide torrent-like redundancy over ordinary HTTPS sources without requiring a BitTorrent client or holding giant buffers in RAM.

## Multi-plane transport design

`NazaMultiplaneModelDownloader` provides:

- 4 MiB logical chunks by default;
- adaptive transfer concurrency from 3 to 8 workers;
- HTTP range requests against both full-object and part-relative sources;
- persistent `HttpClient` instances per origin;
- bounded connections per host;
- provider scoring based on trust weight, EWMA throughput, success/failure history, in-flight pressure, and backoff state;
- automatic rerouting when a provider fails;
- bounded retries;
- out-of-order chunk arrival into a disk spool;
- contiguous-prefix assembly into a staging model file;
- a resumable v2 download journal;
- restart recovery for complete uncommitted spool chunks;
- final whole-model SHA-256 verification before promotion;
- progress snapshots with active stream count, throughput, completed chunks, and fastest observed provider.

The downloader deliberately uses disk-backed chunk files instead of multi-gigabyte RAM buffers. It also avoids unsafe random-write reopen behavior by advancing only the verified contiguous prefix into the staging file.

### Current transport layers

The distribution manifest describes:

- immutable Hugging Face full-object source;
- GitHub Release part replicas;
- Pinata IPFS gateways;
- `ipfs.io` public gateway URLs;
- `*.ipfs.inbrowser.link` gateway URLs;
- direct DigitalOcean IPFS peer IDs and TCP/QUIC multiaddrs as **topology hints only**.

Raw libp2p/Bitswap peers are not treated as fake HTTP URLs. Native direct-Bitswap transport can be added separately without weakening the HTTPS model trust boundary.

## Runtime mirror catalog

[`mirrors.md`](mirrors.md) is both human documentation and a machine-readable optional mirror catalog.

The catalog pins:

- model filename;
- immutable revision;
- total model size;
- final SHA-256;
- part indexes;
- part sizes;
- per-part SHA-256 values;
- IPFS CIDs;
- allowed mirror URLs.

`runtime_mirror_catalog.dart` validates a downloaded catalog against the identity compiled into the app before accepting transport additions. Unsafe or stale catalogs fall back to built-in topology rather than redefining model identity.

The current catalog permits HTTPS transports from the approved GitHub, Hugging Face, Pinata, `ipfs.io`, and browser-IPFS host families and rejects malformed credentials/fragments, non-HTTPS schemes, localhost-style destinations, and obvious literal private/link-local/loopback addresses.

**Important implementation detail:** the current `lib/main.dart` entrypoint launches through `NazaModelBootstrap`, whose first-install path is the verified Hugging Face → GitHub fallback described above. The multi-plane engine is present as a reusable advanced distribution subsystem and is not the authoritative first-install bootstrap unless explicitly wired into that launch path.

That distinction is intentional in this README so the documentation reflects the current executable path rather than only the available modules.

---

# Chat system

Naza One is built for long-form local generation rather than a single blocking completion box.

The chat/runtime code includes:

- streaming local generation;
- automatic continuation when a response appears to stop at a token boundary;
- continuation seam repair and overlap removal;
- bounded continuation passes;
- warm-session continuation where practical;
- context-window recovery paths;
- user-selected image attachment support;
- prompt-injection-resistant handling of retrieved memory and image evidence;
- explicit generation and initialization timeouts;
- history persistence;
- conversation continuation after reopening history.

## Reader-aware scrolling

`lib/chat/scroll_follow_controller.dart` implements streaming auto-follow that yields when the user deliberately scrolls upward. Streaming output no longer has to fight the reader for scroll position; returning to the tail can re-arm follow behavior.

## Chat history

The modular chat layer includes:

- searchable conversation history;
- grouped history entries;
- pinning;
- rename/delete actions;
- model-generated titles with bounded fallback titles;
- encrypted conversation metadata separate from transcript data.

Relevant files:

```text
lib/chat/advanced_chat_coordinator.dart
lib/chat/history_drawer.dart
lib/chat/history_metadata_repository.dart
lib/chat/scroll_follow_controller.dart
```

---

# Smart local memory

Naza One contains a fully local embedded retrieval layer designed to avoid sending personal memory to a vector-database service.

## Embedded vector store

`lib/memory/embedded_vector_store.dart` implements a dependency-free hybrid ANN retrieval engine.

Default geometry:

```text
128 vector dimensions
8 LSH tables
13 bits per LSH signature
2,400 record bound
96 first-stage candidates
```

Search is a multi-stage pipeline:

1. deterministic LSH fan-out finds approximate cosine candidates;
2. one-bit neighboring buckets improve recall;
3. lexical inverted postings add keyword candidates;
4. int8 vectors provide a cheap first-stage similarity estimate;
5. exact cosine similarity reranks candidates;
6. lexical relevance, salience, recency, reinforcement, confidence, thread affinity, and access signals are blended;
7. maximal marginal relevance (MMR) reduces near-duplicate memory results.

The store supports tenants, class names, typed memory kinds, metadata filters, deterministic snapshots, exact content deduplication, reinforcement, pruning, and bounded retrieval.

## Encrypted memory service

`lib/memory/local_memory_service.dart` layers policy and durable encrypted persistence over the embedded index.

Important properties:

- memory is local-first;
- the encrypted SQLite vault is the durable source of truth;
- ANN indexes are rebuildable acceleration structures;
- memory can be enabled/disabled persistently;
- user and assistant turns are locally extracted into bounded memory candidates;
- low-salience content can be filtered before storage;
- retrieval can be scoped by thread, tenant, class, or memory kind;
- prompt context labels recalled text as historical evidence rather than trusted instructions;
- memory can be flushed, cleared, rebuilt, and pruned locally.

This design treats recalled memory as potentially stale or wrong evidence—not as a hidden control channel for the model.

---

# First-run onboarding

The modular onboarding system lives in:

```text
lib/onboarding/first_run_onboarding.dart
lib/onboarding/onboarding_state.dart
```

It provides model-install guidance, first-run help, verified-model readiness state, and an encrypted/versioned onboarding state path. The goal is to get a new installation from empty vault → verified model → usable chat without making model setup look like a developer-only workflow.

---

# Vision and image handling

Naza One can accept an image selected explicitly by the user and process it with the local Gemma runtime.

Current application bounds include:

- one image per vision request;
- maximum normalized dimension of 1280 pixels;
- bounded source image size;
- bounded normalized payload size;
- reserved context budget for vision input;
- local normalization before model use.

The application does not crawl a photo library. File/photo access comes from the user selecting an item through the operating-system picker or explicitly opening supported camera flows.

---

# Scanner workflows

Naza One contains structured local scanner logic intended for evidence-bounded decision support.

The scanner contract is designed to:

- separate observed evidence from inference;
- return bounded `Low`, `Medium`, or `High` risk/confidence classifications where required;
- keep safety scores directionally consistent;
- avoid inventing missing contaminants, hazards, locations, recalls, or physical sensor readings;
- keep deterministic diagnostic transforms separate from claims about real physical sensors;
- preserve explicit uncertainty when evidence is incomplete.

Scanner output is decision support, not a substitute for direct inspection, professional testing, medical care, emergency services, or other real-world verification when stakes are high.

---

# Food intelligence

The food subsystem is substantially larger than a simple image prompt.

Relevant modules include:

```text
lib/food/food_hub.dart
lib/food/models.dart
lib/food/photo_picker.dart
lib/food/prompts.dart
lib/food/repository.dart
lib/food/shelf_scanner.dart
lib/food/bake_simulation.dart
```

Features include:

- fridge-image analysis;
- structured food observations;
- shelf/product comparison workflows;
- bake-completion analysis;
- deterministic bake simulation helpers;
- prompt-injection-resistant structured JSON contracts;
- bounded visual evidence fields;
- encrypted food/fridge/bake history;
- retention and pagination logic;
- re-openable saved analyses.

Food analysis is advisory. Image appearance alone cannot prove microbiological safety, internal temperature, contamination status, or doneness.

---

# Vault and local data security

The current encrypted database format is documented in [`SECURITY.md`](SECURITY.md).

The vault uses a layered key hierarchy:

```text
boot password
    |
    v
Argon2id
    |
    v
KEK (key-encryption key)
    |
    v
wrapped random 256-bit VUK
    |
    v
versioned wrapped 256-bit DEKs
    |
    v
AES-256-GCM encrypted logical records
```

Default password-mode policy currently includes:

- minimum 12-character password;
- Argon2id;
- unique salt;
- 64 MiB memory cost;
- three iterations;
- one lane.

Logical record identifiers are HMAC-SHA-256-derived rather than stored as plaintext logical names.

## Password changes and key rotation

Password changes rewrap the VUK with a new password-derived KEK instead of rewriting every user record.

DEK rotation:

- creates a new random active data key;
- marks rotation pending;
- migrates records transactionally;
- resumes after interruption;
- verifies no record still references the old DEK before retirement.

## Passwordless process unlock option

The default behavior is to require the vault password on each fresh app process. A user can explicitly choose the alternate secure-storage mode, where a random unlock secret is kept in the platform secure credential store.

The app fails closed if that secure store is unavailable; it does not silently write an equivalent plaintext key to disk.

## SQLite boundary

Naza One uses **authenticated record encryption**, not full-page SQLite encryption.

An attacker who obtains the database may still infer things such as:

- that the file is SQLite;
- schema/format information;
- approximate record count;
- ciphertext sizes/patterns;
- key-version identifiers;
- update timing and filesystem metadata.

The design does not claim impossible secure deletion guarantees on flash storage, copy-on-write filesystems, swap, snapshots, or provider backups.

---

# Hardened security architecture

The repository also includes a defense-in-depth security layer beyond basic vault encryption.

See [`docs/SECURITY_HARDENING.md`](docs/SECURITY_HARDENING.md).

Implemented or actively modeled primitives include:

- security-state identities bound to explicit security epochs;
- single-purpose capability leases;
- one-shot privileged authorization paths;
- rollback detection;
- forward-evolving audit state;
- persistent audit chains/checkpoints;
- intent/provenance guards separating model suggestions from user authorization;
- key-guardian abstractions that return opaque handles rather than casually exporting root material;
- release/model trust identities;
- model-substitution detection;
- explicit policy/recovery/trust-root identity binding.

Relevant files include:

```text
lib/security/security_kernel.dart
lib/security/security_identity.dart
lib/security/hardened_security_runtime.dart
lib/security/hardened_vault_controller.dart
lib/security/authenticated_rollback_guard.dart
lib/security/persistent_audit.dart
lib/security/intent_guard.dart
lib/security/key_guardian.dart
lib/security/release_trust.dart
lib/security/pq_trust_policy.dart
```

The LLM is not treated as an authorization authority. Model output may propose an action; deterministic application policy is responsible for granting/consuming privilege.

## Physical compromise limits

No Flutter/Dart application can truthfully promise that plaintext actively being processed is invisible to a fully privileged live-memory attacker. Naza One therefore documents memory extraction, debugger/core-dump exposure, root/admin compromise, device theft, and hardware-backed key handling as explicit threat-model boundaries rather than claiming “RAM-proof” security.

---

# Hybrid post-quantum recovery

Post-quantum cryptography is deliberately kept out of the ordinary local password-unlock path. It is used where separately held recovery artifacts create a meaningful trust boundary.

The current v2 recovery profile uses:

- **ML-KEM-1024**;
- **X25519**;
- transcript-bound **HKDF-SHA-512** over both shared secrets;
- **AES-256-GCM** for encrypted recovery payloads;
- **ML-DSA-87** signatures for backup origin authorization;
- an Argon2id-protected private recovery key kit;
- authenticated manifests containing suite, identity, size, digest, record-count, and creation metadata.

Private recovery key-kit protection currently uses:

```text
Argon2id
96 MiB memory
4 iterations
32-byte salt
AES-256-GCM
```

The live vault stores public recovery enrollment state, not the recovery private key.

Creating a new v2 backup requires reopening the separate private key kit and authenticating it with the recovery password before the backup is signed.

Legacy version-1 ML-KEM-768/HKDF-SHA-256 recovery packages remain readable through an explicit compatibility path but are not selected for new enrollment.

**Keep the encrypted backup, private recovery key kit, and recovery password separated.** Losing required recovery material can make a backup unrecoverable; obtaining all of it can make the backup decryptable.

The implementation is designed around FIPS 203/204-aligned primitives but does **not** claim FIPS 140 module validation.

---

# Model attestation

After a model passes the expensive full-file integrity check, Naza One can retain an encrypted trust attestation for that unchanged artifact.

The attestation lets later launches avoid hashing a multi-gigabyte public model unnecessarily. If the artifact identity, file metadata, trust record, or expected digest changes, trust is invalidated and verification is required again.

A partial or digest-mismatched model is never promoted as trusted.

---

# GPU / CPU backend control

Desktop runtime policy supports three conceptual modes:

- **GPU first** — prefer GPU, permit CPU fallback;
- **GPU only** — reject CPU fallback;
- **CPU only** — favor compatibility.

Useful environment overrides:

```bash
# Force CPU preference
NAZA_DESKTOP_CPU=1

# Require GPU; CPU fallback must not masquerade as success
NAZA_DESKTOP_GPU=only
```

Runtime telemetry distinguishes requested backend, observed backend, fallback, and bounded failure reason so “fast” is not incorrectly treated as proof that GPU inference occurred.

---

# Windows / LiteRT-LM GPU work

Windows GPU support is treated as its own compatibility problem rather than assuming every LiteRT-LM package revision behaves identically on Windows.

The normal cross-platform dependency line remains:

```text
flutter_gemma              1.5.2
flutter_gemma_litertlm     1.3.1
```

The dedicated Microsoft Store workflow currently prepares and validates the known Windows compatibility runtime before building the Store package:

```text
flutter_gemma_litertlm     1.0.2
LiteRT-LM native           0.13.1-a
Windows GPU cache          :nocache
```

That path exists because later upstream Windows WebGPU/D3D12 revisions have had compatibility regressions, including the issue tracked as `google-ai-edge/LiteRT-LM#2957`.

## Modern source-build tooling

For development beyond the compatibility runtime, the repository includes:

```text
tool/prepare_windows_litertlm.ps1
tool/build_windows_modern_gpu.ps1
tool/check_windows_litertlm.ps1
```

The modern GPU build script supports a pinned LiteRT-LM fork/source revision, builds/injects a runtime bundle, emits provenance, verifies injected DLLs by SHA-256, and can launch in strict GPU-only mode:

```powershell
.\tool\build_windows_modern_gpu.ps1 -SkipNativeBuild -Launch -StrictGpu
```

Strict mode sets GPU-only application policy so an automatic CPU fallback cannot be mistaken for a successful RTX/WebGPU/D3D12 test.

A hosted GitHub Actions Windows runner can prove that a build/package is reproducible; it cannot prove physical NVIDIA inference. Final GPU correctness must be validated on appropriate Windows/NVIDIA hardware.

---

# Linux rendering behavior

The Linux runner defaults to Flutter's software renderer because affected OpenGL/compositor combinations can update application state without presenting new frames until a resize/move damage event occurs.

Opt into Flutter Linux OpenGL rendering with:

```bash
NAZA_FLUTTER_GPU=1 ./naza_one
```

An additional GTK redraw workaround can be enabled only when required:

```bash
NAZA_GTK_REDRAW=1 ./naza_one
```

The default software-renderer decision affects Flutter UI presentation, not the separate Gemma model backend preference.

---

# Themes and UI

Naza One uses Material 3 plus custom local fonts and a dark glass/mint visual language.

Bundled font families:

- Inter
- JetBrains Mono

The theme system lives under:

```text
lib/theme/naza_themes.dart
lib/theme/theme_settings_panel.dart
```

The theme catalog includes multiple named presets while preserving readable contrast and runtime switching.

---

# Privacy model

The privacy policy is in [`privacypolicy.md`](privacypolicy.md).

Core privacy properties:

- chat/model inference is intended to happen on device;
- no developer-operated conversation server;
- no advertising or behavioral-tracking SDK;
- no microphone/voice pipeline;
- images are processed only after user selection/capture;
- app-private Android cloud backup/device-transfer is disabled;
- local history/memory/settings are stored in the encrypted record system;
- model-delivery providers necessarily receive normal network metadata for model-download requests;
- exported recovery artifacts remain wherever the user chooses to place them.

Do not put real passwords, recovery private keys, highly sensitive records, or private user content in public GitHub issues.

---

# Build from source

## Shared setup

Clone the repository:

```bash
git clone https://github.com/ornab74/naza_one_generation_ui_code.git
cd naza_one_generation_ui_code
```

Use Flutter 3.44.4 to match CI where possible.

If using the repository-local Flutter toolchain on Linux:

```bash
export PATH="$PWD/.tooling/flutter/bin:$PATH"
export PUB_CACHE="$PWD/.pub-cache"
export FLUTTER_SUPPRESS_ANALYTICS=true
```

Then:

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

## Linux x64

Install build dependencies on Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libsecret-1-dev
```

Build:

```bash
flutter build linux --release --no-pub
```

Output:

```text
build/linux/x64/release/bundle/
```

## Android

Requirements:

- Flutter
- Android SDK
- JDK 17+

Build APK and AAB:

```bash
flutter build apk --release --no-pub
flutter build appbundle --release --no-pub
```

The configured local LiteRT-LM model runtime is intended for supported Android ARM64 targets. Unsupported Android x86/x64 runtime combinations are rejected rather than silently pretending the model can run.

## Windows x64

Requirements:

- Flutter
- Visual Studio 2022
- Desktop development with C++ workload

```powershell
flutter pub get
flutter build windows --release --no-pub
```

Output:

```text
build\windows\x64\runner\Release\
```

## macOS

Requirements:

- macOS
- Flutter
- Xcode
- CocoaPods

```bash
flutter build macos --release --no-pub
```

## iOS

Unsigned local build:

```bash
flutter build ios --release --no-codesign --no-pub
```

Signed IPA creation requires the normal Apple distribution certificate, provisioning profile, and export options.

## Web

The UI can be compiled for Web:

```bash
flutter build web --release --no-pub
```

Treat Web as experimental until the local model-runtime behavior for the target browser/deployment is validated.

Full platform instructions:

[`docs/build-all-platforms.md`](docs/build-all-platforms.md)

Signing and CI secrets:

[`docs/github-actions-signing.md`](docs/github-actions-signing.md)

---

# GitHub Actions

The repository intentionally keeps the Actions surface small. There are currently **two workflows**.

## 1. Build Naza One

`.github/workflows/flutter-release.yml`

Triggers on:

- pull requests;
- pushes to `main`;
- `v*` tags;
- manual dispatch.

The workflow first runs:

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

Platform jobs then build:

- Android APK/AAB;
- Linux x64 archive;
- Windows x64 ZIP;
- Windows x64 MSI;
- optional Store-mode MSIX when configured;
- macOS bundle/archive;
- iOS outputs.

## 2. Build Microsoft Store MSIX

`.github/workflows/windows-store-msix.yml`

This Windows-specific workflow:

- prepares the Windows LiteRT-LM compatibility runtime;
- verifies the expected runtime/package/cache policy;
- runs full analysis;
- runs regression tests;
- builds Windows release;
- creates the Store MSIX;
- unpacks and validates the generated `AppxManifest.xml`;
- checks PublisherDisplayName, package identity, and publisher;
- uploads the validated Store package.

The Store workflow requires `WINDOWS_MSIX_PUBLISHER` in GitHub Actions secrets.

---

# Regression testing

The test suite is intentionally broad because many Naza One features are security/state machines rather than static UI.

Coverage includes:

- secure database setup/unlock;
- wrong-password rejection;
- ciphertext tamper detection;
- password changes;
- DEK rotation;
- rollback state;
- security epochs and one-shot capabilities;
- intent guards;
- persistent audit state;
- release/model trust;
- post-quantum export/recovery;
- ML-KEM / ML-DSA policy behavior;
- model bootstrap and SHA verification;
- model backend policy / GPU fallback telemetry;
- image picker bounds;
- app smoke tests;
- continuation engine behavior;
- scanner schema/integrity rules;
- food structured parsing and simulation;
- encrypted food repositories;
- embedded vector search;
- encrypted local memory lifecycle;
- conversation metadata;
- advanced chat coordination;
- onboarding;
- runtime mirror catalog validation;
- model-distribution manifest identity/topology.

Run everything with:

```bash
flutter test --no-pub
```

---

# Project layout

```text
.github/workflows/
  flutter-release.yml          Main analysis/test/cross-platform build
  windows-store-msix.yml       Dedicated Microsoft Store pipeline

lib/
  main.dart                    Verified bootstrap entrypoint
  model_bootstrap.dart         Shipping first-install model verification path
  app.dart                     Main application shell and local model runtime

  chat/
    advanced_chat_coordinator.dart
    history_drawer.dart
    history_metadata_repository.dart
    scroll_follow_controller.dart

  memory/
    embedded_vector_store.dart
    local_memory_service.dart

  model/
    model_distribution_manifest.dart
    multiplane_model_downloader.dart
    runtime_mirror_catalog.dart
    runtime_profile.dart

  onboarding/
    first_run_onboarding.dart
    onboarding_state.dart

  settings/
    runtime_backend_card.dart
    smart_memory_settings_card.dart

  security/
    secure_database.dart
    security_kernel.dart
    security_identity.dart
    hardened_security_runtime.dart
    hardened_vault_controller.dart
    authenticated_rollback_guard.dart
    persistent_audit.dart
    intent_guard.dart
    key_guardian.dart
    release_trust.dart
    pq_trust_policy.dart
    post_quantum_export.dart
    post_quantum_recovery.dart

  food/
    food_hub.dart
    models.dart
    prompts.dart
    repository.dart
    photo_picker.dart
    shelf_scanner.dart
    bake_simulation.dart

  scanner/
    scanner_surface.dart

  theme/
    naza_themes.dart
    theme_settings_panel.dart

tool/
  prepare_windows_litertlm.ps1
  build_windows_modern_gpu.ps1
  check_windows_litertlm.ps1
  model_smoke.dart
  patch_main_advanced.py

docs/
  build-all-platforms.md
  github-actions-signing.md
  SECURITY_HARDENING.md

test/                          Regression and security test suite
mirrors.md                     Model mirror topology + runtime catalog
SECURITY.md                    Current security model
RESEARCH_PAPER.md              Project research/design discussion
privacypolicy.md               Privacy policy
```

---

# Security boundaries and non-claims

Naza One intentionally does **not** claim that:

- Dart heap memory is perfectly zeroizable;
- a rooted/admin-compromised live device cannot observe plaintext in use;
- secure storage is automatically a hardware monotonic counter;
- encrypted SQLite records hide all database metadata;
- flash blocks can always be securely overwritten;
- post-quantum algorithms compensate for a compromised policy engine;
- a deterministic diagnostic transform is a physical sensor measurement;
- image-only food inspection can prove microbiological safety;
- a hosted CI runner can prove physical NVIDIA GPU inference;
- more entropy sources automatically improve a correct OS CSPRNG;
- the advanced HTTPS multi-plane transport is the same thing as native libp2p/Bitswap.

These boundaries are documented because precise guarantees are more useful than decorative security language.

---

# Security reporting

Please report suspected vulnerabilities privately to:

**janulisgraylan@gmail.com**

Include the affected version/platform, reproduction steps, and impact. Do not include real user content, passwords, private recovery keys, or other sensitive material.

See [`SECURITY.md`](SECURITY.md) for the full reporting and threat-model guidance.

---

# Further reading

- [Security model](SECURITY.md)
- [Hardened security architecture](docs/SECURITY_HARDENING.md)
- [Privacy policy](privacypolicy.md)
- [Build all platforms](docs/build-all-platforms.md)
- [GitHub Actions signing](docs/github-actions-signing.md)
- [Model mirrors](mirrors.md)
- [Research paper](RESEARCH_PAPER.md)
- [GitHub Release v1 model parts](https://github.com/ornab74/naza_one_generation_ui_code/releases/tag/v1)

---

## Design principle

**Local first. Verify the model. Encrypt user state. Keep memory on device. Treat model output as data, not authority. Make fallbacks visible. Fail closed when integrity or trust cannot be established.**
