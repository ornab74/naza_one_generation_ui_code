import '../security/secure_database.dart';
import 'history_drawer.dart';

/// Encrypted metadata store for conversation presentation state.
///
/// Raw turns remain owned by the existing transcript/history store. This layer
/// persists only user-facing metadata such as generated titles, pins and the
/// time a thread was first observed. Keeping it separate makes title generation
/// replaceable without ever rewriting the authoritative conversation.
final class NazaHistoryMetadataRepository {
  NazaHistoryMetadataRepository({NazaSecureDatabase? database})
      : _database = database ?? NazaSecureDatabase.instance;

  static const String namespace = 'naza-chat-metadata-v2';
  static const String indexKey = 'threads';
  static const String format = 'naza-chat-metadata-v2';

  final NazaSecureDatabase _database;
  Map<String, NazaThreadMetadata>? _cache;

  Future<Map<String, NazaThreadMetadata>> load() async {
    final cached = _cache;
    if (cached != null) return Map<String, NazaThreadMetadata>.unmodifiable(cached);

    final raw = await _database.readJson(namespace, indexKey);
    final result = <String, NazaThreadMetadata>{};
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final threads = map['threads'];
      if (threads is List) {
        for (final item in threads) {
          if (item is! Map) continue;
          try {
            final metadata = NazaThreadMetadata.fromJson(
              Map<String, dynamic>.from(item),
            );
            result[metadata.threadId] = metadata;
          } catch (_) {
            // Skip a malformed metadata entry without making raw history
            // inaccessible. Vault authentication handles tamper detection.
          }
        }
      }
    }
    _cache = result;
    return Map<String, NazaThreadMetadata>.unmodifiable(result);
  }

  Future<NazaThreadMetadata> ensureThread({
    required String threadId,
    required String firstUserText,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    final map = await _mutable();
    final current = map[threadId];
    if (current != null) {
      final next = current.copyWith(updatedAt: updatedAt);
      map[threadId] = next;
      await _save(map);
      return next;
    }

    final created = NazaThreadMetadata(
      threadId: threadId,
      title: NazaConversationTitlePolicy.fallback(firstUserText),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
    map[threadId] = created;
    await _save(map);
    return created;
  }

  Future<void> setGeneratedTitle({
    required String threadId,
    required String generatedTitle,
    required String fallbackText,
  }) async {
    final map = await _mutable();
    final current = map[threadId];
    if (current == null || current.userRenamed) return;
    final title = NazaConversationTitlePolicy.sanitizeModelTitle(
      generatedTitle,
      fallbackText,
    );
    if (title.trim().isEmpty) return;
    map[threadId] = current.copyWith(
      title: title,
      titleGenerated: true,
      titleGeneratedAt: DateTime.now().toUtc(),
    );
    await _save(map);
  }

  Future<void> rename(String threadId, String title) async {
    final clean = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return;
    final map = await _mutable();
    final current = map[threadId];
    if (current == null) return;
    map[threadId] = current.copyWith(
      title: clean.length <= 72 ? clean : clean.substring(0, 72).trimRight(),
      userRenamed: true,
    );
    await _save(map);
  }

  Future<void> setPinned(String threadId, bool pinned) async {
    final map = await _mutable();
    final current = map[threadId];
    if (current == null || current.pinned == pinned) return;
    map[threadId] = current.copyWith(pinned: pinned);
    await _save(map);
  }

  Future<void> touch(String threadId, DateTime updatedAt) async {
    final map = await _mutable();
    final current = map[threadId];
    if (current == null) return;
    map[threadId] = current.copyWith(updatedAt: updatedAt.toUtc());
    await _save(map);
  }

  Future<void> remove(String threadId) async {
    final map = await _mutable();
    if (map.remove(threadId) == null) return;
    await _save(map);
  }

  Future<void> clear() async {
    _cache = <String, NazaThreadMetadata>{};
    await _database.delete(namespace, indexKey);
  }

  Future<List<NazaHistoryEntry>> decorate({
    required Iterable<NazaHistoryEntry> transcriptEntries,
  }) async {
    final metadata = await load();
    final result = <NazaHistoryEntry>[];
    for (final entry in transcriptEntries) {
      final meta = metadata[entry.threadId];
      result.add(
        NazaHistoryEntry(
          threadId: entry.threadId,
          title: meta?.title ?? entry.title,
          preview: entry.preview,
          createdAt: meta?.createdAt ?? entry.createdAt,
          updatedAt: entry.updatedAt,
          pinned: meta?.pinned ?? entry.pinned,
          messageCount: entry.messageCount,
        ),
      );
    }
    result.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return result;
  }

  Future<Map<String, NazaThreadMetadata>> _mutable() async =>
      Map<String, NazaThreadMetadata>.from(await load());

  Future<void> _save(Map<String, NazaThreadMetadata> value) async {
    _cache = Map<String, NazaThreadMetadata>.from(value);
    await _database.writeJson(
      namespace,
      indexKey,
      <String, Object?>{
        'format': format,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'threads': value.values.map((item) => item.toJson()).toList(growable: false),
      },
    );
  }
}

final class NazaThreadMetadata {
  const NazaThreadMetadata({
    required this.threadId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.pinned = false,
    this.titleGenerated = false,
    this.titleGeneratedAt,
    this.userRenamed = false,
  });

  final String threadId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pinned;
  final bool titleGenerated;
  final DateTime? titleGeneratedAt;
  final bool userRenamed;

  NazaThreadMetadata copyWith({
    String? title,
    DateTime? updatedAt,
    bool? pinned,
    bool? titleGenerated,
    DateTime? titleGeneratedAt,
    bool? userRenamed,
  }) =>
      NazaThreadMetadata(
        threadId: threadId,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        pinned: pinned ?? this.pinned,
        titleGenerated: titleGenerated ?? this.titleGenerated,
        titleGeneratedAt: titleGeneratedAt ?? this.titleGeneratedAt,
        userRenamed: userRenamed ?? this.userRenamed,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'threadId': threadId,
        'title': title,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'pinned': pinned,
        'titleGenerated': titleGenerated,
        'titleGeneratedAt': titleGeneratedAt?.toUtc().toIso8601String(),
        'userRenamed': userRenamed,
      };

  factory NazaThreadMetadata.fromJson(Map<String, dynamic> json) {
    final threadId = json['threadId'] as String?;
    final title = json['title'] as String?;
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updated = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (threadId == null || threadId.isEmpty || title == null || created == null || updated == null) {
      throw const FormatException('Invalid conversation metadata.');
    }
    return NazaThreadMetadata(
      threadId: threadId,
      title: title,
      createdAt: created.toUtc(),
      updatedAt: updated.toUtc(),
      pinned: json['pinned'] == true,
      titleGenerated: json['titleGenerated'] == true,
      titleGeneratedAt: DateTime.tryParse(json['titleGeneratedAt'] as String? ?? '')?.toUtc(),
      userRenamed: json['userRenamed'] == true,
    );
  }
}
