# AION-MSL Protocol Specification

Status: Experimental, version 1.0. This document is normative for the Dart
implementation. It does not claim independent cryptographic review.

## 1. Security objectives

AION-MSL derives purpose-bound authorization capabilities while providing
forward state evolution, replay resistance, rollback detection, optional
post-quantum key contribution, and optional multi-administrator contribution
quorums. It does not protect secrets after compromise of the live endpoint.
Software-chaos values are public transcript diversity and receive zero entropy
credit.

## 2. Primitive suite

| Function | Primitive |
|---|---|
| Transcript commitment | SHA-256 |
| PRF and ratchet | HMAC-SHA-512 |
| Persistence AEAD | AES-256-GCM through `NazaSecureDatabase` |
| PQ key contribution | Authenticated ML-KEM shared secret |
| Contributor signature | ML-DSA-65 by default; ML-DSA-44/87 explicitly pinned |
| Randomness | 64 bytes from the platform CSPRNG per transition |

Keys, nonces, signatures, and parameter sets are not algorithm-negotiated on
attacker-controlled input. Contributor parameter sets are pinned locally.

## 3. Integer and field encoding

Integers are unsigned big-endian. `U64(x)` is exactly eight bytes. Variable
fields are `U32(length) || value`. Text is UTF-8 without normalization and must
match `[A-Za-z0-9._:/-]{1,64}` where an identifier is required. Lists are sorted
by bytewise source identifier before hashing. Domain labels are literal UTF-8.

Ambiguous concatenation is prohibited. Existing fixed-width concatenations are
version-frozen; all new variable fields require a length prefix.

## 4. Federation contribution

For source `s`, round `r`, visibility `v`, and reveal `x`:

```text
C = SHA-256("AION-FEDERATION/commit/v1" || LP(s) || U64(r) || LP(x))
M = "AION-FEDERATION/sign/v1" || LP(s) || U64(r) || U8(v) || C
SIG = ML-DSA.Sign(sk_s, M, ctx="NAZA-AION-FEDERATION-v1")
```

`x` is 32–128 bytes, `r > 0`, and each source occurs once. Every signature and
commitment must verify before any output is released. A round contains 2–16
sources and must meet configured total and confidential quorums.

The public transcript commits to source, round, visibility, commitment and
signature digest. The confidential mix is:

```text
F = SHA-256("AION-FEDERATION/confidential/v1" || U64(r)
    || (LP(source_i) || LP(reveal_i))* )
```

Only confidential entries enter `F`. Public entries receive zero secret entropy
credit. The resulting mix is one-use and its round must equal the next durable
AION epoch. Reuse and stale/future epoch binding reject before derivation.
Transport confidentiality remains a caller obligation. Contributor keys carry
locally pinned inclusive first/last valid rounds, providing deterministic key
rotation and revocation cutovers without attacker-controlled negotiation.

## 5. AION state transition

Inputs are profile, purpose, 32-byte verifier nonce, optional federation mix,
zero-to-128-byte PQ secret, one-to-64 bounded chaos frames, prior ratchet `R_e`,
prior Merkle root `T_e`, and durable epoch `e`.

Maximum mode requires at least 32 PQ-secret bytes. The engine obtains 64 fresh
CSPRNG bytes `Z`, computes the canonical transcript digest `D`, and derives:

The distinct `federatedMaximum` profile is downgrade-resistant: federation is
mandatory and the verified mix must contain at least five total contributors,
three confidential contributors, and three distinct locally pinned trust
domains. It uses a separate persisted profile namespace from ordinary maximum
mode. It also forbids device and user roots in the Flutter engine and requires
an external key schedule. The broker receives the transcript digest, prior
ratchet, fresh entropy, authenticated PQ secret and confidential federation mix;
it combines these with roots provisioned directly inside its boundary and
returns exactly one 64-byte active transition key. Any other output length
rejects and poisons the broker session.

```text
A_0 = HMAC-SHA-512(SHA-256(D), device_root || user_root? || R_e || Z
      || pq_secret || federation_confidential_mix?)
A_i = HMAC-SHA-512(A_(i-1), D || U64(i-1) || chaos_digest)
R_(e+1) = HMAC-SHA-512(A_n, "puncture" || lattice_digest || Z)
T_(e+1) = SHA-256(T_e || SHA-256(U64(e+1) || D || lattice_digest))
```

Checkpoint compare-and-commit and monotonic-counter advance must both move from
`e` to `e+1`. Disagreement fails closed. A storage interruption may deny future
use and require recovery; it must never silently roll state backward.

## 6. Persistence envelope

Checkpoint JSON is stored only in `NazaSecureDatabase`. That database uses
AES-256-GCM with a fresh nonce and AAD binding the record identifier and key
version. Plaintext also contains its namespace and logical key, preventing
record swapping. Ratchet length is 64 bytes, Merkle root length 32 bytes, and
epoch is positive. The checkpoint carries mandatory cryptographic suite version
2; legacy, absent and future suite values reject rather than migrate implicitly.
Decode, tag, shape, rollback, suite or read-back failure rejects. Preventing an
attacker from installing an older application binary additionally requires the
platform's signed-update and anti-rollback controls.

## 7. Capability semantics

Capabilities bind purpose, epoch and expiry. Authorization removes the stored
capability before verification, making every attempt consuming and one-use.
Messages are capped at 1 MiB. Expired, modified, replayed or unknown handles
reject. Capability keys and superseded ratchets are zeroed on best effort.

## 8. Failure rules

Malformed inputs, unknown identities, invalid signatures, quorum failure,
counter mismatch, checkpoint divergence, entropy failure and internal verifier
exceptions are terminal for that operation. No partial federation result,
plaintext checkpoint, reconstructed root, or raw secret is returned.

## 9. Isolated broker framing

The optional native broker protocol uses `AIONBRK1 || version || direction ||
U64(sequence) || U8(code) || U32(length) || payload || HMAC-SHA-256`. Frames are
capped at 65,536 payload bytes. Responses must be authenticated, have response
direction, and exactly echo the outstanding sequence. Unknown, replayed,
oversized, truncated or modified frames reject. Sessions default to a two-second
operation deadline and at most 1,024 invocations. Any timeout, authentication
failure, sequence error or broker rejection irreversibly poisons the session,
zeroes its authentication key on best effort and closes the transport. A fresh 256-bit session key must
be delivered through protected inherited IPC—not command-line arguments,
environment variables, logs or files. Broker framing does not itself create an
OS sandbox; the native launcher must apply the platform policy in the isolation
review.

On Linux, the conforming launcher is the direct Landlock/seccomp implementation
under `tool/aion_broker`. Production startup must fail when Landlock ABI 3,
seccomp filtering, process limits, non-dumpability, `no_new_privs`, or parent-
death coupling cannot be installed. A successful self-test is required for the
release environment, not merely the build host.

## 10. Conformance

Conforming implementations must pass known-good, mutation, ordering, replay,
rollback, restart, malformed-length, duplicate-source, signature-substitution,
capability-reuse and randomized parser tests. Production activation additionally
requires independent cryptographic review and platform-specific side-channel
assessment.
