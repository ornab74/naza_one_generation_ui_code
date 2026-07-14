# Naza One

Naza One is a private, local-first Flutter assistant. It runs Gemma through
LiteRT-LM on the user's device, provides chat plus road and food/water scanner
workflows, and keeps user-created state in an encrypted SQLite record store.
There is no account, advertising SDK, cloud chat backend, voice mode, or voice
model pack.

![Naza One demo](./demo.png)

## Security at a glance

The vault is locked before the main application is mounted. By default, every
fresh app process asks for the boot password before model setup, history,
memory, settings, or generation can run. The password is processed locally and
is never stored. During initial setup the user may opt out of this prompt; that
mode stores a random unlock secret in the operating system's secure credential
store and fails closed when secure storage is unavailable.

Vault records use a versioned key hierarchy:

- Argon2id derives a key-encryption key from the boot password.
- That key unwraps a random vault-unlock key (VUK).
- The VUK unwraps versioned data-encryption keys (DEKs).
- Each logical record is independently encrypted and authenticated with
  AES-256-GCM. HMAC-derived record identifiers avoid storing logical record
  names in plaintext.

Changing the password rewraps the VUK instead of rewriting all user data. DEK
rotation creates a new active key, re-encrypts records transactionally, resumes
an interrupted rotation, and retires the previous key only after no record
references it.

This is record encryption, not SQLite page encryption. An observer who can read
the database file can still infer the schema, approximate record count,
ciphertext lengths, key-version identifiers, and update times. The model file
and non-secret runtime files are not encrypted. See [SECURITY.md](SECURITY.md)
for the threat model and cryptographic boundaries.

## Model integrity

The Gemma 4 E2B model is not committed to this repository. Naza One downloads
it over HTTPS from a revision-pinned URL and checks this pinned SHA-256 digest:

```text
ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42
```

The download is written to a temporary file and hashed while streaming. Only a
matching artifact is atomically promoted into the managed model cache. Its
trust attestation is then stored inside the unlocked encrypted database.

Later boot and send paths reuse that encrypted attestation for the same
unchanged artifact; they do not hash the multi-gigabyte model again. If the
artifact identity or file metadata changes, the attestation is missing, or the
vault cannot authenticate it, Naza One fails closed and verifies the file
again. A mismatched or partial download is never installed.

A matching local `.litertlm` file may be supplied with `NAZA_MODEL_PATH`. Local
files are also accepted only after their digest matches the pinned value.

The inference backend is selectable in Settings:

- **GPU first** uses GPU when supported and falls back to CPU.
- **GPU only** reports an error instead of falling back.
- **CPU only** favors compatibility.

`NAZA_DESKTOP_CPU=1` or `NAZA_DESKTOP_GPU=only` can seed the first-run backend
preference.

## Optional post-quantum recovery

Post-quantum cryptography is deliberately outside the local vault-unlock path.
The optional encrypted backup/recovery format uses a hybrid of ML-KEM-768 and
X25519, combines both shared secrets with transcript-bound HKDF-SHA-256, and
encrypts the exported bytes with AES-256-GCM. The recovery private-key bundle is
itself protected by a local Argon2id-derived key.

ML-KEM does not make a password-derived, single-device database more secure by
itself. The recovery design is useful only when the recovery private key is
kept separately from the device holding the encrypted backup. Losing both the
password and the recovery material is unrecoverable.

## Build and test

This workspace includes Flutter in `.tooling/flutter`:

```bash
export PATH="$PWD/.tooling/flutter/bin:$PATH"
export PUB_CACHE="$PWD/.pub-cache"
export FLUTTER_SUPPRESS_ANALYTICS=true

flutter pub get
flutter analyze
flutter test
flutter build linux --release
```

The Linux bundle is written to `build/linux/x64/release/bundle/`. Android is
restricted to the `arm64-v8a` ABI supported by the LiteRT-LM runtime. Platform
build instructions are in [docs/build-all-platforms.md](docs/build-all-platforms.md),
and release-signing configuration is documented in
[docs/github-actions-signing.md](docs/github-actions-signing.md).

On Linux, the runner defaults to Flutter's software renderer to avoid a known
OpenGL resize-only repaint failure. Set `NAZA_FLUTTER_GPU=1` to test the GPU
renderer. If a stale build does not print
`Naza One: using Flutter Linux software renderer`, run `flutter clean` and
rebuild.

## Project layout

- `lib/main.dart` contains the application, local model runtime, routing, and
  scanner workflows.
- `lib/security/secure_database.dart` implements the encrypted SQLite record
  store, boot unlock, and key rotation.
- `lib/security/post_quantum_export.dart` implements optional hybrid recovery
  exports.
- `test/` covers vault authentication, tamper detection, rotation, recovery,
  routing, and UI behavior.

For privacy details, see [privacypolicy.md](privacypolicy.md).
