import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../security/secure_database.dart';
import 'models.dart';
import 'photo_picker.dart';

typedef ShelfVisionAnalyzer =
    Future<FridgeAnalysis> Function(FoodVisionImage image, String note);

enum ShelfRiskLevel {
  low,
  medium,
  high;

  String get label => switch (this) {
    ShelfRiskLevel.low => 'Low',
    ShelfRiskLevel.medium => 'Medium',
    ShelfRiskLevel.high => 'High',
  };

  int get severity => switch (this) {
    ShelfRiskLevel.low => 0,
    ShelfRiskLevel.medium => 1,
    ShelfRiskLevel.high => 2,
  };

  static ShelfRiskLevel parse(Object? value) => switch (
        value?.toString().trim().toLowerCase()) {
      'high' => ShelfRiskLevel.high,
      'medium' => ShelfRiskLevel.medium,
      _ => ShelfRiskLevel.low,
    };
}

final class ShelfItem {
  final String id;
  final String name;
  final String approximateQuantity;
  final List<String> visibleCues;
  final FoodConfidence confidence;
  final bool interested;
  final ShelfRiskLevel? risk;
  final String riskReason;
  final List<String> uncertainties;

  const ShelfItem({
    required this.id,
    required this.name,
    required this.approximateQuantity,
    required this.visibleCues,
    required this.confidence,
    this.interested = false,
    this.risk,
    this.riskReason = '',
    this.uncertainties = const <String>[],
  });

  ShelfItem copyWith({
    bool? interested,
    ShelfRiskLevel? risk,
    bool clearRisk = false,
    String? riskReason,
    List<String>? uncertainties,
  }) {
    return ShelfItem(
      id: id,
      name: name,
      approximateQuantity: approximateQuantity,
      visibleCues: visibleCues,
      confidence: confidence,
      interested: interested ?? this.interested,
      risk: clearRisk ? null : (risk ?? this.risk),
      riskReason: riskReason ?? this.riskReason,
      uncertainties: uncertainties ?? this.uncertainties,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'approximate_quantity': approximateQuantity,
        'visible_cues': visibleCues,
        'confidence': confidence.name,
        'interested': interested,
        if (risk != null) 'risk': risk!.name,
        'risk_reason': riskReason,
        'uncertainties': uncertainties,
      };

  factory ShelfItem.fromJson(Map<String, Object?> json) {
    final rawCues = json['visible_cues'];
    final rawUncertainties = json['uncertainties'];
    return ShelfItem(
      id: _safeText(json['id'], 100, fallback: _newShelfId('item')),
      name: _safeText(json['name'], 140, fallback: 'Unidentified item'),
      approximateQuantity: _safeText(
        json['approximate_quantity'],
        100,
        fallback: 'Quantity unclear',
      ),
      visibleCues: _safeStringList(rawCues, 8, 220),
      confidence: FoodConfidence.parse(json['confidence']),
      interested: json['interested'] == true,
      risk: json['risk'] == null ? null : ShelfRiskLevel.parse(json['risk']),
      riskReason: _safeText(json['risk_reason'], 700),
      uncertainties: _safeStringList(rawUncertainties, 12, 260),
    );
  }
}

final class ShelfComparison {
  final String id;
  final String leftItemId;
  final String rightItemId;
  final String? recommendedItemId;
  final String summary;
  final DateTime createdAt;

  const ShelfComparison({
    required this.id,
    required this.leftItemId,
    required this.rightItemId,
    required this.recommendedItemId,
    required this.summary,
    required this.createdAt,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'left_item_id': leftItemId,
        'right_item_id': rightItemId,
        if (recommendedItemId != null)
          'recommended_item_id': recommendedItemId,
        'summary': summary,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory ShelfComparison.fromJson(Map<String, Object?> json) {
    return ShelfComparison(
      id: _safeText(json['id'], 100, fallback: _newShelfId('compare')),
      leftItemId: _safeText(json['left_item_id'], 100),
      rightItemId: _safeText(json['right_item_id'], 100),
      recommendedItemId: json['recommended_item_id']?.toString(),
      summary: _safeText(json['summary'], 1200),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

final class ShelfScanRecord {
  static const String format = 'naza-shelf-scan-v1';

  final String id;
  final DateTime capturedAt;
  final FoodVisionImage image;
  final String note;
  final List<ShelfItem> items;
  final List<ShelfComparison> comparisons;

  const ShelfScanRecord({
    required this.id,
    required this.capturedAt,
    required this.image,
    required this.note,
    required this.items,
    required this.comparisons,
  });

  ShelfScanRecord copyWith({
    List<ShelfItem>? items,
    List<ShelfComparison>? comparisons,
  }) {
    return ShelfScanRecord(
      id: id,
      capturedAt: capturedAt,
      image: image,
      note: note,
      items: items ?? this.items,
      comparisons: comparisons ?? this.comparisons,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'format': format,
        'id': id,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'image': image.toJson(),
        'note': note,
        'items': items.map((item) => item.toJson()).toList(growable: false),
        'comparisons': comparisons
            .map((item) => item.toJson())
            .toList(growable: false),
      };

  factory ShelfScanRecord.fromJson(Map<String, Object?> json) {
    if (json['format'] != format) {
      throw const FormatException('Unsupported shelf scan format.');
    }
    final rawItems = json['items'];
    final rawComparisons = json['comparisons'];
    return ShelfScanRecord(
      id: _safeText(json['id'], 100, fallback: _newShelfId('shelf')),
      capturedAt: DateTime.tryParse(json['captured_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      image: FoodVisionImage.fromJson(
        Map<String, Object?>.from(json['image'] as Map? ?? const {}),
      ),
      note: _safeText(json['note'], 1200),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .take(80)
              .map((entry) => ShelfItem.fromJson(
                    Map<String, Object?>.from(entry),
                  ))
              .toList(growable: false)
          : const <ShelfItem>[],
      comparisons: rawComparisons is List
          ? rawComparisons
              .whereType<Map>()
              .take(40)
              .map((entry) => ShelfComparison.fromJson(
                    Map<String, Object?>.from(entry),
                  ))
              .toList(growable: false)
          : const <ShelfComparison>[],
    );
  }
}

abstract interface class ShelfRepository {
  ValueNotifier<int> get revision;

  Future<void> save(ShelfScanRecord record);

  Future<List<ShelfScanRecord>> list({int limit = 20});

  Future<void> clear();
}

/// Shelf scans are stored as independent authenticated records inside the
/// existing encrypted vault. The index contains only record IDs and UTC times.
final class EncryptedShelfRepository implements ShelfRepository {
  EncryptedShelfRepository({
    NazaSecureDatabase? database,
    this.retention = 24,
  }) : _database = database ?? NazaSecureDatabase.instance {
    if (retention < 1 || retention > 100) {
      throw ArgumentError.value(retention, 'retention');
    }
  }

  static const String _namespace = 'food.shelf.v1';
  static const String _indexKey = 'index';
  static const String _entryPrefix = 'entry:';

  final NazaSecureDatabase _database;
  final int retention;
  Future<void> _tail = Future<void>.value();

  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  @override
  Future<void> save(ShelfScanRecord record) {
    return _enqueue(() async {
      final index = await _readIndex();
      final entries = <Map<String, Object?>>[
        <String, Object?>{
          'id': record.id,
          'captured_at': record.capturedAt.toUtc().toIso8601String(),
        },
        ...index.where((entry) => entry['id'] != record.id),
      ]..sort((a, b) => b['captured_at']
          .toString()
          .compareTo(a['captured_at'].toString()));
      final kept = entries.take(retention).toList(growable: false);
      final keptIds = kept.map((entry) => entry['id'].toString()).toSet();
      final pruned = entries
          .map((entry) => entry['id'].toString())
          .where((id) => !keptIds.contains(id));

      await _database.importRecords(<NazaVaultRecordKey, Object?>{
        NazaVaultRecordKey(_namespace, '$_entryPrefix${record.id}'):
            record.toJson(),
        const NazaVaultRecordKey(_namespace, _indexKey): <String, Object?>{
          'format': 'naza-shelf-index-v1',
          'entries': kept,
        },
      });
      for (final id in pruned) {
        await _database.delete(_namespace, '$_entryPrefix$id');
      }
      revision.value++;
    });
  }

  @override
  Future<List<ShelfScanRecord>> list({int limit = 20}) {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit');
    }
    return _enqueue(() async {
      final index = await _readIndex();
      final result = <ShelfScanRecord>[];
      for (final entry in index.take(limit)) {
        final id = entry['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final raw = await _database.readJson(_namespace, '$_entryPrefix$id');
        if (raw is! Map) continue;
        try {
          result.add(ShelfScanRecord.fromJson(
            Map<String, Object?>.from(raw),
          ));
        } catch (error) {
          throw NazaVaultException(
            'invalid_shelf_scan',
            'An encrypted shelf scan is malformed.',
            error,
          );
        }
      }
      return List<ShelfScanRecord>.unmodifiable(result);
    });
  }

  @override
  Future<void> clear() {
    return _enqueue(() async {
      final index = await _readIndex();
      for (final entry in index) {
        final id = entry['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          await _database.delete(_namespace, '$_entryPrefix$id');
        }
      }
      await _database.delete(_namespace, _indexKey);
      revision.value++;
    });
  }

  Future<List<Map<String, Object?>>> _readIndex() async {
    final raw = await _database.readJson(_namespace, _indexKey);
    if (raw == null) return <Map<String, Object?>>[];
    if (raw is! Map || raw['format'] != 'naza-shelf-index-v1') {
      throw const NazaVaultException(
        'invalid_shelf_index',
        'The encrypted shelf index is malformed.',
      );
    }
    final entries = raw['entries'];
    if (entries is! List) return <Map<String, Object?>>[];
    return entries
        .whereType<Map>()
        .take(100)
        .map((entry) => Map<String, Object?>.from(entry))
        .toList(growable: false);
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final queued = _tail.then((_) => operation());
    _tail = queued.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return queued;
  }
}

final class MemoryShelfRepository implements ShelfRepository {
  final Map<String, ShelfScanRecord> _records = <String, ShelfScanRecord>{};

  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  @override
  Future<void> save(ShelfScanRecord record) async {
    _records[record.id] = record;
    revision.value++;
  }

  @override
  Future<List<ShelfScanRecord>> list({int limit = 20}) async {
    final values = _records.values.toList(growable: false)
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return List<ShelfScanRecord>.unmodifiable(values.take(limit));
  }

  @override
  Future<void> clear() async {
    _records.clear();
    revision.value++;
  }
}

/// Dedicated grocery shelf scanner. It deliberately distinguishes visual/model
/// evidence from a real-world product-safety verdict: Low/Medium/High below is
/// a review-risk label for the currently visible evidence, not pathogen,
/// contamination, recall, or regulatory status.
final class ShelfScannerPane extends StatefulWidget {
  final ShelfRepository repository;
  final FoodPhotoPicker photoPicker;
  final ShelfVisionAnalyzer analyzeVision;
  final VoidCallback? onCancel;

  const ShelfScannerPane({
    super.key,
    required this.repository,
    required this.photoPicker,
    required this.analyzeVision,
    this.onCancel,
  });

  @override
  State<ShelfScannerPane> createState() => _ShelfScannerPaneState();
}

class _ShelfScannerPaneState extends State<ShelfScannerPane> {
  final TextEditingController _note = TextEditingController();
  FoodVisionImage? _image;
  ShelfScanRecord? _record;
  final Set<String> _compareIds = <String>{};
  bool _busy = false;
  bool _started = false;
  String _status = 'Ready to scan a grocery shelf';

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    if (_busy) return;
    final source = await _chooseSource(context);
    if (source == null || !mounted) return;
    setState(() {
      _busy = true;
      _status = 'Preparing photo securely';
    });
    final result = await widget.photoPicker.pick(source);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.selected) {
        _image = result.image;
        _record = null;
        _compareIds.clear();
        _status = 'Photo normalized locally; original metadata discarded';
      } else {
        _status = result.message ??
            (result.outcome == FoodPhotoPickOutcome.cancelled
                ? 'Photo selection cancelled'
                : 'Photo unavailable');
      }
    });
  }

  Future<void> _scanShelf() async {
    final image = _image;
    if (_busy || image == null) return;
    setState(() {
      _busy = true;
      _status = 'Finding visible shelf items locally';
    });
    try {
      final note = _note.text.trim();
      final analysis = await widget.analyzeVision(
        image,
        '''GROCERY SHELF INVENTORY MODE. Treat the scene as a retail shelf, not a fridge. List only products visibly supported by the image. Preserve brand/product wording only when readable. Do not invent prices, recalls, expiration dates, ingredients, allergens, pathogens, or package contents. User note: $note''',
      );
      if (!mounted) return;
      final seen = <String, int>{};
      final items = <ShelfItem>[];
      for (final observation in analysis.items.take(60)) {
        final base = _slug(observation.name);
        final ordinal = (seen[base] ?? 0) + 1;
        seen[base] = ordinal;
        items.add(ShelfItem(
          id: '$base-$ordinal',
          name: observation.name,
          approximateQuantity: observation.approximateQuantity,
          visibleCues: observation.visibleCues,
          confidence: observation.confidence,
          uncertainties: analysis.uncertainties,
        ));
      }
      final record = ShelfScanRecord(
        id: _newShelfId('shelf'),
        capturedAt: DateTime.now().toUtc(),
        image: image,
        note: note,
        items: List<ShelfItem>.unmodifiable(items),
        comparisons: const <ShelfComparison>[],
      );
      await widget.repository.save(record);
      if (!mounted) return;
      setState(() {
        _record = record;
        _busy = false;
        _status = items.isEmpty
            ? 'No products were confidently structured from this image'
            : '${items.length} visible product${items.length == 1 ? '' : 's'} saved encrypted';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Shelf scan failed: $error';
      });
    }
  }

  void _setInterested(String id, bool value) {
    final record = _record;
    if (record == null || _busy) return;
    final items = record.items
        .map((item) => item.id == id ? item.copyWith(interested: value) : item)
        .toList(growable: false);
    final updated = record.copyWith(items: List<ShelfItem>.unmodifiable(items));
    setState(() => _record = updated);
    unawaited(widget.repository.save(updated));
  }

  Future<void> _riskSelected() async {
    final record = _record;
    if (_busy || record == null) return;
    final selected = record.items.where((item) => item.interested).toList();
    if (selected.isEmpty) {
      setState(() => _status = 'Check at least one item you are interested in');
      return;
    }
    setState(() => _busy = true);
    var working = record;
    try {
      for (var index = 0; index < selected.length; index++) {
        final target = selected[index];
        if (!mounted) return;
        setState(() {
          _status =
              'Reviewing ${index + 1}/${selected.length}: ${target.name}';
        });
        final analysis = await widget.analyzeVision(
          record.image,
          '''SHELF ITEM REVIEW MODE. Focus only on the visible product named "${target.name}". Return only evidence supportable from the image. Pay special attention to package integrity, visible damage/opening/leak/swelling, readable storage/handling cues, and uncertainty. Do NOT claim pathogens, recalls, contamination, expiration, nutrition, ingredients, or allergen facts unless directly readable in the supplied image.''',
        );
        final focused = _closestObservation(analysis.items, target.name);
        final risk = _deriveReviewRisk(
          focused ??
              FridgeItemObservation(
                name: target.name,
                approximateQuantity: target.approximateQuantity,
                location: 'Retail shelf',
                visibleCues: target.visibleCues,
                useWindow: 'Verify package and label',
                confidence: target.confidence,
              ),
          analysis,
        );
        final reason = _riskReason(risk, focused, analysis);
        final updatedItems = working.items
            .map((item) => item.id == target.id
                ? item.copyWith(
                    risk: risk,
                    riskReason: reason,
                    uncertainties: analysis.uncertainties,
                  )
                : item)
            .toList(growable: false);
        working = working.copyWith(
          items: List<ShelfItem>.unmodifiable(updatedItems),
        );
        await widget.repository.save(working);
      }
      if (!mounted) return;
      setState(() {
        _record = working;
        _busy = false;
        _status = 'Selected-item review complete and encrypted';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _record = working;
        _busy = false;
        _status = 'Item review stopped: $error';
      });
    }
  }

  void _toggleCompare(String id, bool selected) {
    if (_busy) return;
    setState(() {
      if (selected) {
        if (_compareIds.length < 2) _compareIds.add(id);
      } else {
        _compareIds.remove(id);
      }
    });
  }

  Future<void> _compare() async {
    final record = _record;
    if (_busy || record == null || _compareIds.length != 2) {
      if (record != null && _compareIds.length != 2) {
        setState(() => _status = 'Choose exactly two similar items to compare');
      }
      return;
    }
    final pair = record.items
        .where((item) => _compareIds.contains(item.id))
        .toList(growable: false);
    if (pair.length != 2) return;
    setState(() {
      _busy = true;
      _status = 'Running local two-item comparison';
    });
    try {
      final analysis = await widget.analyzeVision(
        record.image,
        '''SHELF COMPARISON MODE. Compare only "${pair[0].name}" and "${pair[1].name}" using evidence visibly supported by this shelf image. Discuss clearly readable packaging/handling cues and uncertainty. Do not invent price, nutrition, ingredients, recalls, pathogens, contamination, expiration, or hidden attributes. If the image cannot support a preference, say so.''',
      );
      final recommendation = _recommend(pair[0], pair[1]);
      final summary = analysis.summary.trim().isEmpty
          ? _comparisonFallback(pair[0], pair[1], recommendation)
          : '${analysis.summary.trim()}\n\n${_comparisonFallback(pair[0], pair[1], recommendation)}';
      final comparison = ShelfComparison(
        id: _newShelfId('compare'),
        leftItemId: pair[0].id,
        rightItemId: pair[1].id,
        recommendedItemId: recommendation?.id,
        summary: summary,
        createdAt: DateTime.now().toUtc(),
      );
      final updated = record.copyWith(
        comparisons: List<ShelfComparison>.unmodifiable(<ShelfComparison>[
          comparison,
          ...record.comparisons,
        ]),
      );
      await widget.repository.save(updated);
      if (!mounted) return;
      setState(() {
        _record = updated;
        _busy = false;
        _status = recommendation == null
            ? 'Comparison saved; no evidence-backed winner'
            : 'Comparison saved; ${recommendation.name} suggested';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Comparison failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final record = _record;
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 24,
            16,
            compact ? 12 : 24,
            32,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _ShelfHero(
                      started: _started,
                      busy: _busy,
                      status: _status,
                      onStart: () => setState(() => _started = true),
                      onStop: _busy && widget.onCancel != null
                          ? widget.onCancel
                          : null,
                    ),
                    const SizedBox(height: 14),
                    if (!_started)
                      _ShelfStartCard(
                        onStart: () => setState(() => _started = true),
                      )
                    else ...<Widget>[
                      _ShelfCaptureCard(
                        image: _image,
                        busy: _busy,
                        note: _note,
                        onPhoto: _choosePhoto,
                        onClear: _busy
                            ? null
                            : () => setState(() {
                                  _image = null;
                                  _record = null;
                                  _compareIds.clear();
                                }),
                        onScan: _image == null || _busy ? null : _scanShelf,
                      ),
                      if (record != null) ...<Widget>[
                        const SizedBox(height: 14),
                        _ShelfInterestCard(
                          items: record.items,
                          busy: _busy,
                          onChanged: _setInterested,
                          onRiskSelected: _riskSelected,
                        ),
                        const SizedBox(height: 14),
                        _ShelfCompareCard(
                          record: record,
                          selected: _compareIds,
                          busy: _busy,
                          onToggle: _toggleCompare,
                          onCompare: _compare,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _ShelfHero extends StatelessWidget {
  final bool started;
  final bool busy;
  final String status;
  final VoidCallback onStart;
  final VoidCallback? onStop;

  const _ShelfHero({
    required this.started,
    required this.busy,
    required this.status,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Theme.of(context).colorScheme.primary.withAlpha(28),
          ),
          child: const Icon(Icons.shelves, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Shelf Scanner',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                status,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (!started)
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start'),
          )
        else if (busy && onStop != null)
          FilledButton.tonalIcon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop'),
          ),
      ],
    );
  }
}

final class _ShelfStartCard extends StatelessWidget {
  final VoidCallback onStart;

  const _ShelfStartCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: <Widget>[
            const Icon(Icons.document_scanner_outlined, size: 46),
            const SizedBox(height: 12),
            Text(
              'Scan a shelf into your private grocery workspace',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Products are listed locally, chosen items can be reviewed one-by-one, and two similar products can be compared. Shelf images and results stay in the encrypted vault.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start shelf scanner'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ShelfCaptureCard extends StatelessWidget {
  final FoodVisionImage? image;
  final bool busy;
  final TextEditingController note;
  final VoidCallback onPhoto;
  final VoidCallback? onClear;
  final VoidCallback? onScan;

  const _ShelfCaptureCard({
    required this.image,
    required this.busy,
    required this.note,
    required this.onPhoto,
    required this.onClear,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final current = image;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.photo_camera_back_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Photo scanner',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(current == null ? 'Picture' : 'Replace'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (current != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 8,
                  child: Image.memory(
                    current.bytes,
                    fit: BoxFit.cover,
                    cacheWidth: 1280,
                  ),
                ),
              )
            else
              Container(
                height: 160,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withAlpha(120),
                  ),
                ),
                child: const Text('No shelf photo selected'),
              ),
            if (current != null) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${current.name} • ${current.dimensions}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: note,
              enabled: !busy,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Optional shelf note',
                hintText: 'Cereal aisle, sparkling water, protein bars…',
              ),
            ),
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.document_scanner_rounded),
              label: Text(busy ? 'Scanning locally…' : 'Scan visible shelf'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ShelfInterestCard extends StatelessWidget {
  final List<ShelfItem> items;
  final bool busy;
  final void Function(String id, bool value) onChanged;
  final VoidCallback onRiskSelected;

  const _ShelfInterestCard({
    required this.items,
    required this.busy,
    required this.onChanged,
    required this.onRiskSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCount = items.where((item) => item.interested).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.checklist_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Interested items',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy || selectedCount == 0 ? null : onRiskSelected,
                  icon: const Icon(Icons.health_and_safety_outlined),
                  label: Text('Review $selectedCount'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Check products you care about. Naza reviews them sequentially so one model result cannot silently overwrite another.',
            ),
            const SizedBox(height: 10),
            for (final item in items)
              _ShelfItemTile(
                item: item,
                busy: busy,
                onChanged: (value) => onChanged(item.id, value),
              ),
          ],
        ),
      ),
    );
  }
}

final class _ShelfItemTile extends StatelessWidget {
  final ShelfItem item;
  final bool busy;
  final ValueChanged<bool> onChanged;

  const _ShelfItemTile({
    required this.item,
    required this.busy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final risk = item.risk;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: CheckboxListTile(
        value: item.interested,
        onChanged: busy ? null : (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (risk != null) _RiskChip(risk: risk),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${item.approximateQuantity} • ${item.confidence.label} visual confidence',
            ),
            if (item.visibleCues.isNotEmpty)
              Text(
                item.visibleCues.join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (item.riskReason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(item.riskReason),
              ),
          ],
        ),
      ),
    );
  }
}

final class _RiskChip extends StatelessWidget {
  final ShelfRiskLevel risk;

  const _RiskChip({required this.risk});

  @override
  Widget build(BuildContext context) {
    final color = switch (risk) {
      ShelfRiskLevel.low => Colors.greenAccent,
      ShelfRiskLevel.medium => Colors.amberAccent,
      ShelfRiskLevel.high => Colors.redAccent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        risk.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

final class _ShelfCompareCard extends StatelessWidget {
  final ShelfScanRecord record;
  final Set<String> selected;
  final bool busy;
  final void Function(String id, bool selected) onToggle;
  final VoidCallback onCompare;

  const _ShelfCompareCard({
    required this.record,
    required this.selected,
    required this.busy,
    required this.onToggle,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.compare_arrows_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Compare two',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: busy || selected.length != 2 ? null : onCompare,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Compare'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose exactly two similar products. The model supplies a bounded visual comparison; recommendation logic prefers lower review risk and stronger visual confidence.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final item in record.items)
                  FilterChip(
                    selected: selected.contains(item.id),
                    onSelected: busy ||
                            (!selected.contains(item.id) && selected.length >= 2)
                        ? null
                        : (value) => onToggle(item.id, value),
                    label: Text(item.name),
                  ),
              ],
            ),
            if (record.comparisons.isNotEmpty) ...<Widget>[
              const Divider(height: 28),
              for (final comparison in record.comparisons.take(4))
                _ComparisonResult(record: record, comparison: comparison),
            ],
          ],
        ),
      ),
    );
  }
}

final class _ComparisonResult extends StatelessWidget {
  final ShelfScanRecord record;
  final ShelfComparison comparison;

  const _ComparisonResult({required this.record, required this.comparison});

  @override
  Widget build(BuildContext context) {
    final recommended = _byId(record.items, comparison.recommendedItemId);
    final left = _byId(record.items, comparison.leftItemId);
    final right = _byId(record.items, comparison.rightItemId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${left?.name ?? 'Item A'} vs ${right?.name ?? 'Item B'}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          if (recommended != null)
            Text(
              'Suggested: ${recommended.name}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            )
          else
            const Text('No evidence-backed winner.'),
          const SizedBox(height: 4),
          Text(comparison.summary),
        ],
      ),
    );
  }
}

Future<FoodPhotoSource?> _chooseSource(BuildContext context) {
  return showModalBottomSheet<FoodPhotoSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Photo scanner',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Naza decodes and re-encodes the selected image locally; original EXIF/GPS metadata is not retained in the scanner image.',
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Camera'),
              subtitle: const Text('Take a new picture'),
              onTap: () => Navigator.pop(context, FoodPhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo library'),
              subtitle: const Text('Use the system photo picker'),
              onTap: () => Navigator.pop(context, FoodPhotoSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('Files'),
              subtitle: const Text('Choose JPG, PNG, or WebP from files'),
              onTap: () => Navigator.pop(context, FoodPhotoSource.files),
            ),
          ],
        ),
      ),
    ),
  );
}

ShelfRiskLevel _deriveReviewRisk(
  FridgeItemObservation item,
  FridgeAnalysis analysis,
) {
  final evidence = <String>[
    ...item.visibleCues,
    item.useWindow,
    ...analysis.uncertainties,
  ].join(' ').toLowerCase();
  const highSignals = <String>[
    'leak',
    'leaking',
    'swollen',
    'bulging',
    'mold',
    'mould',
    'torn',
    'open package',
    'broken seal',
    'damaged seal',
    'puncture',
  ];
  if (highSignals.any(evidence.contains)) return ShelfRiskLevel.high;
  if (analysis.status != FoodAnalysisStatus.complete ||
      item.confidence == FoodConfidence.low ||
      analysis.uncertainties.isNotEmpty) {
    return ShelfRiskLevel.medium;
  }
  if (item.confidence == FoodConfidence.medium) return ShelfRiskLevel.medium;
  return ShelfRiskLevel.low;
}

String _riskReason(
  ShelfRiskLevel risk,
  FridgeItemObservation? item,
  FridgeAnalysis analysis,
) {
  final cues = item?.visibleCues ?? const <String>[];
  return switch (risk) {
    ShelfRiskLevel.high =>
      'High review risk: visible/model-structured cues may indicate package damage or another condition that needs direct inspection. This is not a pathogen or recall determination.',
    ShelfRiskLevel.medium =>
      'Medium review risk: evidence is incomplete or visually uncertain${cues.isEmpty ? '' : ' (${cues.take(2).join(' • ')})'}. Verify the package and label directly.',
    ShelfRiskLevel.low =>
      'Low review risk from the visible evidence only. This does not establish freshness, contamination status, recall status, allergens, or hidden package condition.',
  };
}

ShelfItem? _recommend(ShelfItem a, ShelfItem b) {
  final aRisk = a.risk?.severity ?? 1;
  final bRisk = b.risk?.severity ?? 1;
  if (aRisk != bRisk) return aRisk < bRisk ? a : b;
  final aConfidence = _confidenceScore(a.confidence);
  final bConfidence = _confidenceScore(b.confidence);
  if (aConfidence != bConfidence) return aConfidence > bConfidence ? a : b;
  return null;
}

String _comparisonFallback(ShelfItem a, ShelfItem b, ShelfItem? recommended) {
  final aRisk = a.risk?.label ?? 'Not reviewed';
  final bRisk = b.risk?.label ?? 'Not reviewed';
  if (recommended == null) {
    return '${a.name}: $aRisk review risk. ${b.name}: $bRisk review risk. The available visible evidence does not justify a unique recommendation; compare price, ingredients, nutrition, allergens, and labels directly.';
  }
  return '${a.name}: $aRisk review risk. ${b.name}: $bRisk review risk. Suggested ${recommended.name} because its currently structured visible evidence is lower-risk or higher-confidence. Verify product facts on the actual label before purchasing.';
}

FridgeItemObservation? _closestObservation(
  List<FridgeItemObservation> items,
  String target,
) {
  if (items.isEmpty) return null;
  final words = target.toLowerCase().split(RegExp(r'\W+')).where((e) => e.isNotEmpty).toSet();
  FridgeItemObservation? best;
  var bestScore = -1;
  for (final item in items) {
    final itemWords = item.name
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((e) => e.isNotEmpty)
        .toSet();
    final score = itemWords.intersection(words).length;
    if (score > bestScore) {
      best = item;
      bestScore = score;
    }
  }
  return best;
}

int _confidenceScore(FoodConfidence confidence) => switch (confidence) {
      FoodConfidence.low => 0,
      FoodConfidence.medium => 1,
      FoodConfidence.high => 2,
    };

ShelfItem? _byId(List<ShelfItem> items, String? id) {
  if (id == null) return null;
  for (final item in items) {
    if (item.id == id) return item;
  }
  return null;
}

String _slug(String value) {
  final slug = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'item' : slug.substring(0, math.min(48, slug.length));
}

String _newShelfId(String prefix) {
  final now = DateTime.now().toUtc().microsecondsSinceEpoch;
  final random = math.Random.secure().nextInt(0x7fffffff);
  return '$prefix-${now.toRadixString(36)}-${random.toRadixString(36)}';
}

String _safeText(Object? value, int maxChars, {String fallback = ''}) {
  final clean = value?.toString().replaceAll(RegExp(r'[\u0000-\u001F]'), ' ').trim() ?? '';
  final use = clean.isEmpty ? fallback : clean;
  if (use.length <= maxChars) return use;
  return use.substring(0, maxChars);
}

List<String> _safeStringList(Object? value, int maxItems, int maxChars) {
  if (value is! List) return const <String>[];
  return value
      .take(maxItems)
      .map((entry) => _safeText(entry, maxChars))
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}
