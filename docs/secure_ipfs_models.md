# Secure IPFS model bootstrap and low-resource seeding

Naza One now starts behind a model bootstrap gate. The original application lives unchanged in `lib/naza_app.dart`; `lib/main.dart` verifies the model, optionally starts bounded desktop seeding, and then hands control to the app.

## Configure and publish the model

Edit `lib/model_bootstrap/model_manifest.dart`:

1. Calculate SHA-256 and the exact byte count of the final model.
2. Add the file to IPFS with the exact UnixFS options in `seedProfile`.
3. Put the resulting root CID in `primaryModelManifest.cid`.
4. Put the independent 64-character SHA-256 in `primaryModelManifest.sha256`.
5. Set `expectedBytes` to the exact file size.
6. Keep only gateways you trust in `gatewayHosts`.

The current reproducible publishing command is:

```bash
sha256sum gemma-4-E2B-it.litertlm
wc -c < gemma-4-E2B-it.litertlm
ipfs add \
  --cid-version=1 \
  --hash=sha2-256 \
  --chunker=size-262144 \
  --raw-leaves=true \
  --trickle=false \
  gemma-4-E2B-it.litertlm
```

Do not change those IPFS layout options after publishing. Different chunking or UnixFS settings produce a different root CID even when the model bytes are identical.

## Download security

- Only allowlisted HTTPS gateways are contacted.
- Redirects are rejected.
- Downloads use a `.part` staging file.
- Declared and actual byte counts are checked.
- SHA-256 is compared before installation.
- A verified file is atomically renamed into `verified_models`.
- Bad, partial, oversized, or mismatched files are deleted.
- Existing cached models are re-verified on startup.
- Until configured, the boot screen lets users continue without downloading.

`dart_ipfs` supplies canonical CID parsing and validation. Gateway transport is streamed with `HttpClient`, so large models are not buffered wholly in memory.

## Low-resource seeding

Desktop builds can seed the verified model through a locally installed Kubo executable named `ipfs` or `kubo`. Mobile builds and systems without Kubo simply continue into the app without seeding.

The seeder deliberately does not call `dart_ipfs.addFileStream` for the multi-gigabyte model because that package currently assembles the stream in memory. Instead, it uses Kubo's no-copy filestore and references the already verified file in place.

Default limits:

- Kubo `lowpower` profile.
- `GOMAXPROCS=1`, limiting Go execution to one logical CPU at a time.
- `GOMEMLIMIT=256MiB`, a Go runtime memory target rather than an absolute operating-system cap.
- `GOGC=50`, favoring earlier garbage collection.
- Eight swarm connections maximum, with a low-water target of four.
- mDNS disabled.
- bandwidth metrics disabled.
- provider announcements reduced to a 12-hour interval where supported.
- no second full-size copy of the model; only IPFS metadata and references are stored.

The first no-copy attachment still has to read and hash the full model once to reproduce the UnixFS CID. It is single-thread bounded but can take time on slower devices. Subsequent starts reuse the filestore metadata.

Seeding never bypasses model verification. The locally reproduced IPFS root CID must exactly match the manifest CID or the seed process is rejected. Kubo configuration keys vary slightly between releases, so optional tuning keys are best-effort; the one-thread and Go memory settings are always passed directly to the Kubo process.
