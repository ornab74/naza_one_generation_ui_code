# Naza One Security Model

## Scope

Naza One is a local-first application. Its security design protects locally
stored user records, detects tampering, establishes the encrypted vault before
model acquisition on fresh installs, and verifies the large inference model
before it is trusted.

This document describes application-layer controls. Platform sandboxing,
full-disk encryption, secure credential storage, Flutter, LiteRT-LM, SQLite,
and the operating system remain part of the trusted computing base.

## Vault design

The `naza-vault-v3` store uses SQLite as a ciphertext record container. Naza
One now exposes two startup-unlock policies over the same encrypted vault:

1. **Protected device unlock — default for new installs.** A random 256-bit
   unlock secret is generated and stored through the operating system secure
   credential store. The user is not asked for a startup password. Failure to
   use the secure credential store is fail-closed; Naza does not silently save
   an equivalent plaintext key.
2. **Interactive boot password — opt in.** A password is processed by Argon2id
   to derive the key-encryption key (KEK). The policy requires at least 12
   characters and uses a unique salt, 64 MiB memory, three iterations, and one
   lane.
3. In either mode the resulting authentication key authenticates and unwraps a
   random 256-bit vault-unlock key (VUK).
4. The VUK authenticates and unwraps versioned random 256-bit data-encryption
   keys (DEKs).
5. Each record value is independently sealed with AES-256-GCM and
   context-bound associated data. Logical record identifiers are derived with
   HMAC-SHA-256 from an index key derived from the VUK.

Encryption is therefore **not optional** merely because the first-run password
checkbox is unchecked. The checkbox controls how the wrapping key is unlocked,
not whether user records are encrypted.

When password mode is enabled, the boot password is not stored. Keys are
retained in process memory only while the vault is unlocked and are cleared on
lock on a best-effort basis. Dart and the host operating system do not provide
a guarantee that every historical copy has been scrubbed from memory.

The first-run UI deliberately makes the interactive gate opt in with the
checkbox **“Require a password every time Naza One starts.”** Existing vaults
keep their previously selected unlock policy.

The small vault header is outside SQLite so KDF parameters and wrapped keys can
be read before unlock. It contains cryptographic metadata, not plaintext user
records.

## First-run security ordering

Fresh/current installs use the following startup ordering:

1. inspect/create/unlock encrypted storage;
2. choose and verify the local Gemma model and the separate scanner-only
   safety-sentinel model;
3. optional product/prompt guide;
4. encrypted theme selection;
5. initialize the selected local inference backend;
6. enter Chat only after both local model identities are ready.

An install containing legacy encrypted records is routed through the original
authenticated migration gate before the new flow can create replacement state.
This prevents the low-friction onboarding path from silently overwriting an
older encrypted vault waiting to be migrated.

## Rotation and password changes

A password change derives a new KEK and rewraps the same VUK. It does not expose
or unnecessarily rewrite all records.

A DEK rotation:

- creates and wraps a new active DEK;
- marks rotation as pending before record migration;
- re-encrypts records inside SQLite transactions;
- resumes after interruption;
- verifies that no record references the previous DEK before retiring it.

Header updates use temporary-file replacement and read-back validation. Database
integrity and authenticated sentinel checks are part of unlock and migration.

## SQLite boundary

Naza One does **not** claim full-page SQLite encryption. The following remain
observable to someone who obtains the database and header:

- SQLite format and schema;
- approximate record count;
- ciphertext and record-size patterns;
- key-version identifiers and update times;
- KDF or secure-storage suite metadata and wrapped-key envelopes.

Record names and values are authenticated ciphertext, but filesystem metadata,
the downloaded model, and non-secret runtime files may also remain visible.
`secure_delete` is enabled, but flash translation layers, snapshots, and backup
systems prevent a reliable secure-deletion guarantee.

## Encrypted voice recall

Generated Read Aloud WAV data is stored as independently authenticated records
inside the unlocked vault. The cache does not persist message plaintext. Its
request identity is SHA-256 over the normalized message hash, instructions
hash, selected model, voice, speed, and WAV format. Recalled audio must also
match its separately stored SHA-256 digest, canonical PCM WAV structure,
authenticated record identity, and encrypted index metadata before playback.

Voice retention is bounded to 64 records, 32 MiB total PCM WAV data, and 16 MiB
per record. Least-recent records are pruned, and cache parsing fails closed on
malformed identities, metadata, encodings, or hashes. A matching encrypted
voice is recalled before any new speech API request is made.

Native Linux and Darwin playback requires a temporary decrypted file. Naza
creates that file inside a freshly generated private temporary directory rather
than the shared `/tmp` root, then removes it on completion, stop, error, or
disposal. Stale files from an interrupted process are removed before the next
playback attempt. Filesystem snapshots and a process or host compromise while
the vault is unlocked remain outside this guarantee. The separate **Export
decrypted WAV file** action intentionally creates a user-visible plaintext
copy.

## Model artifact trust

Each model identity is compiled into the app: expected filename, revision,
exact byte count, part identities, and SHA-256 values. Transport location is
not treated as model identity. Gemma and the scanner-only Llama sentinel have
independent identities and managed files; neither artifact can be substituted
for the other.

The first-run multi-source downloader may obtain chunks from the immutable
Hugging Face full object or approved GitHub Release parts. Completed chunks are
spooled to disk for bounded-memory resume. Model parts and the final assembled
artifact are verified before promotion into the managed model location.

Desktop users may alternatively choose a local `.litertlm` file through the
native picker. Its path is written to the encrypted vault only after exact size
and SHA-256 verification. `NAZA_MODEL_PATH` remains an administrator/developer
override, but it does not bypass integrity verification.

After verification, an attestation for an installed artifact can be stored as
an encrypted vault record. A changed file, missing or unauthenticated
attestation, partial download, or digest mismatch invalidates trust and requires
verification again. The model itself is integrity-protected but not encrypted
because it is public model data.

A runtime mirror catalog may add approved transport locations only when its
immutable model identity matches the version compiled into the app. It cannot
replace the expected model hash or part layout.

The safety sentinel is pinned as `llama3-small-Q3_K_M.gguf`, 111,454,016 bytes,
SHA-256
`8e4f4856fb84bafb895f1eb08e6c03e4be613ead2d942f91561aeac742a619aa`.
It runs through LlamaDart's CPU-only llama.cpp runtime with the `b10075` ABI.
The Linux reproducible-build helper pins native source commit
`0ba009799d7b88ea2851cff4c273a41aa7137224`. The GGUF is rechecked before it is
loaded. This runtime is not exposed to Chat, chat history, tools, or memory.

## Probabilistic harm-filter boundary

Privileged remote-development operations pass through a central, fail-closed
sentinel immediately before authorization or I/O. Current call sites include
DigitalOcean/node lifecycle plans, container/remote/agentic runs, every
configured non-Chat frontier-model egress, Kubo IPFS publish/pull/RPC, and
GitHub repository scan/download/publish.

The privileged-operation classifier receives only:

- one bounded semantic command identifier selected by trusted application
  code;
- bounded CPU/RAM measurements; and
- the locally derived L-state fields and checksum.

It never receives arguments, paths, hosts, CIDs, payloads, prompts, repository
content, credentials, environment variables, or chat history. Repeated
PUNKD/CHUNKD passes return strict `Low`, `Medium`, or `High` votes. Any `High`
vote denies the operation. A timeout, unavailable model, invalid model output,
invalid command identifier, or telemetry failure that cannot be represented
safely also denies. Shell interpreters and destructive command classes retain
deterministic hard denies independent of model output.

`Low` and `Medium` are not authority. Existing user approval, capability,
allowlist, encryption, immutable-image, host-key, and adapter checks still have
to pass. Remote-operation approval and dispatch are separate fresh sentinel
checks, and direct network adapters gate again immediately before opening a
request. Audit receipts contain the semantic name and bounded decision
metadata, never the excluded operation data.

Road and Food/Water scanners use the same small model through a separate
scanner-only evidence API. Its result is authoritative for the displayed risk
band; Gemma may still produce bounded explanations and recommendations. Chat
continues to use its existing model route and does not call the sentinel.

The L-state is a required classifier signal in this design. It is not used as
a password, cryptographic random source, signature, capability, or physical
attestation. See [Probabilistic Harm Filter](docs/probabilistic-harm-filter.md)
for adapter invariants and failure semantics.

## Download pause/resume boundary

The onboarding transfer controller implements cooperative pause rather than a
cosmetic UI state. It stops new chunk scheduling and applies back-pressure at
stream checkpoints. Complete chunks remain in the on-disk resume spool. Pause
does not revoke already-established network connections instantaneously; it
prevents continued application consumption until resumed or cancelled.

## Default hybrid post-quantum recovery

ML-KEM is used only where two separately held key components are meaningful:
encrypted export and recovery. It is intentionally absent from password
derivation and ordinary local vault unlock.

Recovery policy uses the maximum hybrid profile for new enrollment:

- ML-KEM-1024 and ephemeral X25519 in a hybrid construction;
- ML-DSA-87 origin signatures proving that v2 backups were authorized by the
  enrolled recovery key kit rather than merely encrypted to its public key;
- transcript-bound HKDF-SHA-512 over both shared secrets;
- AES-256-GCM for backup confidentiality and authentication;
- an authenticated payload manifest with format, size, digest, record count,
  suite, recipient identity, and creation time;
- Argon2id (96 MiB, four iterations, 32-byte salt) and AES-256-GCM for the
  private recovery key kit.

Version-1 ML-KEM-768/HKDF-SHA-256 combined packages remain decryptable for
backward compatibility but are never selected for new enrollment.

The live vault retains only the public recovery identity. New backup exports
must reopen the separate private key kit and authenticate it with the recovery
password before an ML-DSA-87 signature is produced. Recovery is marked ready
only after the saved kit and backup pass a complete decrypt and record-level
validation pass.

This design protects against compromise of only one key-establishment
primitive. It does not help if the backup and decrypted recovery key are on the
same compromised device. Store the private key kit offline and separately from
backup ciphertext, protect its password, and use the full verification action
before relying on it. The implementation uses FIPS 203/204-aligned primitives;
the app does not claim FIPS 140 module validation or resistance to every
side-channel.

## Experimental MSL-PQ physical root

The Metameric Surface Lattice host protocol is an experimental integration
boundary for future authenticated optical-reader hardware. It is not enabled as
a production root of trust, and simulations, cameras, RGB transforms, and
entropy scores are not accepted as physical possession evidence. Any production
enablement requires the complete evidence package and every mandatory gate in
[MSL-PQ Laboratory Characterization and Security Validation
Specification](docs/msl-pq-laboratory-validation-spec.md).

The host contract enforces bounded challenge profiles, transcript binding,
reader attestation, health checks, replay rejection, optical-dose/rate limits,
encrypted monotonic counters, a required independent post-quantum shared-secret
contribution, and expiring opaque key handles. Physical-surface hardness,
fuzzy-extractor reliability, conditional entropy, reader side-channel
resistance, attestation PKI, and DORR/model-extraction resistance remain claims
that must be established experimentally and independently.

## Threats outside the design

These controls do not protect against:

- malware, root/administrator access, or a modified binary while the vault is
  unlocked;
- password capture when password mode is enabled, screen capture, or clipboard
  monitoring;
- compromise of the operating system secure credential store in default
  passwordless mode;
- vulnerabilities in the operating system, dependencies, hardware, or secure
  credential store;
- intentionally exported plaintext or disclosure by another authorized user;
- denial of service, file deletion, rollback to an older valid snapshot, or
  traffic analysis of model downloads;
- data retained by filesystem snapshots, swap, or flash-media wear leveling.

Android application backup and device-transfer extraction are disabled and
explicitly exclude application storage. Other operating systems, privileged
backup tools, and full-device snapshots remain outside the app's control.

No cryptographic design can recover a forgotten boot password without valid,
separately retained recovery material. Likewise, loss or corruption of required
secure-storage state can make a passwordless vault inaccessible without valid
recovery material.

## Development checks

GitHub Actions are intentionally manual-only. Before release, run locally or
manually dispatch CI for:

```bash
flutter analyze
flutter test
```

Security tests cover wrong-password rejection, ciphertext tampering, key
rotation, device-key mode, encrypted recovery round trips, malformed recovery
material, first-run password-default invariants, model distribution identity,
the cooperative transfer pause gate, harm-filter High vetoes, malformed and
timed-out classifier output, semantic-input minimization, pre-network denial,
and approval/dispatch rechecks. Changes to vault formats, KDF policies, model
attestations, model identities, sentinel policy, or recovery formats require
explicit migration and regression tests; do not silently fall back to defaults
after authentication or parsing errors.

## Reporting a vulnerability

Report suspected vulnerabilities privately to
[janulisgraylan@gmail.com](mailto:janulisgraylan@gmail.com). Include the affected
version, platform, reproduction steps, and impact. Do not include real user
content, passwords, or private recovery keys. Please avoid publishing an
unpatched exploit before there has been a reasonable opportunity to investigate
and prepare a fix.
