import 'package:dart_ipfs/dart_ipfs.dart';

class ModelSeedProfile {
  const ModelSeedProfile({
    this.cidVersion = 1,
    this.hashFunction = 'sha2-256',
    this.chunker = 'size-262144',
    this.rawLeaves = true,
    this.trickle = false,
  });

  final int cidVersion;
  final String hashFunction;
  final String chunker;
  final bool rawLeaves;
  final bool trickle;

  void validate() {
    if (cidVersion != 1) {
      throw const ModelManifestException('Low-resource seeding requires CIDv1.');
    }
    if (hashFunction != 'sha2-256') {
      throw const ModelManifestException('Only sha2-256 IPFS blocks are supported.');
    }
    if (!RegExp(r'^size-[1-9][0-9]{3,7}$').hasMatch(chunker)) {
      throw const ModelManifestException('Unsafe or unsupported IPFS chunker.');
    }
    if (!rawLeaves) {
      throw const ModelManifestException('No-copy filestore seeding requires raw UnixFS leaves.');
    }
  }

  List<String> get kuboAddArguments => <String>[
        '--cid-version=$cidVersion',
        '--hash=$hashFunction',
        '--chunker=$chunker',
        '--raw-leaves=$rawLeaves',
        '--trickle=$trickle',
      ];
}

class ModelPartManifest {
  const ModelPartManifest({
    required this.index,
    required this.name,
    required this.sizeBytes,
    required this.sha256,
    required this.cid,
  });

  final int index;
  final String name;
  final int sizeBytes;
  final String sha256;
  final String cid;

  void validate() {
    if (index < 0) {
      throw const ModelManifestException('Part index must be non-negative.');
    }
    if (!_safeFileName(name)) {
      throw ModelManifestException('Unsafe model part filename: $name');
    }
    if (sizeBytes <= 0) {
      throw ModelManifestException('Invalid model part size: $name');
    }
    if (!_isSha256(sha256)) {
      throw ModelManifestException('Invalid SHA-256 for model part: $name');
    }
    _validateCid(cid, label: 'model part');
  }
}

class ModelManifest {
  const ModelManifest({
    required this.fileName,
    required this.manifestCid,
    required this.manifestSigningKeySha256,
    required this.sha256,
    required this.expectedBytes,
    required this.expectedParts,
    this.gatewayHosts = const <String>[
      'ipfs.io',
      'dweb.link',
      'cloudflare-ipfs.com',
    ],
    this.seedProfile = const ModelSeedProfile(),
  });

  final String fileName;
  final String manifestCid;
  final String manifestSigningKeySha256;
  final String sha256;
  final int expectedBytes;
  final List<ModelPartManifest> expectedParts;
  final List<String> gatewayHosts;
  final ModelSeedProfile seedProfile;

  bool get isConfigured =>
      manifestCid.isNotEmpty &&
      manifestSigningKeySha256.isNotEmpty &&
      sha256.isNotEmpty &&
      expectedBytes > 0 &&
      expectedParts.isNotEmpty &&
      !manifestCid.startsWith('REPLACE_');

  void validate() {
    if (!isConfigured) {
      throw const ModelManifestException('Model download is not configured yet.');
    }
    if (!_safeFileName(fileName)) {
      throw const ModelManifestException('Unsafe model file name.');
    }
    if (!_isSha256(sha256)) {
      throw const ModelManifestException('Model SHA-256 must be 64 hexadecimal characters.');
    }
    if (!_isSha256(manifestSigningKeySha256)) {
      throw const ModelManifestException('Manifest signing-key fingerprint is invalid.');
    }
    _validateCid(manifestCid, label: 'manifest');

    if (gatewayHosts.isEmpty) {
      throw const ModelManifestException('At least one HTTPS gateway is required.');
    }
    for (final host in gatewayHosts) {
      if (!RegExp(r'^[a-z0-9.-]+$').hasMatch(host) ||
          host.startsWith('.') ||
          host.endsWith('.')) {
        throw ModelManifestException('Unsafe gateway host: $host');
      }
    }

    var bytes = 0;
    for (var i = 0; i < expectedParts.length; i++) {
      final part = expectedParts[i];
      part.validate();
      if (part.index != i) {
        throw const ModelManifestException('Model part indexes must be contiguous and ordered.');
      }
      bytes += part.sizeBytes;
    }
    if (bytes != expectedBytes) {
      throw ModelManifestException(
        'Part byte total $bytes does not match expected model size $expectedBytes.',
      );
    }

    seedProfile.validate();
  }

  Iterable<Uri> gatewayUrisForCid(String cid) sync* {
    validate();
    _validateCid(cid, label: 'download');
    for (final host in gatewayHosts) {
      yield Uri(scheme: 'https', host: host, pathSegments: <String>['ipfs', cid]);
    }
  }

  Iterable<Uri> manifestFileUris(String name) sync* {
    validate();
    if (!_safeFileName(name)) {
      throw ModelManifestException('Unsafe manifest filename: $name');
    }
    for (final host in gatewayHosts) {
      yield Uri(
        scheme: 'https',
        host: host,
        pathSegments: <String>['ipfs', manifestCid, name],
      );
    }
  }
}

bool _safeFileName(String value) =>
    value.isNotEmpty &&
    !value.contains('/') &&
    !value.contains(r'\\') &&
    value != '.' &&
    value != '..';

bool _isSha256(String value) =>
    RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value);

void _validateCid(String value, {required String label}) {
  try {
    final decoded = CID.decode(value);
    if (decoded.encode() != value && !value.startsWith('Qm')) {
      throw ModelManifestException('$label CID is not canonical.');
    }
  } on ModelManifestException {
    rethrow;
  } catch (_) {
    throw ModelManifestException('Invalid $label IPFS CID.');
  }
}

class ModelManifestException implements Exception {
  const ModelManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}

const primaryModelManifest = ModelManifest(
  fileName: 'gemma-4-E2B-it.litertlm',
  manifestCid: 'bafybeieddw3q33xyvreaycv3dwiu6o36yvpfkpphtrh2laiflkzf7izjdq',
  manifestSigningKeySha256:
      'fc5d1367b9f18a34b0980ae8605bdbf4da5e6a376346a1706e9417ec8638ecdb',
  sha256: 'ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42',
  expectedBytes: 2583085056,
  expectedParts: <ModelPartManifest>[
    ModelPartManifest(
      index: 0,
      name: 'gemma-4-E2B-it.litertlm.part-00.bin',
      sizeBytes: 861028352,
      sha256: 'b4ba4432650a1d767736b4139d9d94ab0ebb2e084a9c1fcca3824e691b4cb995',
      cid: 'bafybeiax5zuvour7ukmssodnaiowp6ija7t2tqzghlqnikakpcafhknpty',
    ),
    ModelPartManifest(
      index: 1,
      name: 'gemma-4-E2B-it.litertlm.part-01.bin',
      sizeBytes: 861028352,
      sha256: '5f27ca28d693292298ce9bff48c641458af2994466cc1809576380b947861bc8',
      cid: 'bafybeid7wk63zk76jno5rqovfbl2boekhdfhphvomvb4ztfs2oj5oasqm4',
    ),
    ModelPartManifest(
      index: 2,
      name: 'gemma-4-E2B-it.litertlm.part-02.bin',
      sizeBytes: 861028352,
      sha256: '00e9d3b99151f41afe9cbc2e99cd3d684b62d67238859285ec89d1cf5a94c2f3',
      cid: 'bafybeiav2gawt4c2lwz3kj52zjdyw5gtvvrpmrfisyeahhndiuzbiaeckm',
    ),
  ],
);
