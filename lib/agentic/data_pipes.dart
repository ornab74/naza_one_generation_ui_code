// Approval-gated remote scraping pipeline plans and encrypted local ingestion.
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';

import '../security/boundary_sanitizer.dart';
import '../security/probabilistic_harm_filter.dart';
import '../security/secure_database.dart';
import '../model/sentinel_model_runtime.dart';
import 'progressive_security_loop.dart';
import 'remote_operations.dart';

enum NazaDataPipeState {
  draft,
  awaitingApproval,
  approved,
  provisioning,
  running,
  importing,
  completed,
  failed,
  cancelled,
}

@immutable
final class NazaDataPipePlan {
  const NazaDataPipePlan({
    required this.id,
    required this.name,
    required this.targetUrl,
    required this.allowedDomains,
    required this.createdAt,
    this.region = 'nyc3',
    this.size = 's-2vcpu-4gb',
    this.maxPages = 10,
    this.respectRobots = true,
    this.state = NazaDataPipeState.awaitingApproval,
    this.image = NazaRemoteOperationsDefaults.scraperImage,
  });
  final String id;
  final String name;
  final String targetUrl;
  final List<String> allowedDomains;
  final String region;
  final String size;
  final int maxPages;
  final bool respectRobots;
  final String image;
  final DateTime createdAt;
  final NazaDataPipeState state;

  List<String> validate() {
    final scrape = scrapePlan;
    return <String>[
      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{2,95}$').hasMatch(id))
        'Invalid pipeline identity.',
      if (name.trim().isEmpty || name.length > 100) 'Pipeline name is invalid.',
      ...scrape.validate(),
      if (!respectRobots) 'Data Pipes requires robots.txt enforcement.',
    ];
  }

  NazaChromiumScrapePlan get scrapePlan => NazaChromiumScrapePlan(
    targetUrl: targetUrl,
    allowedDomains: allowedDomains,
    image: image,
    maxPages: maxPages,
    respectRobots: respectRobots,
    allowCookies: false,
    networkApproved: true,
    outputFormat: 'jsonl',
  );

  NazaDigitalOceanDropletPlan get dropletPlan => NazaDigitalOceanDropletPlan(
    name: 'naza-pipe-$id',
    region: region,
    size: size,
    image: 'ubuntu-24-04-x64',
    tags: const ['naza-data-pipe'],
    monitoring: true,
    publicNetworking: false,
    workspacePurpose: 'ephemeral-secure-scraper',
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'targetUrl': targetUrl,
    'allowedDomains': allowedDomains,
    'region': region,
    'size': size,
    'maxPages': maxPages,
    'respectRobots': respectRobots,
    'image': image,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'state': state.name,
  };
}

@immutable
final class NazaDataPipeArtifact {
  const NazaDataPipeArtifact({
    required this.pipelineId,
    required this.rows,
    required this.sha256,
    required this.receivedAt,
  });
  final String pipelineId;
  final List<Map<String, Object?>> rows;
  final String sha256;
  final DateTime receivedAt;
}

@immutable
final class NazaDataPipeExecutionReceipt {
  const NazaDataPipeExecutionReceipt({
    required this.pipelineId,
    required this.planDigest,
    required this.resultDigest,
    required this.rowCount,
    required this.nodeId,
    required this.startedAt,
    required this.completedAt,
  });
  final String pipelineId;
  final String planDigest;
  final String resultDigest;
  final int rowCount;
  final String nodeId;
  final DateTime startedAt;
  final DateTime completedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'format': 'naza-data-pipe-receipt-v1',
    'pipelineId': pipelineId,
    'planDigest': planDigest,
    'resultDigest': resultDigest,
    'rowCount': rowCount,
    'nodeId': nodeId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'completedAt': completedAt.toUtc().toIso8601String(),
  };
}

abstract interface class NazaDataPipeAdapter {
  /// Implementations obtain credentials directly from the vault. Tokens and
  /// arbitrary model-generated shell text are intentionally absent here.
  Future<String> provision(NazaDigitalOceanDropletPlan plan);
  Future<void> deployPinnedScraper(String nodeId, NazaChromiumScrapePlan plan);
  Future<List<int>> runAndFetch(String nodeId, NazaChromiumScrapePlan plan);
  Future<void> destroyEphemeralNode(String nodeId);
}

final class NazaDataPipeStore {
  NazaDataPipeStore({NazaSecureDatabase? database})
    : _database = database ?? NazaSecureDatabase.instance;
  final NazaSecureDatabase _database;
  static const _namespace = 'data-pipes';
  static const _plans = 'plans-v1';
  static const _results = 'encrypted-results-v1';

  Future<void> savePlan(NazaDataPipePlan plan) async {
    final errors = plan.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join(' '));
    final raw = await _database.readJson(_namespace, _plans);
    final list = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, Object?>.from(e)).toList()
        : <Map<String, Object?>>[];
    list.removeWhere((value) => value['id'] == plan.id);
    list.add(plan.toJson());
    await _database.writeJson(
      _namespace,
      _plans,
      list.length <= 64 ? list : list.sublist(list.length - 64),
    );
  }

  Future<void> importArtifact(NazaDataPipeArtifact artifact) async {
    if (artifact.rows.length > 10000 || artifact.sha256.length != 64)
      throw const FormatException('Scrape artifact exceeded ingestion policy.');
    final cleanRows = artifact.rows
        .map(
          (row) => <String, Object?>{
            for (final entry in row.entries.take(64))
              NazaBoundarySanitizer.databaseText(
                entry.key,
                maxCharacters: 80,
              ): NazaBoundarySanitizer.databaseText(
                entry.value?.toString() ?? '',
                maxCharacters: 8000,
              ),
          },
        )
        .toList(growable: false);
    await _database.writeJson(_namespace, '$_results:${artifact.pipelineId}', {
      'pipelineId': artifact.pipelineId,
      'sha256': artifact.sha256,
      'receivedAt': artifact.receivedAt.toUtc().toIso8601String(),
      'rows': cleanRows,
    });
  }

  Future<void> saveReceipt(NazaDataPipeExecutionReceipt receipt) async {
    final digest = RegExp(r'^[a-f0-9]{64}$');
    if (receipt.pipelineId.trim().isEmpty ||
        !digest.hasMatch(receipt.planDigest) ||
        !digest.hasMatch(receipt.resultDigest) ||
        receipt.rowCount < 0 ||
        receipt.rowCount > 10000 ||
        receipt.nodeId.trim().isEmpty ||
        receipt.completedAt.isBefore(receipt.startedAt)) {
      throw const FormatException(
        'The Data Pipes execution receipt is invalid.',
      );
    }
    await _database.writeJson(
      _namespace,
      'receipt:${receipt.pipelineId}',
      receipt.toJson(),
    );
  }
}

final class NazaDataPipeOrchestrator {
  NazaDataPipeOrchestrator({
    required this.adapter,
    NazaHarmGate? harmGate,
    NazaDataPipeStore? store,
  }) : _harmGate = harmGate ?? NazaSentinelGuard.instance.gate,
       _store = store ?? NazaDataPipeStore();
  final NazaDataPipeAdapter adapter;
  final NazaHarmGate _harmGate;
  final NazaDataPipeStore _store;
  final _scanner = const NazaProgressiveSecurityLoop();

  Future<NazaDataPipeArtifact> execute(
    NazaDataPipePlan plan, {
    required bool userApproved,
  }) async {
    if (!userApproved || plan.validate().isNotEmpty)
      throw StateError('A valid, explicitly approved pipeline is required.');
    final manifest = jsonEncode({
      'droplet': plan.dropletPlan.toApiPayload(),
      'scrape': plan.scrapePlan.toAdapterPlan(),
    });
    final review = _scanner.review(manifest);
    if (review.denied)
      throw StateError(
        'Progressive security review denied the pipeline manifest.',
      );
    String? nodeId;
    final startedAt = DateTime.now().toUtc();
    final planDigest = crypto.sha256
        .convert(utf8.encode(jsonEncode(plan.toJson())))
        .toString();
    try {
      await _harmGate.requireAllowed('digitalocean.droplet.create');
      nodeId = await adapter.provision(plan.dropletPlan);
      await _harmGate.requireAllowed('container.scraper.deploy');
      await adapter.deployPinnedScraper(nodeId, plan.scrapePlan);
      await _harmGate.requireAllowed('container.chromium.scrape');
      final bytes = await adapter.runAndFetch(nodeId, plan.scrapePlan);
      if (bytes.length > 64 * 1024 * 1024)
        throw StateError('Scrape result exceeded 64 MiB.');
      final decoded = const Utf8Decoder(allowMalformed: false).convert(bytes);
      final outputReview = _scanner.review(decoded);
      if (outputReview.denied) {
        throw StateError(
          'Progressive security review denied hostile scraper output.',
        );
      }
      final rows = const LineSplitter()
          .convert(decoded)
          .where((line) => line.trim().isNotEmpty)
          .take(10000)
          .map((line) {
            final value = jsonDecode(line);
            if (value is! Map)
              throw const FormatException('Every JSONL row must be an object.');
            return <String, Object?>{
              for (final entry in value.entries)
                entry.key.toString(): entry.value,
            };
          })
          .toList(growable: false);
      final artifact = NazaDataPipeArtifact(
        pipelineId: plan.id,
        rows: rows,
        sha256: crypto.sha256.convert(bytes).toString(),
        receivedAt: DateTime.now().toUtc(),
      );
      await _store.importArtifact(artifact);
      await _store.saveReceipt(
        NazaDataPipeExecutionReceipt(
          pipelineId: plan.id,
          planDigest: planDigest,
          resultDigest: artifact.sha256,
          rowCount: artifact.rows.length,
          nodeId: nodeId,
          startedAt: startedAt,
          completedAt: DateTime.now().toUtc(),
        ),
      );
      return artifact;
    } finally {
      if (nodeId != null) {
        await _harmGate.requireAllowed('digitalocean.droplet.delete');
        await adapter.destroyEphemeralNode(nodeId);
      }
    }
  }
}
