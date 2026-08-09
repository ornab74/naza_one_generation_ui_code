# Naza One

[![Build Naza One](https://github.com/ornab74/naza_one_generation_ui_code/actions/workflows/flutter-release.yml/badge.svg)](https://github.com/ornab74/naza_one_generation_ui_code/actions/workflows/flutter-release.yml)
[![Microsoft Store MSIX](https://github.com/ornab74/naza_one_generation_ui_code/actions/workflows/windows-store-msix.yml/badge.svg)](https://github.com/ornab74/naza_one_generation_ui_code/actions/workflows/windows-store-msix.yml)

**Naza One is a private, local-first Flutter AI workstation built around on-device Gemma + LiteRT-LM.** It combines local chat, vision, road/safety scanning, food intelligence, encrypted memory, hardened local storage, hybrid post-quantum recovery, verified model delivery, and cross-platform desktop/mobile builds without requiring a cloud chat backend.

> **Microsoft Store:** https://apps.microsoft.com/detail/9nm382wsvsvn

![Naza One demo](./demo.png)

## Core idea

Naza One keeps the assistant and user-created state as close to the user as practical. Normal inference runs locally. History, memory, scanner state, settings, onboarding state, and selected-model metadata are stored locally with authenticated encryption. Model files are public model data, so they are integrity-protected rather than encrypted.

There is no developer-operated conversation server, no advertising SDK, no behavioral analytics SDK, no required user account, and no microphone/voice-generation pipeline.

## First-run experience

The executable entrypoint is now **vault first**, not model first.

```text
lib/main.dart
    |
    v
NazaBootCoordinator
    |
    +-- 1. encrypted vault setup / unlock
    +-- 2. verified model setup
    +-- 3. skippable AI + feature guide
    +-- 4. theme selection
    +-- 5. pre-load Gemma runtime
    |
    v
Chat ready to use
```

### 1. Encryption first

A fresh install always creates the encrypted local vault before model acquisition.

The default UX is intentionally low-friction:

- **vault encryption is always on**;
- **startup password is off by default**;
- the default passwordless path generates a random unlock secret and stores it in the operating system secure credential store;
- the first-run checkbox is phrased as an opt-in: **“Require a password every time Naza One starts”**;
- enabling it switches the startup gate to Argon2id-derived password protection;
- secure-storage failure is fail-closed rather than silently writing an equivalent plaintext key.

Existing password-protected vaults still request their password. Installs containing older encrypted records are routed through the original authenticated migration path so legacy data is verified before cleanup.

### 2. Advanced model setup

The second screen is the local-model setup surface. It exposes a real multi-source chunked downloader with live progress rather than a decorative progress bar.

The UI shows:

- received / total bytes;
- chunk completion;
- active transfer count;
- current throughput;
- fastest observed provider;
- verification stage;
- **Pause** and **Resume** controls.

Pause is cooperative and real: active response streams are back-pressured and new chunks stop being scheduled. Completed chunks remain on disk for later resume. Closing and reopening the app can reuse already-completed chunk state.

### Desktop local-model picker

Windows, Linux, and macOS also expose **“Use a local .litertlm model file instead”**.

The native file picker accepts the model only after the exact expected byte count and pinned SHA-256 match. The selected source path and model identity are then saved inside the encrypted vault. Naza attempts to expose the verified file to the managed model cache using a link/hard-link first to avoid casually duplicating ~2.4 GiB, with a copy fallback when the platform cannot link it.

The developer/admin override remains supported:

```bash
export NAZA_MODEL_PATH=/absolute/path/to/gemma-4-E2B-it.litertlm
```

That path does **not** bypass model integrity checks.

### 3. Skippable local guide

The third screen teaches the minimum useful mental model for:

- normal prompting;
- local chat and encrypted Smart Memory;
- vision/image prompts;
- road/safety scanner use;
- fridge, food and bake workflows;
- local-first security boundaries.

The guide is skippable.

### 4. Theme gallery

First run now includes a large theme gallery with dark and light presets including Naza Emerald, Orbital Olive, Cyber Neon, Synthwave, Midnight, Terminal, Ocean Lab, Forest, Ember, Lavender Moon, Graphite, Obsidian Red, Quantum Cyan, Deep Space, Aurora, Plasma, Copper Circuit, Ice Station, Rose Dark, Black Gold, Matrix Rain, Ultraviolet, Solar, Arctic, Paper Mint, Rose Quartz, Open Sky and Desert Paper.

The selected theme is stored in the encrypted vault and restored on later starts.

### 5. AI pre-warm

Before onboarding exits, Naza prepares the selected backend, refreshes model trust, and calls the local Gemma runtime readiness path. The application lands in Chat only after local inference is ready, so the first message does not need to wait through a hidden model-load step.

---

# Local model identity

Current model:

```text
gemma-4-E2B-it.litertlm
```

Immutable Hugging Face revision:

```text
7fa1d78473894f7e736a21d920c3aa80f950c0db
```

Expected bytes:

```text
2,583,085,056
```

Pinned final SHA-256:

```text
ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42
```

The GitHub release is split into three equal-size model parts:

| Part | Bytes | SHA-256 |
| --- | ---: | --- |
| `part00.bin` | 861,028,352 | `b4ba4432650a1d767736b4139d9d94ab0ebb2e084a9c1fcca3824e691b4cb995` |
| `part01.bin` | 861,028,352 | `5f27ca28d693292298ce9bff48c641458af2994466cc1809576380b947861bc8` |
| `part02.bin` | 861,028,352 | `00e9d3b99151f41afe9cbc2e99cd3d684b62d67238859285ec89d1cf5a94c2f3` |

Release: https://github.com/ornab74/naza_one_generation_ui_code/releases/tag/v1

---

# Multi-source model distribution

Relevant files:

```text
lib/model/model_distribution_manifest.dart
lib/model/runtime_mirror_catalog.dart
lib/model/multiplane_model_downloader.dart
lib/model/pausable_model_downloader.dart
lib/model/local_model_preference.dart
mirrors.md
```

The first-run downloader uses immutable model identity compiled into the app. Runtime mirror discovery may add approved transport locations but cannot change the expected filename, revision, total size, part sizes, part hashes/CIDs, or final SHA-256.

Current transport families include:

- immutable Hugging Face full-object source;
- GitHub Release parts;
- Pinata IPFS gateways;
- `ipfs.io`;
- `*.ipfs.inbrowser.link`;
- documented direct IPFS peer IDs/multiaddrs as topology hints for future native libp2p/Bitswap transport.

The onboarding transfer engine uses 4 MiB chunks, concurrent range requests, provider scoring, persistent chunk spool state, contiguous-prefix assembly, part hash verification, final full-file SHA-256 verification, and atomic promotion into the managed model location.

[`mirrors.md`](mirrors.md) is both human-readable topology documentation and the optional runtime HTTPS mirror catalog.

---

# Chat

Naza One supports local streaming generation with:

- automatic continuation;
- seam/overlap repair;
- bounded continuation passes;
- context-window recovery;
- image attachment support;
- explicit generation timeouts;
- encrypted history;
- reopenable conversation threads;
- user-aware streaming scroll behavior;
- searchable/pinnable/renameable conversation metadata in the modular chat layer.

Relevant modular files:

```text
lib/chat/advanced_chat_coordinator.dart
lib/chat/history_drawer.dart
lib/chat/history_metadata_repository.dart
lib/chat/scroll_follow_controller.dart
```

---

# Smart local memory

Naza One includes an embedded dependency-free hybrid vector retrieval engine instead of requiring a network vector database.

Default index geometry:

```text
128 dimensions
8 LSH tables
13 LSH bits
2,400 record bound
96 first-stage candidates
```

Retrieval combines deterministic LSH fan-out, one-bit neighbor probing, lexical postings, int8 first-stage similarity, exact cosine reranking, recency, salience, reinforcement, confidence, thread affinity, access signals, and maximal marginal relevance.

The encrypted SQLite vault is the durable source of truth; ANN structures are rebuildable local acceleration data.

Relevant files:

```text
lib/memory/embedded_vector_store.dart
lib/memory/local_memory_service.dart
```

Retrieved memory is treated as potentially stale historical evidence, not as trusted instructions.

---

# Vision, scanner and food intelligence

Vision input is selected/captured deliberately by the user and normalized locally before inference.

The scanner system is evidence-bounded: it separates supplied observations from inference, avoids presenting software transforms as physical sensors, and keeps uncertainty explicit when evidence is incomplete.

Food modules include fridge analysis, shelf/product workflows, bake analysis/simulation, structured local prompts, image handling, and encrypted saved analyses.

```text
lib/scanner/scanner_surface.dart
lib/food/food_hub.dart
lib/food/models.dart
lib/food/photo_picker.dart
lib/food/prompts.dart
lib/food/repository.dart
lib/food/shelf_scanner.dart
lib/food/bake_simulation.dart
```

Visual AI cannot prove microbiological safety, hidden contamination, internal temperature, or other properties that are not directly evidenced. Use real-world measurements and professional/emergency guidance when stakes require it.

---

# Vault security

See [`SECURITY.md`](SECURITY.md) and [`docs/SECURITY_HARDENING.md`](docs/SECURITY_HARDENING.md).

The vault uses a layered hierarchy:

```text
password OR OS secure-storage unlock secret
              |
              v
        key-encryption key
              |
              v
      wrapped 256-bit VUK
              |
              v
    versioned wrapped DEKs
              |
              v
 AES-256-GCM encrypted records
```

Password mode uses Argon2id. Logical record identifiers are HMAC-derived. Data-key rotation is transactional/resumable. Password changes rewrap key material rather than rewriting every record.

The SQLite container is **record encrypted**, not page encrypted. Schema, approximate row count, ciphertext sizes, key-version identifiers, timestamps, filesystem metadata and similar information can remain observable to someone who obtains the database.

No software-only Flutter/Dart design can guarantee that plaintext actively being used is invisible to a fully privileged live-memory attacker.

---

# Hardened security layer

The repository includes security-state identities and epochs, single-purpose capability leases, rollback detection, forward-evolving audit state, intent/provenance guards, key-guardian abstractions, model/release trust identities, and explicit separation between model suggestions and deterministic application authorization.

Relevant modules:

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

The LLM is never treated as the authority that grants privileged security capabilities.

---

# Hybrid post-quantum recovery

The current maximum recovery profile uses:

- ML-KEM-1024;
- X25519;
- transcript-bound HKDF-SHA-512;
- AES-256-GCM;
- ML-DSA-87 origin signatures;
- an Argon2id-protected private recovery key kit.

Post-quantum cryptography protects long-lived recovery/key-establishment/signature relationships; it is not used as a replacement for AES bulk record encryption.

Legacy ML-KEM-768 recovery packages remain readable through the compatibility path but are not selected for new enrollment.

---

# GPU / CPU runtime policy

Desktop runtime policy supports GPU-first, GPU-only, and CPU-only behavior with explicit backend telemetry and fallback visibility.

Examples:

```bash
NAZA_DESKTOP_CPU=1
NAZA_DESKTOP_GPU=only
```

Strict GPU testing must reject CPU fallback rather than treating a fast CPU result as proof of GPU execution.

Windows development helpers:

```text
tool/prepare_windows_litertlm.ps1
tool/build_windows_modern_gpu.ps1
tool/check_windows_litertlm.ps1
```

A hosted Windows runner can validate build/package reproducibility; physical NVIDIA inference still requires suitable hardware.

---

# Build from source

Clone:

```bash
git clone https://github.com/ornab74/naza_one_generation_ui_code.git
cd naza_one_generation_ui_code
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

CI currently uses Flutter `3.44.4`; matching it locally is recommended.

### Linux

```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev
flutter build linux --release --no-pub
```

### Android

```bash
flutter build apk --release --no-pub
flutter build appbundle --release --no-pub
```

### Windows

```powershell
flutter build windows --release --no-pub
```

### macOS

```bash
flutter build macos --release --no-pub
```

### iOS unsigned

```bash
flutter build ios --release --no-codesign --no-pub
```

More detail: [`docs/build-all-platforms.md`](docs/build-all-platforms.md)

---

# GitHub Actions: manual only

To reduce CI/CD minutes and artifact storage, the repository intentionally keeps only two workflows and **neither runs automatically**.

### Build Naza One

`.github/workflows/flutter-release.yml`

Trigger: **`workflow_dispatch` only**.

When manually started, you can choose:

```text
all
analyze
android
linux
windows
macos
ios
```

The analyzer/regression-test gate always runs first. Build artifacts are currently retained for only **3 days**.

### Build Microsoft Store MSIX

`.github/workflows/windows-store-msix.yml`

Trigger: **`workflow_dispatch` only**.

It prepares/verifies the Windows LiteRT-LM compatibility runtime, analyzes/tests, builds Windows, creates the Store package, validates the generated Appx manifest, and uploads the MSIX with short artifact retention.

So pushes, pull requests and tags do **not** spend Actions minutes by themselves. Run either workflow manually from the GitHub Actions tab when you actually want a build.

---

# Regression coverage

The test suite covers encrypted-database lifecycle, wrong-password handling, ciphertext tamper detection, key rotation, post-quantum recovery, security-state/capability behavior, model bootstrap/integrity, runtime backend policy, continuation logic, scanner contracts, food repositories, vector retrieval, encrypted memory, conversation metadata, onboarding, runtime mirror validation and model-distribution identity.

New first-run regression guards also assert:

- the product first-run password requirement remains opt-in;
- `main.dart` remains vault-first;
- the theme catalog remains broad and IDs stay unique;
- the model pause gate actually blocks and resumes;
- both GitHub workflows remain manual-only;
- desktop local-model selection remains encrypted-preference + hash gated.

Run manually:

```bash
flutter test --no-pub
```

---

# Project map

```text
.github/workflows/
  flutter-release.yml
  windows-store-msix.yml

lib/
  main.dart
  app.dart
  model_bootstrap.dart

  onboarding/
    boot_coordinator.dart
    boot_theme_catalog.dart
    first_run_onboarding.dart
    onboarding_state.dart

  model/
    model_distribution_manifest.dart
    multiplane_model_downloader.dart
    pausable_model_downloader.dart
    runtime_mirror_catalog.dart
    local_model_preference.dart
    runtime_profile.dart

  chat/
  memory/
  scanner/
  food/
  security/
  settings/
  theme/

tool/
docs/
test/
mirrors.md
SECURITY.md
privacypolicy.md
```

---

# Security non-claims

Naza One does not claim that:

- Dart heap memory is perfectly zeroizable;
- root/admin compromise cannot observe plaintext in use;
- SQLite record encryption hides all database metadata;
- flash storage can always be securely overwritten;
- post-quantum primitives repair a compromised policy engine;
- image analysis can prove hidden physical/biological properties;
- hosted CI proves physical NVIDIA execution;
- HTTPS gateway transport is native libp2p/Bitswap.

Precision is part of the security model.

---

# Security reporting

Report suspected vulnerabilities privately to:

**janulisgraylan@gmail.com**

Do not include real passwords, recovery private keys, sensitive user records or private conversation content in public GitHub issues.

Further reading:

- [Security model](SECURITY.md)
- [Hardened security architecture](docs/SECURITY_HARDENING.md)
- [Privacy policy](privacypolicy.md)
- [Build guide](docs/build-all-platforms.md)
- [Signing guide](docs/github-actions-signing.md)
- [Model mirrors](mirrors.md)
- [Research paper](RESEARCH_PAPER.md)

## Design principle

**Encrypt user state. Verify the model. Keep memory local. Treat model output as data, not authority. Make fallbacks visible. Keep the default experience simple without pretending security properties that are not actually present.**
