# Probabilistic Harm Filter

Naza's core security sentinel is a local, scanner-only Llama runtime adapted
from `naza-dart-source.zip`. It is a defense-in-depth veto in front of remote
and privileged operations, and a risk classifier for Road and Food/Water
scanners. It is never a Chat model.

## Privileged-operation contract

Trusted application code maps a typed operation to one semantic identifier,
such as `ipfs.data.publish`, `digitalocean.droplet.start`, or
`github.data.pull`. The gate adds current CPU/RAM telemetry and derives the
L-state. No caller API exists for supplying command arguments or payload data.

The model runs up to five repeated PUNKD/CHUNKD passes. Output parsing accepts
only the complete words `Low`, `Medium`, and `High`.

| Outcome | Authorization result |
| --- | --- |
| Any `High` vote | Deny |
| Invalid/missing output | Deny |
| Timeout, load failure, or inference error | Deny |
| Invalid semantic identifier | Deny without sending the raw value to the model or audit |
| Deterministically destructive/shell class | Deny without model authorization |
| Repeated `Low`/`Medium` result | Continue to all independent policy and approval checks |

The decision queue and inference queue are serialized. Idle unload participates
in the same queue, preventing an unload from racing a newly submitted
generation. A fresh artifact size and SHA-256 verification precedes model load.

## Input minimization

The cyber sentinel input is limited to:

- semantic command name;
- CPU utilization and logical processor count;
- process RSS and available/total RAM when the platform provides them; and
- L-state probabilities, coherence, phase, state bit, non-local index, and
  checksum.

The following must never cross this boundary: shell text, arguments, paths,
URLs, hostnames, CIDs, repository data, prompts, chat history, environment
variables, tokens, cookies, SSH keys, or other credentials. Audit records use
the same minimized projection.

Because the model intentionally cannot inspect arguments, every adapter must
accept a typed operation rather than arbitrary shell text. The adapter remains
responsible for argument validation, allowlists, quotas, immutable references,
authentication, encryption, explicit approval, and capability consumption.

## Enforcement points

- Remote-operation records are reclassified when moving to `approved` and
  again when moving to `dispatched`. A denied transition is audited but not
  persisted as authorized.
- Kubo RPC classifies immediately before creating each request/socket.
- BookForge GitHub scan, pull, and publish classify before the first HTTP
  request.
- Agentic remote SSH/container/network/frontier routes classify before remote
  model or execution-bound work.
- Every configured frontier-model route except Chat classifies before provider
  egress. Chat remains deliberately outside the scanner-only runtime.
- Future adapters must gate again at the concrete side effect; a stored
  approval is not a reusable bypass token.

## Scanner contract

Road and Food/Water flows use a separate method that accepts bounded scanner
evidence and the scanner L-state. Evidence is delimited as inert data. Invalid
sentinel output fails the scan closed. The sentinel risk label overrides the
risk label produced by the explanatory model and conservatively calibrates the
safety score. Scanner calls do not create chat turns or use chat memory.

## Trust and limitations

The GGUF identity is pinned by filename, size, and SHA-256. This prevents a
mirror from silently substituting different bytes; it does not make model
predictions deterministic truth or protect a process already controlled by a
privileged attacker. The L-state is treated as a required classifier signal,
not as cryptographic entropy, a signature, or a capability. Deterministic
policy and explicit authority therefore remain mandatory even after a
non-High result.
