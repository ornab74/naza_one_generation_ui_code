# Naza One Hardened Security Architecture

This document defines the first implementation phase of Naza One's hardened local-AI security architecture. The goal is defense in depth: compromise of one component should not automatically become authority over the vault, model trust, recovery system, or future security epochs.

## Threat model

The hardened design assumes an attacker may obtain a filesystem image, restore an older but valid encrypted vault, submit malicious imported content, replay a previously authorized privileged request, replace a model artifact, inspect logs, or compromise a non-security-critical component. Higher-assurance profiles also plan for debugger/core-dump exposure, memory extraction, device theft, and compromised update infrastructure.

No software-only design can promise that plaintext actively being used by a process is invisible to a fully privileged live-memory attacker. Dart and Flutter also cannot guarantee that every runtime copy of a secret is synchronously zeroized. Naza therefore minimizes secret lifetime and is evolving toward native/hardware key handles rather than claiming "RAM-proof" encryption.

## Security kernel

`lib/security/security_kernel.dart` introduces four primitives.

### Security-state binding

`NazaSecurityState` binds privileged authorization to an explicit security epoch plus vault, application, model, policy, recovery, and trust-root identities. A keyed digest of this state is used by capabilities. A change in any bound identity invalidates capabilities issued under the previous state.

### Single-purpose capability leases

`NazaCapabilityLease` represents explicit authority for one action and resource. Leases have a bounded use count, are bound to the security-state digest and epoch, and are revoked on every security-state transition. High-risk actions should use single-use leases.

The model must never mint or validate these leases. An LLM may propose an operation, but deterministic application policy must issue and consume the capability.

### Rollback guard

`NazaRollbackGuard` tracks the highest accepted security epoch in a separate key/value store and rejects vault state older than that value. The current abstraction deliberately describes this as a rollback signal, not a universal hardware monotonic counter. Platform integrations should back it with protected device storage and, where practical, TPM/StrongBox/Secure-Enclave-backed state.

### Forward-evolving audit key

`NazaForwardSecureAudit` chains events and ratchets its audit key after every append. Erased predecessor keys are not reconstructed from a later audit key. Future work will persist encrypted audit entries, add Merkle checkpoints, and sign checkpoint roots with an independent recovery/audit authority.

## Required integration rules

1. Privileged operations must not check only `isUnlocked`. They should require an action-specific capability.
2. Vault export, recovery change, authentication change, key rotation, model replacement, trust-root replacement, and vault erasure should use single-use leases.
3. Model identity, policy identity, recovery generation, or trust-root changes must advance the security epoch.
4. Outstanding leases must die immediately when the epoch changes or the vault locks.
5. Rollback verification must happen before decrypted user records are made available.
6. The rollback epoch must be committed only after the new vault state is durably committed.
7. Audit data must never contain passwords, VUKs, DEKs, recovery private keys, full prompts, or plaintext user records.
8. LLM output is untrusted data. It cannot grant capabilities or weaken policy.

## Post-quantum direction

Naza's existing recovery implementation remains the cryptographic recovery layer. The long-term hardened profile should keep bulk record encryption symmetric while using hybrid post-quantum/classical cryptography for long-lived trust relationships:

- ML-KEM-1024 + X25519 for recovery/device-migration encapsulation.
- ML-DSA-87 + a classical signature for long-lived manifests and trust transitions.
- Independent signing domains for application releases, model releases, recovery, audit checkpoints, and emergency revocation.
- Explicit suite identifiers and downgrade policy.
- Recovery generations so restored historical backups cannot silently resurrect revoked recovery authority.
- Threshold authorization for root changes and optional threshold recovery, using reviewed threshold protocols rather than reconstructing a long-lived private key in normal runtime memory.

Post-quantum cryptography is not used as a replacement for AES record encryption. AES-256 remains appropriate for bulk local data; PQ primitives protect long-lived key establishment, recovery, signatures, and trust delegation.

## Physical-compromise roadmap

The next implementation stage is a small native Key Guardian with a deliberately narrow API. Flutter should receive opaque handles instead of durable root keys. Target properties:

- VUK/recovery private material does not reside in the Dart heap during ordinary operation.
- TPM, Android StrongBox/Keystore, or Apple Secure Enclave bindings where supported.
- locked/non-dumpable native pages where supported, with documented platform limitations.
- aggressive session-key destruction on OS lock, suspend, hibernate, user switch, or vault lock.
- disposable inference workers for high-assurance sessions, because terminating a worker is easier to reason about than proving every runtime scratch buffer was scrubbed.
- no network, arbitrary filesystem access, environment secrets, recovery material, or vault keys inside model workers.

## Storage roadmap

The existing database uses authenticated per-record encryption and intentionally does not claim SQLite page encryption. Hardened storage will evolve toward:

- authenticated security epochs and rollback detection;
- per-record or per-sensitivity-class DEKs for crypto-erasure;
- security-state/epoch binding in record AAD;
- Merkle commitments over encrypted record envelopes;
- padded size buckets for high-privacy records;
- optional encrypted placement indirection and periodic reshuffling;
- recovery quarantine and atomic promotion rather than overwriting a live vault during restore.

Traditional multi-pass overwrite is not considered reliable deletion on modern flash media because wear leveling, snapshots, and copy-on-write can retain old physical pages. Naza should prefer cryptographic erasure by destroying the relevant wrapping key.

## Supply-chain roadmap

Application and model updates should eventually use independent signed manifests containing artifact hashes, exact sizes, source revisions, minimum compatible runtime/security versions, issuance/expiry metadata, and revocation generations. High-assurance release jobs should pin CI actions, emit an SBOM and provenance, and keep release signing isolated from untrusted pull-request execution.

## Non-goals / claims we do not make

- The Dart heap is not guaranteed to provide perfect secret zeroization.
- Secure storage is not automatically equivalent to a hardware monotonic counter.
- Memory canaries do not defeat a privileged attacker.
- More entropy sources do not automatically improve a good OS CSPRNG; CPU load, timing, and visual/color state must not be treated as cryptographic entropy.
- Hybrid or post-quantum cryptography does not compensate for a compromised policy engine or a process that exposes plaintext after legitimate decryption.
- "ORAM-lite" placement/padding techniques are not full oblivious RAM unless a reviewed ORAM protocol is actually implemented.

These distinctions are intentional. The hardened architecture favors precise security properties over decorative or unverifiable security claims.
