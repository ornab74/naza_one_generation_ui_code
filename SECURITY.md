# Naza One Security Model

## Scope

Naza One is a local-first application. Its security design protects locally
stored user records, detects tampering, gates access at fresh process startup,
and verifies the large inference model without repeatedly hashing an unchanged
artifact.

This document describes application-layer controls. Platform sandboxing,
full-disk encryption, secure credential storage, Flutter, LiteRT-LM, SQLite,
and the operating system remain part of the trusted computing base.

## Vault design

The `naza-vault-v3` store uses SQLite as a ciphertext record container:

1. A boot password is processed by Argon2id to derive a key-encryption key
   (KEK). The default policy requires at least 12 characters and uses a unique
   salt, 64 MiB memory, three iterations, and one lane.
2. The KEK authenticates and unwraps a random 256-bit vault-unlock key (VUK).
3. The VUK authenticates and unwraps versioned random 256-bit data-encryption
   keys (DEKs).
4. Each record value is independently sealed with AES-256-GCM and context-bound
   associated data. Logical record identifiers are derived with HMAC-SHA-256
   from an index key derived from the VUK.

The boot password is not stored. Keys are retained in process memory only while
the vault is unlocked and are cleared on lock on a best-effort basis. Dart and
the host operating system do not provide a guarantee that every historical
copy has been scrubbed from memory.

The vault defaults to requiring its password for each fresh App process, before
the main UI or model workflow starts. If the user explicitly disables that
gate, the KEK is replaced by a random secret held in the platform secure
credential store. Setup and unlock fail closed if that store is unavailable.

The small vault header is outside SQLite so KDF parameters and wrapped keys can
be read before unlock. It contains cryptographic metadata, not plaintext user
records.

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
- KDF parameters and wrapped-key envelopes.

Record names and values are authenticated ciphertext, but filesystem metadata,
the downloaded model, and non-secret runtime files may also remain visible.
`secure_delete` is enabled, but flash translation layers, snapshots, and backup
systems prevent a reliable secure-deletion guarantee.

## Model artifact trust

The model downloader pins both the HTTPS artifact revision and its SHA-256
digest. It hashes incoming bytes while writing a temporary file and promotes
the file only after the digest matches.

After verification, an attestation for that installed artifact is stored as an
encrypted vault record. Boot and message-send paths reuse the attestation for
the same unchanged file, avoiding an expensive second hash. A changed file,
missing or unauthenticated attestation, partial download, or digest mismatch
invalidates trust and fails closed. The model itself is integrity-protected but
not encrypted because it is public model data.

## Default hybrid post-quantum recovery

ML-KEM is used only where two separately held key components are meaningful:
encrypted export and recovery. It is intentionally absent from password
derivation and local vault unlock.

Recovery enrollment is default-on for every new and migrated vault. The v2
profile uses separated private-key-kit and encrypted-backup artifacts:

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
before relying on it. The pure-Dart provider is FIPS 203/204-aligned; the app
does not claim FIPS 140 validation or resistance to every side-channel.

## Threats outside the design

These controls do not protect against:

- malware, root/administrator access, or a modified binary while the vault is
  unlocked;
- password capture, weak or reused passwords, screen capture, or clipboard
  monitoring;
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
separately retained recovery material.

## Development checks

Before release, run:

```bash
flutter analyze
flutter test
```

Security tests cover wrong-password rejection, ciphertext tampering, key
rotation, device-key mode, encrypted recovery round trips, and malformed
recovery material. Changes to vault formats, KDF policies, model attestations,
or recovery formats require explicit migration and regression tests; do not
silently fall back to defaults after authentication or parsing errors.

## Reporting a vulnerability

Report suspected vulnerabilities privately to
[janulisgraylan@gmail.com](mailto:janulisgraylan@gmail.com). Include the affected
version, platform, reproduction steps, and impact. Do not include real user
content, passwords, or private recovery keys. Please avoid publishing an
unpatched exploit before there has been a reasonable opportunity to investigate
and prepare a fix.
