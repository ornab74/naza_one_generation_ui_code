# NAZA One model mirrors

This file is both human-readable documentation and the optional runtime mirror catalog for NAZA One's model downloader.

The app always ships with a baked-in mirror set. This file can add or reorder HTTPS mirrors without removing the baked-in fallback. A downloaded catalog is accepted only when it matches the pinned model filename, immutable Hugging Face revision, full-model byte size, final SHA-256, and all three part byte sizes/CIDs/SHA-256 values compiled into the app.

Security rules enforced by the client:

- HTTPS only; standard port 443 only.
- No URL credentials, fragments, localhost, literal private/link-local/loopback IPs, or `.local` names.
- Remote entries are limited to approved distribution host families (GitHub Releases, Hugging Face, Pinata gateways, `ipfs.io`, and `*.ipfs.inbrowser.link`).
- A runtime catalog can only add transport locations; it cannot change model identity, part identity, hashes, or sizes.
- Every completed part is checked against its pinned SHA-256 before assembly.
- The assembled model is installed only after the final pinned SHA-256 matches.
- If this file is unavailable, malformed, stale, or unsafe, the app silently uses only the baked-in mirrors.

## Current topology

Full model:

- Hugging Face immutable revision: `7fa1d78473894f7e736a21d920c3aa80f950c0db`
- Full bytes: `2583085056`
- SHA-256: `ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42`

Parts:

| Part | Bytes | SHA-256 | CID |
| --- | ---: | --- | --- |
| 0 | 861028352 | `b4ba4432650a1d767736b4139d9d94ab0ebb2e084a9c1fcca3824e691b4cb995` | `bafybeiax5zuvour7ukmssodnaiowp6ija7t2tqzghlqnikakpcafhknpty` |
| 1 | 861028352 | `5f27ca28d693292298ce9bff48c641458af2994466cc1809576380b947861bc8` | `bafybeid7wk63zk76jno5rqovfbl2boekhdfhphvomvb4ztfs2oj5oasqm4` |
| 2 | 861028352 | `00e9d3b99151f41afe9cbc2e99cd3d684b62d67238859285ec89d1cf5a94c2f3` | `bafybeiav2gawt4c2lwz3kj52zjdyw5gtvvrpmrfisyeahhndiuzbiaeckm` |

## Runtime catalog

Do not remove the marker lines. Update only the JSON between them when adding approved mirrors.

<!-- NAZA_MIRRORS_V1_BEGIN -->
```json
{
  "schema": "naza-mirrors-v1",
  "modelFileName": "gemma-4-E2B-it.litertlm",
  "revision": "7fa1d78473894f7e736a21d920c3aa80f950c0db",
  "totalBytes": 2583085056,
  "sha256": "ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42",
  "fullSources": [
    "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/7fa1d78473894f7e736a21d920c3aa80f950c0db/gemma-4-E2B-it.litertlm"
  ],
  "parts": [
    {
      "index": 0,
      "bytes": 861028352,
      "sha256": "b4ba4432650a1d767736b4139d9d94ab0ebb2e084a9c1fcca3824e691b4cb995",
      "cid": "bafybeiax5zuvour7ukmssodnaiowp6ija7t2tqzghlqnikakpcafhknpty",
      "sources": [
        "https://github.com/ornab74/naza_one_generation_ui_code/releases/download/v1/gemma-4-E2B-it.litertlm.part00.bin",
        "https://silver-southern-echidna-758.mypinata.cloud/ipfs/bafybeiax5zuvour7ukmssodnaiowp6ija7t2tqzghlqnikakpcafhknpty",
        "https://ipfs.io/ipfs/bafybeiax5zuvour7ukmssodnaiowp6ija7t2tqzghlqnikakpcafhknpty",
        "https://bafybeiax5zuvour7ukmssodnaiowp6ija7t2tqzghlqnikakpcafhknpty.ipfs.inbrowser.link/"
      ]
    },
    {
      "index": 1,
      "bytes": 861028352,
      "sha256": "5f27ca28d693292298ce9bff48c641458af2994466cc1809576380b947861bc8",
      "cid": "bafybeid7wk63zk76jno5rqovfbl2boekhdfhphvomvb4ztfs2oj5oasqm4",
      "sources": [
        "https://github.com/ornab74/naza_one_generation_ui_code/releases/download/v1/gemma-4-E2B-it.litertlm.part01.bin",
        "https://silver-southern-echidna-758.mypinata.cloud/ipfs/bafybeid7wk63zk76jno5rqovfbl2boekhdfhphvomvb4ztfs2oj5oasqm4",
        "https://ipfs.io/ipfs/bafybeid7wk63zk76jno5rqovfbl2boekhdfhphvomvb4ztfs2oj5oasqm4",
        "https://bafybeid7wk63zk76jno5rqovfbl2boekhdfhphvomvb4ztfs2oj5oasqm4.ipfs.inbrowser.link/"
      ]
    },
    {
      "index": 2,
      "bytes": 861028352,
      "sha256": "00e9d3b99151f41afe9cbc2e99cd3d684b62d67238859285ec89d1cf5a94c2f3",
      "cid": "bafybeiav2gawt4c2lwz3kj52zjdyw5gtvvrpmrfisyeahhndiuzbiaeckm",
      "sources": [
        "https://github.com/ornab74/naza_one_generation_ui_code/releases/download/v1/gemma-4-E2B-it.litertlm.part02.bin",
        "https://silver-southern-echidna-758.mypinata.cloud/ipfs/bafybeiav2gawt4c2lwz3kj52zjdyw5gtvvrpmrfisyeahhndiuzbiaeckm",
        "https://ipfs.io/ipfs/bafybeiav2gawt4c2lwz3kj52zjdyw5gtvvrpmrfisyeahhndiuzbiaeckm",
        "https://bafybeiav2gawt4c2lwz3kj52zjdyw5gtvvrpmrfisyeahhndiuzbiaeckm.ipfs.inbrowser.link/"
      ]
    }
  ]
}
```
<!-- NAZA_MIRRORS_V1_END -->

## Direct IPFS provider hints

These peer records are documentation/provenance for native libp2p/Bitswap transports. They are not HTTPS mirror URLs and are not consumed by the HTTPS runtime catalog.

- Node 1: `/ip4/161.35.112.160/tcp/4001/p2p/12D3KooWCSJHymufeoVskC8kNwS14SPLgApQuNibXWSmtQJENP2d`
- Node 1 QUIC: `/ip4/161.35.112.160/udp/4001/quic-v1/p2p/12D3KooWCSJHymufeoVskC8kNwS14SPLgApQuNibXWSmtQJENP2d`
- Node 2: `/ip4/165.227.17.244/tcp/4001/p2p/12D3KooWA7dr9ocKA2gwhz8mtcCziZvzugbT3gnfSnqSBP2WdST9`
- Node 2 QUIC: `/ip4/165.227.17.244/udp/4001/quic-v1/p2p/12D3KooWA7dr9ocKA2gwhz8mtcCziZvzugbT3gnfSnqSBP2WdST9`
