# Secure IPFS model bootstrap

Naza One now starts behind a model bootstrap gate. The original application lives unchanged in `lib/naza_app.dart`; `lib/main.dart` verifies the model before handing control to it.

## Configure the model

Edit `lib/model_bootstrap/model_manifest.dart`:

1. Upload the final immutable model file to IPFS.
2. Put its CID in `primaryModelManifest.cid`.
3. Calculate SHA-256 independently and put the 64-character lowercase digest in `primaryModelManifest.sha256`.
4. Set `expectedBytes` to the exact file size when available.
5. Keep only gateways you trust in `gatewayHosts`.

```bash
sha256sum gemma-4-E2B-it.litertlm
wc -c < gemma-4-E2B-it.litertlm
ipfs add --cid-version=1 --raw-leaves=true gemma-4-E2B-it.litertlm
```

## Security behavior

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
