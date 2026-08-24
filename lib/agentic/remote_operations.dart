// LLM-CONTEXT:BEGIN
// FILE: lib/agentic/remote_operations.dart
// ROLE: Secret-free plans and encrypted request history for remote agentic
// environments, Chromium scraping, and IPFS publication.
// DOMAIN: agentic-coding
// SECURITY-INVARIANT: No provider token, private key, cookie, command, or
// scraped payload is accepted here; mutations remain awaiting approval until
// a separately attested adapter dispatches them.
// CHANGE-GUARD: Keep requests bounded, HTTPS/allowlist constrained, image
// references immutable, public IPFS exposure opt-in, and local Gemma default.
// LLM-CONTEXT:END
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../model/sentinel_model_runtime.dart';
import '../security/probabilistic_harm_filter.dart';
import '../security/secure_database.dart';

enum NazaRemoteOperationKind {
  digitalOceanDroplet,
  chromiumScrape,
  ipfsPublish,
  ipfsFetch,
  nodeStart,
  nodeStop,
  nodeDelete,
  digitalOceanDropletStart,
  digitalOceanDropletStop,
  digitalOceanDropletDelete,
  scrapeExportIpfs,
}

extension NazaRemoteOperationKindX on NazaRemoteOperationKind {
  String get label => switch (this) {
    NazaRemoteOperationKind.digitalOceanDroplet => 'DigitalOcean droplet',
    NazaRemoteOperationKind.chromiumScrape => 'Chromium scrape',
    NazaRemoteOperationKind.ipfsPublish => 'IPFS publish',
    NazaRemoteOperationKind.ipfsFetch => 'IPFS fetch',
    NazaRemoteOperationKind.nodeStart => 'Node start',
    NazaRemoteOperationKind.nodeStop => 'Node stop',
    NazaRemoteOperationKind.nodeDelete => 'Node delete',
    NazaRemoteOperationKind.digitalOceanDropletStart =>
      'DigitalOcean droplet start',
    NazaRemoteOperationKind.digitalOceanDropletStop =>
      'DigitalOcean droplet stop',
    NazaRemoteOperationKind.digitalOceanDropletDelete =>
      'DigitalOcean droplet delete',
    NazaRemoteOperationKind.scrapeExportIpfs => 'Scrape → IPFS export',
  };

  bool get isDestructive => const <NazaRemoteOperationKind>{
    NazaRemoteOperationKind.nodeDelete,
    NazaRemoteOperationKind.digitalOceanDropletDelete,
  }.contains(this);

  /// Semantic identifier only: no host, path, CID, argument, payload, prompt,
  /// or credential crosses the probabilistic harm-filter boundary.
  String get sentinelCommandName => switch (this) {
    NazaRemoteOperationKind.digitalOceanDroplet =>
      'digitalocean.droplet.create',
    NazaRemoteOperationKind.chromiumScrape => 'container.chromium.scrape',
    NazaRemoteOperationKind.ipfsPublish => 'ipfs.data.publish',
    NazaRemoteOperationKind.ipfsFetch => 'ipfs.data.fetch',
    NazaRemoteOperationKind.nodeStart => 'remote.node.start',
    NazaRemoteOperationKind.nodeStop => 'remote.node.stop',
    NazaRemoteOperationKind.nodeDelete => 'remote.node.delete',
    NazaRemoteOperationKind.digitalOceanDropletStart =>
      'digitalocean.droplet.start',
    NazaRemoteOperationKind.digitalOceanDropletStop =>
      'digitalocean.droplet.stop',
    NazaRemoteOperationKind.digitalOceanDropletDelete =>
      'digitalocean.droplet.delete',
    NazaRemoteOperationKind.scrapeExportIpfs => 'ipfs.data.save',
  };
}

enum NazaRemoteOperationState {
  awaitingApproval,
  approved,
  dispatched,
  completed,
  failed,
  cancelled,
}

extension NazaRemoteOperationStateX on NazaRemoteOperationState {
  String get label => switch (this) {
    NazaRemoteOperationState.awaitingApproval => 'Awaiting approval',
    NazaRemoteOperationState.approved => 'Approved · adapter required',
    NazaRemoteOperationState.dispatched => 'Dispatched',
    NazaRemoteOperationState.completed => 'Completed',
    NazaRemoteOperationState.failed => 'Failed closed',
    NazaRemoteOperationState.cancelled => 'Cancelled',
  };
}

/// A DigitalOcean-compatible create plan. It deliberately contains no bearer
/// token; a trusted provider adapter must obtain that secret from the vault at
/// dispatch time after a fresh user approval.
@immutable
final class NazaDigitalOceanDropletPlan {
  const NazaDigitalOceanDropletPlan({
    required this.name,
    required this.region,
    required this.size,
    required this.image,
    this.sshKeyRefs = const <String>[],
    this.tags = const <String>[],
    this.backups = false,
    this.ipv6 = false,
    this.monitoring = true,
    this.publicNetworking = false,
    this.vpcUuid,
    this.workspacePurpose = 'agentic-sandbox',
  });

  final String name;
  final String region;
  final String size;
  final String image;
  final List<String> sshKeyRefs;
  final List<String> tags;
  final bool backups;
  final bool ipv6;
  final bool monitoring;
  final bool publicNetworking;
  final String? vpcUuid;
  final String workspacePurpose;

  Map<String, Object?> toApiPayload() {
    final payload = <String, Object?>{
      'name': _bounded(name, 63),
      'region': _bounded(region, 32),
      'size': _bounded(size, 64),
      'image': _bounded(image, 160),
      'backups': backups,
      'ipv6': ipv6,
      'monitoring': monitoring,
      'public_networking': publicNetworking,
      'tags': List<String>.unmodifiable(tags.map((tag) => _bounded(tag, 63))),
      'with_droplet_agent': true,
    };
    if (sshKeyRefs.isNotEmpty) {
      payload['ssh_keys'] = List<Object?>.unmodifiable(
        sshKeyRefs.map(_apiKeyReference),
      );
    }
    final cleanVpc = vpcUuid?.trim();
    if (cleanVpc != null && cleanVpc.isNotEmpty) payload['vpc_uuid'] = cleanVpc;
    return Map<String, Object?>.unmodifiable(payload);
  }

  List<String> validate() {
    final errors = <String>[];
    if (!_validLabel(name, 63)) errors.add('Droplet name is invalid.');
    if (!_validToken(region, 32)) errors.add('Droplet region is invalid.');
    if (!_validToken(size, 64)) errors.add('Droplet size is invalid.');
    if (image.trim().isEmpty || image.length > 160) {
      errors.add('Droplet image is required and bounded.');
    }
    if (sshKeyRefs.length > 32) errors.add('Too many SSH-key references.');
    if (tags.length > 32) errors.add('Too many droplet tags.');
    if (tags.any((tag) => !_validLabel(tag, 63))) {
      errors.add('Droplet tags must be short, non-empty labels.');
    }
    if (vpcUuid != null && vpcUuid!.trim().isNotEmpty && !_uuidLike(vpcUuid!)) {
      errors.add('VPC UUID is malformed.');
    }
    return List<String>.unmodifiable(errors);
  }

  static Object _apiKeyReference(String value) {
    final clean = value.trim();
    final numeric = int.tryParse(clean);
    return numeric ?? _bounded(clean, 96);
  }
}

@immutable
final class NazaChromiumScrapePlan {
  const NazaChromiumScrapePlan({
    required this.targetUrl,
    required this.allowedDomains,
    this.workerNodeId,
    this.image = NazaRemoteOperationsDefaults.scraperImage,
    this.maxPages = 1,
    this.outputFormat = 'jsonl',
    this.respectRobots = true,
    this.allowCookies = false,
    this.networkApproved = false,
  });

  final String targetUrl;
  final List<String> allowedDomains;
  final String? workerNodeId;
  final String image;
  final int maxPages;
  final String outputFormat;
  final bool respectRobots;
  final bool allowCookies;
  final bool networkApproved;

  List<String> validate() {
    final errors = <String>[];
    final uri = Uri.tryParse(targetUrl.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      errors.add('Scraping requires an HTTPS target URL.');
    }
    if (allowedDomains.isEmpty || allowedDomains.length > 32) {
      errors.add('Add one to 32 explicit allowed domains.');
    }
    if (allowedDomains.any((domain) => !_validDomain(domain))) {
      errors.add(
        'Allowed domains must be hostnames without paths or wildcards.',
      );
    }
    if (workerNodeId != null && !_isValidId(workerNodeId!)) {
      errors.add('Scraping worker node reference is invalid.');
    }
    if (uri != null &&
        uri.host.isNotEmpty &&
        !allowedDomains.any((domain) => _sameOrSubdomain(uri.host, domain))) {
      errors.add('The target host is not in the domain allowlist.');
    }
    if (!NazaAgenticImagePolicy.isImmutable(image)) {
      errors.add(
        'Chromium workers require an immutable image@sha256:<64 hex> reference.',
      );
    }
    if (maxPages < 1 || maxPages > 100)
      errors.add('Maximum pages must be 1–100.');
    if (!const <String>{
      'jsonl',
      'json',
      'markdown',
      'text',
    }.contains(outputFormat)) {
      errors.add('Unsupported scrape output format.');
    }
    return List<String>.unmodifiable(errors);
  }

  Map<String, Object?> toAdapterPlan() => <String, Object?>{
    'image': image.trim(),
    'targetUrl': targetUrl.trim(),
    'allowedDomains': List<String>.unmodifiable(allowedDomains),
    if (workerNodeId != null) 'workerNodeId': workerNodeId,
    'maxPages': maxPages,
    'outputFormat': outputFormat,
    'respectRobots': respectRobots,
    'allowCookies': allowCookies,
    'networkApproved': networkApproved,
  };
}

enum NazaScrapeExportDestination { localIpfs, digitalOceanIpfs }

extension NazaScrapeExportDestinationX on NazaScrapeExportDestination {
  String get label => switch (this) {
    NazaScrapeExportDestination.localIpfs => 'Local Kubo/IPFS',
    NazaScrapeExportDestination.digitalOceanIpfs => 'DigitalOcean IPFS relay',
  };
}

@immutable
final class NazaScrapeExportPlan {
  const NazaScrapeExportPlan({
    required this.scrapeRequestId,
    required this.destination,
    required this.format,
    this.relayNodeId,
    this.encryptedPayload = true,
    this.publiclyDiscoverable = false,
    this.publicExposureApproved = false,
    this.maxBytes = 64 * 1024 * 1024,
    this.resultCid,
  });

  final String scrapeRequestId;
  final NazaScrapeExportDestination destination;
  final String format;
  final String? relayNodeId;
  final bool encryptedPayload;
  final bool publiclyDiscoverable;
  final bool publicExposureApproved;
  final int maxBytes;
  final String? resultCid;

  List<String> validate() {
    final errors = <String>[];
    if (!_isValidId(scrapeRequestId)) {
      errors.add('Scrape source request reference is invalid.');
    }
    if (!const <String>{'jsonl', 'json', 'markdown', 'text'}.contains(format)) {
      errors.add('Unsupported scrape export format.');
    }
    if (relayNodeId != null && !_isValidId(relayNodeId!)) {
      errors.add('IPFS relay node reference is invalid.');
    }
    if (destination == NazaScrapeExportDestination.digitalOceanIpfs &&
        relayNodeId == null) {
      errors.add('DigitalOcean IPFS export requires an explicit relay node.');
    }
    if (maxBytes < 1024 || maxBytes > 512 * 1024 * 1024) {
      errors.add('Scrape export must be between 1 KiB and 512 MiB.');
    }
    if (!encryptedPayload) errors.add('Scrape exports must be encrypted.');
    if (publiclyDiscoverable && !publicExposureApproved) {
      errors.add('Public scrape export requires explicit exposure approval.');
    }
    if (resultCid != null && !_validCid(resultCid!)) {
      errors.add('Scrape export result CID is invalid.');
    }
    return List<String>.unmodifiable(errors);
  }

  Map<String, Object?> toAdapterPlan() => <String, Object?>{
    'scrapeRequestId': scrapeRequestId,
    'destination': destination.name,
    'format': format,
    if (relayNodeId != null) 'relayNodeId': relayNodeId,
    'encryptedPayload': encryptedPayload,
    'publiclyDiscoverable': publiclyDiscoverable,
    'publicExposureApproved': publicExposureApproved,
    'maxBytes': maxBytes,
    if (resultCid != null) 'resultCid': resultCid,
  };
}

@immutable
final class NazaIpfsPublicationPlan {
  const NazaIpfsPublicationPlan({
    required this.contentCid,
    required this.label,
    this.peerIds = const <String>[],
    this.publiclyDiscoverable = false,
    this.publicExposureApproved = false,
    this.encryptedPayload = true,
  });

  final String contentCid;
  final String label;
  final List<String> peerIds;
  final bool publiclyDiscoverable;
  final bool publicExposureApproved;
  final bool encryptedPayload;

  List<String> validate() {
    final errors = <String>[];
    if (!_validCid(contentCid)) errors.add('Enter a bounded IPFS CID.');
    if (!_validLabel(label, 120)) errors.add('IPFS label is invalid.');
    if (peerIds.length > 64 || peerIds.any((peer) => !_validPeerId(peer))) {
      errors.add('IPFS peer references are invalid or too numerous.');
    }
    if (publiclyDiscoverable && !publicExposureApproved) {
      errors.add(
        'Public IPFS discovery requires an explicit exposure approval.',
      );
    }
    if (!encryptedPayload && publiclyDiscoverable) {
      errors.add('Public IPFS content must be encrypted before publication.');
    }
    return List<String>.unmodifiable(errors);
  }

  Map<String, Object?> toAdapterPlan() => <String, Object?>{
    'contentCid': contentCid.trim(),
    'label': _bounded(label, 120),
    'peerIds': List<String>.unmodifiable(peerIds),
    'publiclyDiscoverable': publiclyDiscoverable,
    'publicExposureApproved': publicExposureApproved,
    'encryptedPayload': encryptedPayload,
  };
}

/// The persisted envelope contains intent and references only. It is safe to
/// show in an audit list because it excludes provider credentials, SSH key
/// bytes, cookies, page content, and model prompts.
@immutable
final class NazaRemoteOperationRequest {
  const NazaRemoteOperationRequest({
    required this.id,
    required this.kind,
    required this.provider,
    required this.label,
    required this.createdAt,
    this.state = NazaRemoteOperationState.awaitingApproval,
    this.nodeId,
    this.host,
    this.droplet,
    this.scrape,
    this.ipfs,
    this.scrapeExport,
    this.error,
  });

  final String id;
  final NazaRemoteOperationKind kind;
  final String provider;
  final String label;
  final DateTime createdAt;
  final NazaRemoteOperationState state;
  final String? nodeId;
  final String? host;
  final NazaDigitalOceanDropletPlan? droplet;
  final NazaChromiumScrapePlan? scrape;
  final NazaIpfsPublicationPlan? ipfs;
  final NazaScrapeExportPlan? scrapeExport;
  final String? error;

  factory NazaRemoteOperationRequest.digitalOcean({
    required String id,
    required NazaDigitalOceanDropletPlan plan,
    String? host,
  }) {
    final errors = plan.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join(' '));
    return NazaRemoteOperationRequest(
      id: _validId(id),
      kind: NazaRemoteOperationKind.digitalOceanDroplet,
      provider: 'DigitalOcean',
      label: plan.name,
      createdAt: DateTime.now().toUtc(),
      host: _nullable(host),
      droplet: plan,
    );
  }

  factory NazaRemoteOperationRequest.chromiumScrape({
    required String id,
    required NazaChromiumScrapePlan plan,
  }) {
    final errors = plan.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join(' '));
    return NazaRemoteOperationRequest(
      id: _validId(id),
      kind: NazaRemoteOperationKind.chromiumScrape,
      provider: 'Chromium worker',
      label: Uri.parse(plan.targetUrl).host,
      createdAt: DateTime.now().toUtc(),
      scrape: plan,
    );
  }

  factory NazaRemoteOperationRequest.ipfsPublish({
    required String id,
    required NazaIpfsPublicationPlan plan,
  }) {
    final errors = plan.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join(' '));
    return NazaRemoteOperationRequest(
      id: _validId(id),
      kind: NazaRemoteOperationKind.ipfsPublish,
      provider: 'IPFS node mesh',
      label: plan.label,
      createdAt: DateTime.now().toUtc(),
      ipfs: plan,
    );
  }

  factory NazaRemoteOperationRequest.scrapeExport({
    required String id,
    required NazaScrapeExportPlan plan,
  }) {
    final errors = plan.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join(' '));
    return NazaRemoteOperationRequest(
      id: _validId(id),
      kind: NazaRemoteOperationKind.scrapeExportIpfs,
      provider: plan.destination == NazaScrapeExportDestination.localIpfs
          ? 'Local Kubo'
          : 'DigitalOcean IPFS relay',
      label: 'scrape ${plan.scrapeRequestId}',
      createdAt: DateTime.now().toUtc(),
      nodeId: plan.relayNodeId,
      scrapeExport: plan,
    );
  }

  factory NazaRemoteOperationRequest.digitalOceanAction({
    required String id,
    required String dropletId,
    required NazaRemoteOperationKind action,
    required String label,
  }) {
    if (!const <NazaRemoteOperationKind>{
      NazaRemoteOperationKind.digitalOceanDropletStart,
      NazaRemoteOperationKind.digitalOceanDropletStop,
      NazaRemoteOperationKind.digitalOceanDropletDelete,
    }.contains(action)) {
      throw const FormatException('Unsupported DigitalOcean droplet action.');
    }
    if (!_validLabel(label, 120)) {
      throw const FormatException('Droplet action label is invalid.');
    }
    return NazaRemoteOperationRequest(
      id: _validId(id),
      kind: action,
      provider: 'DigitalOcean',
      label: _bounded(label, 120),
      createdAt: DateTime.now().toUtc(),
      nodeId: _validId(dropletId),
    );
  }

  factory NazaRemoteOperationRequest.nodeAction({
    required String id,
    required String nodeId,
    required NazaRemoteOperationKind kind,
    required String label,
  }) {
    if (!const <NazaRemoteOperationKind>{
      NazaRemoteOperationKind.nodeStart,
      NazaRemoteOperationKind.nodeStop,
      NazaRemoteOperationKind.nodeDelete,
    }.contains(kind)) {
      throw const FormatException('Unsupported node operation.');
    }
    return NazaRemoteOperationRequest(
      id: _validId(id),
      kind: kind,
      provider: 'Execution envelope',
      label: _bounded(label, 120),
      createdAt: DateTime.now().toUtc(),
      nodeId: _validId(nodeId),
    );
  }

  NazaRemoteOperationRequest copyWith({
    NazaRemoteOperationState? state,
    String? error,
  }) {
    return NazaRemoteOperationRequest(
      id: id,
      kind: kind,
      provider: provider,
      label: label,
      createdAt: createdAt,
      state: state ?? this.state,
      nodeId: nodeId,
      host: host,
      droplet: droplet,
      scrape: scrape,
      ipfs: ipfs,
      scrapeExport: scrapeExport,
      error: error ?? this.error,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    'provider': provider,
    'label': label,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'state': state.name,
    if (nodeId != null) 'nodeId': nodeId,
    if (host != null) 'host': host,
    if (droplet != null)
      'droplet': <String, Object?>{
        'name': droplet!.name,
        'region': droplet!.region,
        'size': droplet!.size,
        'image': droplet!.image,
        'sshKeyRefs': droplet!.sshKeyRefs,
        'tags': droplet!.tags,
        'backups': droplet!.backups,
        'ipv6': droplet!.ipv6,
        'monitoring': droplet!.monitoring,
        'publicNetworking': droplet!.publicNetworking,
        if (droplet!.vpcUuid != null) 'vpcUuid': droplet!.vpcUuid,
        'workspacePurpose': droplet!.workspacePurpose,
      },
    if (scrape != null) 'scrape': scrape!.toAdapterPlan(),
    if (ipfs != null) 'ipfs': ipfs!.toAdapterPlan(),
    if (scrapeExport != null) 'scrapeExport': scrapeExport!.toAdapterPlan(),
    if (error != null) 'error': _bounded(error!, 300),
  };

  static NazaRemoteOperationRequest? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id']?.toString() ?? '';
    final kind = _enumByName<NazaRemoteOperationKind>(
      value['kind']?.toString(),
      NazaRemoteOperationKind.values,
    );
    final state = _enumByName<NazaRemoteOperationState>(
      value['state']?.toString(),
      NazaRemoteOperationState.values,
    );
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    if (kind == null || state == null || createdAt == null) return null;
    try {
      final dropletValue = value['droplet'];
      final droplet = dropletValue is Map
          ? NazaDigitalOceanDropletPlan(
              name: dropletValue['name']?.toString() ?? '',
              region: dropletValue['region']?.toString() ?? '',
              size: dropletValue['size']?.toString() ?? '',
              image: dropletValue['image']?.toString() ?? '',
              sshKeyRefs: _strings(dropletValue['sshKeyRefs']),
              tags: _strings(dropletValue['tags']),
              backups: dropletValue['backups'] == true,
              ipv6: dropletValue['ipv6'] == true,
              monitoring: dropletValue['monitoring'] != false,
              publicNetworking: dropletValue['publicNetworking'] == true,
              vpcUuid: _nullable(dropletValue['vpcUuid']?.toString()),
              workspacePurpose: _bounded(
                dropletValue['workspacePurpose']?.toString() ??
                    'agentic-sandbox',
                64,
              ),
            )
          : null;
      final scrapeValue = value['scrape'];
      final scrape = scrapeValue is Map
          ? NazaChromiumScrapePlan(
              targetUrl: scrapeValue['targetUrl']?.toString() ?? '',
              allowedDomains: _strings(scrapeValue['allowedDomains']),
              workerNodeId: _nullable(scrapeValue['workerNodeId']?.toString()),
              image: scrapeValue['image']?.toString() ?? '',
              maxPages: (scrapeValue['maxPages'] is num)
                  ? (scrapeValue['maxPages'] as num).round()
                  : 1,
              outputFormat: scrapeValue['outputFormat']?.toString() ?? 'jsonl',
              respectRobots: scrapeValue['respectRobots'] != false,
              allowCookies: scrapeValue['allowCookies'] == true,
              networkApproved: scrapeValue['networkApproved'] == true,
            )
          : null;
      final ipfsValue = value['ipfs'];
      final ipfs = ipfsValue is Map
          ? NazaIpfsPublicationPlan(
              contentCid: ipfsValue['contentCid']?.toString() ?? '',
              label: ipfsValue['label']?.toString() ?? '',
              peerIds: _strings(ipfsValue['peerIds']),
              publiclyDiscoverable: ipfsValue['publiclyDiscoverable'] == true,
              publicExposureApproved:
                  ipfsValue['publicExposureApproved'] == true,
              encryptedPayload: ipfsValue['encryptedPayload'] != false,
            )
          : null;
      final exportValue = value['scrapeExport'];
      final exportDestination = exportValue is Map
          ? _enumByName<NazaScrapeExportDestination>(
              exportValue['destination']?.toString(),
              NazaScrapeExportDestination.values,
            )
          : null;
      final scrapeExport = exportValue is Map
          ? NazaScrapeExportPlan(
              scrapeRequestId: exportValue['scrapeRequestId']?.toString() ?? '',
              destination:
                  exportDestination ?? NazaScrapeExportDestination.localIpfs,
              format: exportValue['format']?.toString() ?? '',
              relayNodeId: _nullable(exportValue['relayNodeId']?.toString()),
              encryptedPayload: exportValue['encryptedPayload'] != false,
              publiclyDiscoverable: exportValue['publiclyDiscoverable'] == true,
              publicExposureApproved:
                  exportValue['publicExposureApproved'] == true,
              maxBytes: exportValue['maxBytes'] is num
                  ? (exportValue['maxBytes'] as num).round()
                  : 64 * 1024 * 1024,
              resultCid: _nullable(exportValue['resultCid']?.toString()),
            )
          : null;
      if (exportValue is Map && exportDestination == null) return null;
      final request = NazaRemoteOperationRequest(
        id: _validId(id),
        kind: kind,
        provider: _bounded(value['provider']?.toString() ?? 'unknown', 80),
        label: _bounded(value['label']?.toString() ?? kind.label, 120),
        createdAt: createdAt.toUtc(),
        state: state,
        nodeId: _nullable(value['nodeId']?.toString()),
        host: _nullable(value['host']?.toString()),
        droplet: droplet,
        scrape: scrape,
        ipfs: ipfs,
        scrapeExport: scrapeExport,
        error: _nullable(value['error']?.toString()),
      );
      if (request.kind == NazaRemoteOperationKind.digitalOceanDroplet &&
          (request.droplet == null || request.droplet!.validate().isNotEmpty)) {
        return null;
      }
      if (request.kind == NazaRemoteOperationKind.chromiumScrape &&
          (request.scrape == null || request.scrape!.validate().isNotEmpty)) {
        return null;
      }
      if (request.kind == NazaRemoteOperationKind.ipfsPublish &&
          (request.ipfs == null || request.ipfs!.validate().isNotEmpty)) {
        return null;
      }
      if (request.kind == NazaRemoteOperationKind.scrapeExportIpfs &&
          (request.scrapeExport == null ||
              request.scrapeExport!.validate().isNotEmpty)) {
        return null;
      }
      return request;
    } on FormatException {
      return null;
    }
  }
}

/// Persistence uses the authenticated vault when it is unlocked. A failed
/// read/write is intentionally surfaced to callers so the UI can explain that
/// the request history is ephemeral instead of pretending it was saved.
final class NazaRemoteOperationsStore {
  NazaRemoteOperationsStore({
    NazaSecureDatabase? database,
    NazaHarmGate? harmGate,
  }) : _database = database ?? NazaSecureDatabase.instance,
       _harmGate = harmGate ?? NazaSentinelGuard.instance.gate;

  static const String _namespace = 'agentic-remote-operations';
  static const String _key = 'requests-v1';
  static const String _harmAuditKey = 'harm-decisions-v1';
  static const int maxRequests = 120;
  static const int maxHarmAuditEntries = 240;

  final NazaSecureDatabase _database;
  final NazaHarmGate _harmGate;
  Future<void> _mutationTail = Future<void>.value();

  Future<List<NazaRemoteOperationRequest>> load() {
    return _mutationTail.then((_) => _loadNow());
  }

  Future<List<NazaRemoteOperationRequest>> _loadNow() async {
    final raw = await _database.readJson(_namespace, _key);
    if (raw is! List) return const <NazaRemoteOperationRequest>[];
    final requests = raw
        .map(NazaRemoteOperationRequest.fromJson)
        .whereType<NazaRemoteOperationRequest>()
        .toList(growable: false);
    return List<NazaRemoteOperationRequest>.unmodifiable(
      requests.length <= maxRequests
          ? requests
          : requests.sublist(requests.length - maxRequests),
    );
  }

  Future<void> append(NazaRemoteOperationRequest request) {
    return _serializeMutation(() => _appendNow(request));
  }

  Future<void> _appendNow(NazaRemoteOperationRequest request) async {
    final errors = _validateRequest(request);
    if (errors.isNotEmpty) throw FormatException(errors.join(' '));
    final current = await _loadNow();
    final matches = current.where((item) => item.id == request.id);
    final existing = matches.isEmpty ? null : matches.first;
    if (existing == null &&
        request.state != NazaRemoteOperationState.awaitingApproval) {
      throw const FormatException(
        'New remote operations must begin awaiting approval.',
      );
    }
    if (existing != null) {
      if (!_sameIntent(existing, request)) {
        throw const FormatException(
          'An approved remote-operation identity cannot be rebound to new intent.',
        );
      }
      final transitionError = _stateTransitionError(
        existing.state,
        request.state,
      );
      if (transitionError != null) throw FormatException(transitionError);
      if (existing.state != request.state &&
          (request.state == NazaRemoteOperationState.approved ||
              request.state == NazaRemoteOperationState.dispatched)) {
        final decision = await _harmGate.assessCommand(
          request.kind.sentinelCommandName,
        );
        await _appendHarmAudit(
          request: request,
          from: existing.state,
          decision: decision,
        );
        if (decision.denied) throw NazaHarmDeniedException(decision);
      }
    }
    final withoutDuplicate = current.where((item) => item.id != request.id);
    final next = <NazaRemoteOperationRequest>[...withoutDuplicate, request];
    final bounded = next.length <= maxRequests
        ? next
        : next.sublist(next.length - maxRequests);
    await _database.writeJson(
      _namespace,
      _key,
      bounded.map((item) => item.toJson()).toList(growable: false),
    );
  }

  Future<void> update(NazaRemoteOperationRequest request) => append(request);

  Future<List<Map<String, Object?>>> loadHarmAudit() {
    return _mutationTail.then((_) => _loadHarmAuditNow());
  }

  Future<List<Map<String, Object?>>> _loadHarmAuditNow() async {
    final raw = await _database.readJson(_namespace, _harmAuditKey);
    if (raw is! List) return const <Map<String, Object?>>[];
    return List<Map<String, Object?>>.unmodifiable(
      raw
          .whereType<Map>()
          .map(
            (entry) => Map<String, Object?>.unmodifiable(<String, Object?>{
              for (final item in entry.entries) item.key.toString(): item.value,
            }),
          )
          .take(maxHarmAuditEntries),
    );
  }

  Future<void> cancel(String id) {
    return _serializeMutation(() async {
      final current = await _loadNow();
      final matches = current.where((item) => item.id == id);
      final existing = matches.isEmpty ? null : matches.first;
      if (existing == null) return;
      if (existing.state != NazaRemoteOperationState.awaitingApproval &&
          existing.state != NazaRemoteOperationState.approved) {
        return;
      }
      await _appendNow(
        existing.copyWith(state: NazaRemoteOperationState.cancelled),
      );
    });
  }

  Future<T> _serializeMutation<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static String? _stateTransitionError(
    NazaRemoteOperationState from,
    NazaRemoteOperationState to,
  ) {
    if (from == to) return null;
    final allowed = switch (from) {
      NazaRemoteOperationState.awaitingApproval =>
        const <NazaRemoteOperationState>{
          NazaRemoteOperationState.approved,
          NazaRemoteOperationState.cancelled,
        },
      NazaRemoteOperationState.approved => const <NazaRemoteOperationState>{
        NazaRemoteOperationState.dispatched,
        NazaRemoteOperationState.cancelled,
      },
      NazaRemoteOperationState.dispatched => const <NazaRemoteOperationState>{
        NazaRemoteOperationState.completed,
        NazaRemoteOperationState.failed,
      },
      NazaRemoteOperationState.completed ||
      NazaRemoteOperationState.failed ||
      NazaRemoteOperationState.cancelled => const <NazaRemoteOperationState>{},
    };
    return allowed.contains(to)
        ? null
        : 'Invalid remote operation transition: ${from.label} → ${to.label}.';
  }

  Future<void> _appendHarmAudit({
    required NazaRemoteOperationRequest request,
    required NazaRemoteOperationState from,
    required NazaHarmDecision decision,
  }) async {
    final current = await _loadHarmAuditNow();
    final entry = <String, Object?>{
      ...decision.toAuditJson(),
      'requestId': request.id,
      'operationKind': request.kind.name,
      'fromState': from.name,
      'toState': request.state.name,
    };
    final next = <Map<String, Object?>>[
      entry,
      ...current,
    ].take(maxHarmAuditEntries).toList(growable: false);
    await _database.writeJson(_namespace, _harmAuditKey, next);
  }

  static bool _sameIntent(
    NazaRemoteOperationRequest existing,
    NazaRemoteOperationRequest replacement,
  ) {
    Map<String, Object?> intent(NazaRemoteOperationRequest request) {
      final value = Map<String, Object?>.from(request.toJson());
      value.remove('state');
      value.remove('error');
      return value;
    }

    return jsonEncode(intent(existing)) == jsonEncode(intent(replacement));
  }

  static List<String> _validateRequest(NazaRemoteOperationRequest request) {
    if (!_isValidId(request.id)) return const <String>['Invalid operation ID.'];
    if (request.kind == NazaRemoteOperationKind.digitalOceanDroplet &&
        (request.droplet == null || request.droplet!.validate().isNotEmpty)) {
      return request.droplet?.validate() ??
          const <String>['Droplet plan is missing.'];
    }
    if (request.kind == NazaRemoteOperationKind.chromiumScrape &&
        (request.scrape == null || request.scrape!.validate().isNotEmpty)) {
      return request.scrape?.validate() ??
          const <String>['Scrape plan is missing.'];
    }
    if (request.kind == NazaRemoteOperationKind.ipfsPublish &&
        (request.ipfs == null || request.ipfs!.validate().isNotEmpty)) {
      return request.ipfs?.validate() ??
          const <String>['IPFS plan is missing.'];
    }
    if (request.kind == NazaRemoteOperationKind.scrapeExportIpfs &&
        (request.scrapeExport == null ||
            request.scrapeExport!.validate().isNotEmpty)) {
      return request.scrapeExport?.validate() ??
          const <String>['Scrape export plan is missing.'];
    }
    if (const <NazaRemoteOperationKind>{
          NazaRemoteOperationKind.nodeStart,
          NazaRemoteOperationKind.nodeStop,
          NazaRemoteOperationKind.nodeDelete,
          NazaRemoteOperationKind.digitalOceanDropletStart,
          NazaRemoteOperationKind.digitalOceanDropletStop,
          NazaRemoteOperationKind.digitalOceanDropletDelete,
        }.contains(request.kind) &&
        (request.nodeId == null || !_isValidId(request.nodeId!))) {
      return const <String>['Node action requires a valid node reference.'];
    }
    return const <String>[];
  }
}

final class NazaRemoteOperationsDefaults {
  NazaRemoteOperationsDefaults._();

  // The upstream Chromium workflow must be built and published with a digest
  // before an adapter can use it. This placeholder is deliberately not valid.
  static const String scraperImage =
      'ghcr.io/ornab74/scraper-chrome-docker@sha256:PIN_REQUIRED';
}

final class NazaAgenticImagePolicy {
  NazaAgenticImagePolicy._();

  static bool isImmutable(String image) {
    return RegExp(r'^[^\s@]+@sha256:[a-fA-F0-9]{64}$').hasMatch(image.trim());
  }
}

String _validId(String value) {
  final clean = value.trim();
  if (!_isValidId(clean)) {
    throw const FormatException('Invalid remote operation identity.');
  }
  return clean;
}

bool _isValidId(String value) => _validIdPattern.hasMatch(value.trim());
final RegExp _validIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{1,95}$');

String _bounded(String value, int max) {
  final clean = value.trim();
  return clean.length <= max ? clean : clean.substring(0, max);
}

String? _nullable(String? value) {
  final clean = value?.trim() ?? '';
  return clean.isEmpty ? null : _bounded(clean, 253);
}

bool _validLabel(String value, int max) {
  final clean = value.trim();
  return clean.isNotEmpty && clean.length <= max && !clean.contains('\u0000');
}

bool _validToken(String value, int max) {
  return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(value.trim()) &&
      value.trim().length <= max;
}

bool _validDomain(String value) {
  final clean = value.trim().toLowerCase();
  return clean.length <= 253 &&
      !clean.contains('/') &&
      !clean.contains('*') &&
      RegExp(
        r'^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?(?::\d{1,5})?$',
      ).hasMatch(clean);
}

bool _sameOrSubdomain(String host, String domain) {
  final cleanHost = host.trim().toLowerCase().split(':').first;
  final cleanDomain = domain.trim().toLowerCase().split(':').first;
  return cleanHost == cleanDomain || cleanHost.endsWith('.$cleanDomain');
}

bool _uuidLike(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value.trim());
}

bool _validCid(String value) {
  final clean = value.trim();
  return clean.length >= 10 &&
      clean.length <= 128 &&
      RegExp(r'^[A-Za-z0-9]+$').hasMatch(clean);
}

bool _validPeerId(String value) {
  final clean = value.trim();
  return clean.length >= 10 &&
      clean.length <= 128 &&
      RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(clean);
}

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return List<String>.unmodifiable(
    value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .take(64),
  );
}

T? _enumByName<T extends Enum>(String? value, List<T> values) {
  if (value == null) return null;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return null;
}
