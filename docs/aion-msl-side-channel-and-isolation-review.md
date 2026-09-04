# AION-MSL Side-Channel and Isolation Review

## Current boundary

ML-DSA verification processes public material in a separate Dart isolate. This
protects UI availability from ordinary verification work and removes public-key
parsing from the main isolate, but it is not an OS sandbox: isolates share the
same process, native libraries and compromise domain.

Checkpoint plaintext exists transiently in the application process before
AES-256-GCM encryption. Dart garbage collection prevents guarantees that every
copy is erased. Explicit zeroization is best effort, not a proof of erasure.

## Reviewed properties

- Secret comparisons in local protocol code use constant-work byte comparison.
- Attacker-controlled lengths, frame counts, contributors and messages are
  bounded before expensive operations.
- ML-DSA keys and parameter sets are locally pinned; no downgrade negotiation is
  accepted from a contribution.
- Contributor verification exceptions fail closed.
- Signing should remain hedged; deterministic ML-DSA signing is test-only.
- Public chaos and public beacons receive zero entropy credit.
- Persisted state is AEAD-protected and record-bound.

## Required production isolation

For a high-assurance deployment, move ML-KEM decapsulation, ML-DSA signing, root
access and final capability derivation into a minimal broker process or hardware
keystore. Give the broker no network access, a private authenticated IPC channel,
strict request-size limits, an allowlist of operations, memory/core-dump locking
where supported, reduced filesystem access, a dedicated OS identity, and a
seccomp/App Sandbox/restricted-token profile appropriate to the platform.

The repository now provides `AionAuthenticatedBrokerClient` and the `AIONBRK1`
authenticated binary framing contract. The remaining platform launcher must
deliver its fresh session key through inherited protected IPC, instantiate the
least-privilege profile, pin the broker executable identity, enforce startup and
per-request deadlines, and terminate the session after any framing violation.
The client now enforces bounded per-request deadlines, a bounded session request
count, and terminal session poisoning; launcher startup deadlines and executable
identity pinning remain native-platform responsibilities.

### Linux direct-kernel launcher

`tool/aion_broker/aion_linux_sandbox.c` provides a dependency-free Linux
launcher for x86-64 and AArch64. It requires Landlock ABI 3 or newer and applies
an allowlist containing only the broker and explicitly supplied runtime paths.
All handled filesystem writes, creation, deletion, rename and unlisted reads are
denied. A seccomp-BPF filter denies socket creation, connection, binding,
listening, acceptance and datagram transfer. It also sets `no_new_privs`, disables
core dumps, installs address-space/file-descriptor/CPU limits, requests SIGKILL
when the parent dies and rejects symlink broker paths. Production execution
requires a root-owned broker with no owner/group/world write bits. The launcher
creates a new session, applies a restrictive umask and closes every inherited
descriptor above stderr except its already-open broker descriptor. It executes
that descriptor to reduce path replacement races and supplies only `LANG=C` and
`TZ=UTC`.

The seccomp policy also denies tracing, cross-process memory reads and writes,
mount/chroot/pivot operations, eBPF, userfaultfd, kernel keyrings, kernel module
changes, kexec and reboot. These denials reduce post-compromise expansion; they
do not replace the operation-level broker allowlist.

The launcher's mandatory self-test enters the actual sandbox and succeeds only
if reading `/etc/passwd`, creating an IPv4 socket and enabling ptrace are all
denied. The main
security gate compiles and runs this test on Linux. This materially isolates a
broker but does not authenticate publisher identity: release packaging must
still verify a signed, pinned broker digest and prevent binary rollback before
launch.

The Flutter process should receive opaque handles, verification booleans and
bounded public commitments—not long-lived roots or signing keys. Crash and
timeout paths must consume the request identifier and fail closed.

`AionPolicy.federatedMaximum` now enforces this root boundary in code: supplying
a device or user root to Flutter is rejected, and an external key schedule is
mandatory. `AionBrokerKeySchedule` serializes a domain-separated, length-bounded
derive request over authenticated IPC, accepts only a 64-byte result and zeroes
its request payload and engine-side transition copies on best effort. The
remaining broker executable must provision roots without returning them.

## Validation backlog

1. Run dudect-style timing tests around native secret-bearing operations.
2. Measure cache, branch and power leakage on each supported CPU class.
3. Fault-inject checkpoint writes, counter commits and verifier termination.
4. Disable crash dumps and verify secret exclusion from logs and telemetry.
5. Add native process sandboxes per Android, Apple, Linux and Windows target.
6. Obtain independent review of domain separation and state-transition order.

No timing claim is made for pure Dart ML-DSA internals. Verification handles
public inputs; private ML-DSA signing keys should live outside this process.
