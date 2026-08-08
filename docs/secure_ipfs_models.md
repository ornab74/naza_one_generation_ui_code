# Secure IPFS model bootstrap and low-resource seeding

PR #10 is wired to the production IPFS objects published for `gemma-4-E2B-it.litertlm`. The app no longer has placeholder CIDs.

## Pinned production identity

The app pins all of the values needed to reject substituted content:

- Model: `gemma-4-E2B-it.litertlm`
- Model bytes: `2583085056`
- Model SHA-256: `ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42`
- Signed public-manifest directory CID: `bafybeieddw3q33xyvreaycv3dwiu6o36yvpfkpphtrh2laiflkzf7izjdq`
- Manifest Ed25519 public-key DER SHA-256: `fc5d1367b9f18a34b0980ae8605bdbf4da5e6a376346a1706e9417ec8638ecdb`

Model parts:

| Index | Bytes | SHA-256 | CID |
| --- | ---: | --- | --- |
| 0 | 861028352 | `b4ba4432650a1d767736b4139d9d94ab0ebb2e084a9c1fcca3824e691b4cb995` | `bafybeiax5zuvour7ukmssodnaiowp6ija7t2tqzghlqnikakpcafhknpty` |
| 1 | 861028352 | `5f27ca28d693292298ce9bff48c641458af2994466cc1809576380b947861bc8` | `bafybeid7wk63zk76jno5rqovfbl2boekhdfhphvomvb4ztfs2oj5oasqm4` |
| 2 | 861028352 | `00e9d3b99151f41afe9cbc2e99cd3d684b62d67238859285ec89d1cf5a94c2f3` | `bafybeiav2gawt4c2lwz3kj52zjdyw5gtvvrpmrfisyeahhndiuzbiaeckm` |

The private Ed25519 manifest-signing key stays on the publisher and must never be committed to this repository. Only the public key, signature, key fingerprint, manifest and immutable CIDs are distributable.

## Boot verification chain

1. Fetch `model-manifest.json`, `model-manifest.sig`, `manifest-public-key.pem`, and `public-key.sha256` through the pinned manifest directory CID.
2. Reject redirects and non-HTTPS sources.
3. Hash the DER public key and require the app-pinned fingerprint.
4. Verify the Ed25519 signature over the exact manifest JSON bytes.
5. Require the signed model identity and every signed part record to exactly match the values pinned in the application.
6. Download the three immutable IPFS part CIDs.
7. Verify the exact byte count and SHA-256 of every part.
8. Concatenate parts in index order.
9. Verify the final 2,583,085,056-byte model against the pinned full-file SHA-256.
10. Atomically install the completed `.litertlm` file.

A compromised or misbehaving public gateway therefore cannot silently substitute a different model, manifest, public key, signature, part, or byte count.

## Publisher node

The production publisher setup was validated with Kubo 0.43.0 / repo v18. The RPC API and HTTP gateway stay loopback-only; only the libp2p swarm port is exposed. This is deliberate: clients use content-addressed IPFS retrieval rather than receiving administrative access to the publisher node.

The working provider settings are the Kubo 0.43 `Provide` configuration:

```bash
ipfs config --json Provide.Enabled true
ipfs config Provide.Strategy pinned
ipfs config --json Discovery.MDNS.Enabled false
```

Do **not** restore `Reprovider.Strategy` or `Reprovider.Interval`. Those keys are deprecated in Kubo 0.43 / repo v18 and caused the publisher container to restart until the config was migrated.

The publisher pins and explicitly provides the three model part CIDs plus the signed manifest directory CID. A second independent node can pin the exact same four CIDs later for provider redundancy without changing any application metadata.

## Desktop low-resource seeding

Desktop builds with a local `ipfs`/Kubo executable can become additional providers after the model has been securely downloaded. Mobile platforms continue without launching a Kubo subprocess.

The seeder:

- uses the Kubo `lowpower` profile;
- sets `GOMAXPROCS=1`;
- sets `GOMEMLIMIT=256MiB`;
- sets `GOGC=50`;
- disables telemetry through environment/config where supported;
- limits the connection manager to eight peers (low-water four);
- disables mDNS and bandwidth metrics where supported;
- uses `Provide.Enabled=true` and `Provide.Strategy=pinned`;
- enables the filestore and attaches the three already-verified part files with `--nocopy`;
- rejects each attachment unless Kubo reproduces the exact published part CID;
- adds the small signed-manifest directory and rejects it unless Kubo reproduces the exact manifest CID.

Because the published model is intentionally split into three IPFS files, desktop seeding retains those verified part files in addition to the assembled model. Kubo itself does not make another full content copy because the part payloads are attached through the no-copy filestore.

## Reproducing the published layout

The model parts were created from the verified full model as three equal 861,028,352-byte files. Each was added with CIDv1 and raw leaves. The deterministic profile used by the app matches Kubo's published layout:

```bash
ipfs add \
  --cid-version=1 \
  --hash=sha2-256 \
  --chunker=size-262144 \
  --raw-leaves=true \
  --trickle=false \
  PART_FILE
```

The public manifest directory was signed with Ed25519 and added recursively with CIDv1/raw leaves. Keep the signing key offline/private and republish a new immutable manifest CID whenever model metadata changes.
