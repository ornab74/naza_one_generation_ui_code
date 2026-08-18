// LLM-CONTEXT:BEGIN
// FILE: lib/naza_bookforge.dart
// ROLE: Owns naza bookforge behavior within the application-core subsystem.
// DOMAIN: application-core
// SECURITY-INVARIANT: Preserve local-first privacy, bounded resource use, and explicit error handling.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import 'security/bounded_input.dart';
import 'security/secure_database.dart';

const Object _bookUnset = Object();

enum BookProvider { gemma4, gpt56Luna }

enum BookFormat { markdown, plainText, docx }

enum BookOrigin { local, generated, repository }

enum BookStatus { draft, review, published }

class BookMedia {
  const BookMedia({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final List<int> bytes;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'mimeType': mimeType,
    'bytes': base64Encode(bytes),
  };

  factory BookMedia.fromJson(Map<String, Object?> json) => BookMedia(
    name: json['name'] as String? ?? 'image',
    mimeType: json['mimeType'] as String? ?? 'image/png',
    bytes: base64Decode(json['bytes'] as String? ?? ''),
  );
}

class BookDocument {
  const BookDocument({
    required this.id,
    required this.title,
    required this.author,
    required this.content,
    required this.format,
    required this.origin,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.sourcePath,
    this.repository,
    this.tags = const <String>[],
    this.media = const <BookMedia>[],
  });

  final String id;
  final String title;
  final String author;
  final String content;
  final BookFormat format;
  final BookOrigin origin;
  final BookStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sourcePath;
  final String? repository;
  final List<String> tags;
  final List<BookMedia> media;

  int get wordCount => RegExp(r'\b[\w’\-]+\b').allMatches(content).length;
  int get estimatedMinutes => wordCount == 0 ? 0 : (wordCount / 220).ceil();

  BookDocument copyWith({
    String? title,
    String? author,
    String? content,
    BookFormat? format,
    BookOrigin? origin,
    BookStatus? status,
    DateTime? updatedAt,
    Object? sourcePath = _bookUnset,
    Object? repository = _bookUnset,
    List<String>? tags,
    List<BookMedia>? media,
  }) {
    return BookDocument(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      content: content ?? this.content,
      format: format ?? this.format,
      origin: origin ?? this.origin,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourcePath: identical(sourcePath, _bookUnset)
          ? this.sourcePath
          : sourcePath as String?,
      repository: identical(repository, _bookUnset)
          ? this.repository
          : repository as String?,
      tags: tags ?? this.tags,
      media: media ?? this.media,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'author': author,
    'content': content,
    'format': format.name,
    'origin': origin.name,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'sourcePath': sourcePath,
    'repository': repository,
    'tags': tags,
    'media': media.map((BookMedia item) => item.toJson()).toList(),
  };

  factory BookDocument.fromJson(Map<String, Object?> json) {
    T parseEnum<T extends Enum>(List<T> values, Object? value, T fallback) {
      return values.where((T item) => item.name == value).firstOrNull ??
          fallback;
    }

    return BookDocument(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      author: json['author'] as String? ?? 'Unknown',
      content: json['content'] as String? ?? '',
      format: parseEnum(BookFormat.values, json['format'], BookFormat.markdown),
      origin: parseEnum(BookOrigin.values, json['origin'], BookOrigin.local),
      status: parseEnum(BookStatus.values, json['status'], BookStatus.draft),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      sourcePath: json['sourcePath'] as String?,
      repository: json['repository'] as String?,
      tags: (json['tags'] as List<Object?>? ?? const <Object?>[])
          .whereType<String>()
          .toList(),
      media: (json['media'] as List<Object?>? ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> item) =>
                BookMedia.fromJson(Map<String, Object?>.from(item)),
          )
          .toList(),
    );
  }

  String encode() => jsonEncode(toJson());
}

class RepositoryBook {
  const RepositoryBook({
    required this.name,
    required this.path,
    required this.sha,
    required this.size,
    required this.downloadUrl,
    required this.format,
  });

  final String name;
  final String path;
  final String sha;
  final int size;
  final Uri? downloadUrl;
  final BookFormat format;
}

class RepositoryTarget {
  const RepositoryTarget({
    required this.owner,
    required this.name,
    this.branch = 'main',
    this.directory = 'generated',
  });

  final String owner;
  final String name;
  final String branch;
  final String directory;

  String get fullName => '$owner/$name';

  RepositoryTarget copyWith({
    String? owner,
    String? name,
    String? branch,
    String? directory,
  }) {
    return RepositoryTarget(
      owner: owner ?? this.owner,
      name: name ?? this.name,
      branch: branch ?? this.branch,
      directory: directory ?? this.directory,
    );
  }
}

class GenerationRequest {
  const GenerationRequest({
    required this.title,
    required this.premise,
    required this.audience,
    required this.voice,
    required this.chapterCount,
    required this.depth,
    required this.includeExercises,
    required this.includeSources,
    this.chapterWordTarget = 1200,
  });

  final String title;
  final String premise;
  final String audience;
  final String voice;
  final int chapterCount;
  final String depth;
  final bool includeExercises;
  final bool includeSources;
  final int chapterWordTarget;
}

class GenerationProgress {
  const GenerationProgress({
    required this.completed,
    required this.total,
    required this.phase,
  });

  final int completed;
  final int total;
  final String phase;

  double get fraction => total == 0 ? 0 : completed / total;
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LibraryStore {
  static const String _legacyKey = 'bookforge.library.v1';
  static const String _indexKey = 'bookforge.library-index.v2';
  static const String _bookPrefix = 'bookforge.book.v2.';

  Future<List<BookDocument>> load() async {
    Object? index;
    try {
      index = await NazaSecureDatabase.instance.readJson(
        'bookforge',
        _indexKey,
      );
    } catch (_) {
      index = null;
    }
    if (index is List) {
      final books = <BookDocument>[];
      for (final Object? id in index) {
        if (id is! String || id.isEmpty) continue;
        try {
          final Object? value = await NazaSecureDatabase.instance.readJson(
            'bookforge',
            _recordKey(id),
          );
          if (value is Map) {
            books.add(BookDocument.fromJson(Map<String, Object?>.from(value)));
          }
        } catch (_) {
          // A corrupt/missing record should not hide the rest of the library.
        }
      }
      return books;
    }

    Object? secure;
    var secureReadSucceeded = false;
    try {
      secure = await NazaSecureDatabase.instance.readJson(
        'bookforge',
        'library',
      );
      secureReadSucceeded = true;
      if (secure is List) {
        final books = _decode(secure);
        await _migrateBooks(books);
        return books;
      }
    } catch (_) {}

    // Older builds mirrored the encrypted library into preferences. Read that
    // value only as a one-time migration source; never write new manuscripts
    // or media there. Delete it only after the secure rewrite succeeds so a
    // transient keychain/database failure cannot destroy the user's library.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return <BookDocument>[];
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final books = _decode(decoded);
      if (!secureReadSucceeded || secure is! List) {
        try {
          await _migrateBooks(books);
          await prefs.remove(_legacyKey);
        } catch (_) {
          // Preserve the legacy copy until migration completes successfully.
        }
      }
      return books;
    } catch (_) {
      return <BookDocument>[];
    }
  }

  Future<void> saveBook(BookDocument book) async {
    await NazaSecureDatabase.instance.writeJson(
      'bookforge',
      _recordKey(book.id),
      book.toJson(),
    );
  }

  Future<void> saveBooks(List<BookDocument> books) async {
    for (final BookDocument book in books) {
      await saveBook(book);
    }
    await NazaSecureDatabase.instance.writeJson(
      'bookforge',
      _indexKey,
      books.map((BookDocument book) => book.id).toList(),
    );
    // Remove the old monolithic encrypted record after the per-book migration.
    await NazaSecureDatabase.instance.delete('bookforge', 'library');
  }

  Future<void> deleteBook(
    BookDocument book,
    List<BookDocument> remaining,
  ) async {
    await NazaSecureDatabase.instance.delete('bookforge', _recordKey(book.id));
    await NazaSecureDatabase.instance.writeJson(
      'bookforge',
      _indexKey,
      remaining.map((BookDocument item) => item.id).toList(),
    );
  }

  Future<void> _migrateBooks(List<BookDocument> books) => saveBooks(books);

  String _recordKey(String id) =>
      '$_bookPrefix${base64UrlEncode(utf8.encode(id)).replaceAll('=', '')}';

  List<BookDocument> _decode(Object value) {
    if (value is! List)
      throw const FormatException('Invalid BookForge library.');
    return value
        .map(
          (Object? item) =>
              BookDocument.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList();
  }
}

class ImportService {
  // These limits apply before archive entry contents are materialized. They
  // bound both attacker-controlled compressed input and the declared ZIP
  // expansion, which protects the UI isolate from decompression bombs.
  static const int maxCompressedBytes = 32 * 1024 * 1024;
  static const int maxArchiveEntries = 256;
  static const int maxExpandedBytes = 64 * 1024 * 1024;
  static const int maxEntryBytes = 16 * 1024 * 1024;
  static const int maxXmlBytes = 12 * 1024 * 1024;
  static const int maxMediaBytes = 24 * 1024 * 1024;

  Future<BookDocument?> pickAndImport({
    String author = 'Unknown author',
  }) async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['md', 'markdown', 'txt', 'docx'],
      withData: false,
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final PlatformFile file = result.files.single;
    final Uint8List bytes = await NazaBoundedInput.readPlatformFile(
      file,
      maxBytes: maxCompressedBytes,
      violation: const FormatException(
        'Choose a non-empty file within the 32 MiB import limit.',
      ),
    );
    final String ext = (file.extension ?? '').toLowerCase();
    // Decode once and reuse the validated archive for both document text and
    // media extraction. This halves ZIP parsing and avoids duplicate lazy
    // decompression for DOCX imports.
    final Archive? archive = ext == 'docx'
        ? _decodeBoundedArchive(bytes)
        : null;
    final String content = sanitize(
      archive == null
          ? utf8.decode(bytes, allowMalformed: true)
          : _docxToMarkdownArchive(archive),
    );
    final DateTime now = DateTime.now();
    return BookDocument(
      id: '${now.microsecondsSinceEpoch}-${file.name.hashCode}',
      title: titleFrom(content, file.name),
      author: author,
      content: content,
      format: ext == 'docx'
          ? BookFormat.docx
          : ext == 'txt'
          ? BookFormat.plainText
          : BookFormat.markdown,
      origin: BookOrigin.local,
      status: BookStatus.draft,
      createdAt: now,
      updatedAt: now,
      sourcePath: file.name,
      tags: const <String>['imported'],
      media: archive == null ? const <BookMedia>[] : _docxMedia(archive),
    );
  }

  String docxToMarkdown(Uint8List bytes) {
    return _docxToMarkdownArchive(_decodeBoundedArchive(bytes));
  }

  String _docxToMarkdownArchive(Archive archive) {
    ArchiveFile? document;
    for (final ArchiveFile file in archive.files) {
      if (file.name == 'word/document.xml') {
        document = file;
        break;
      }
    }
    if (document == null)
      throw const FormatException('DOCX is missing word/document.xml.');
    if (document.size > maxXmlBytes) {
      throw const FormatException('DOCX XML exceeds the 12 MiB safety limit.');
    }
    final Uint8List data = document.content;
    final XmlDocument xml = XmlDocument.parse(
      utf8.decode(data, allowMalformed: true),
    );
    final StringBuffer out = StringBuffer();
    for (final XmlElement paragraph in xml.findAllElements('w:p')) {
      final String text = paragraph
          .findAllElements('w:t')
          .map((XmlElement node) => node.innerText)
          .join()
          .trim();
      if (text.isEmpty) continue;
      final String? style = paragraph
          .findAllElements('w:pStyle')
          .map((XmlElement node) => node.getAttribute('w:val'))
          .whereType<String>()
          .firstOrNull;
      if (style != null && style.toLowerCase().startsWith('heading')) {
        final int parsed =
            int.tryParse(style.replaceAll(RegExp(r'\D'), '')) ?? 1;
        final int level = parsed < 1
            ? 1
            : parsed > 6
            ? 6
            : parsed;
        out.writeln('${List<String>.filled(level, '#').join()} $text\n');
      } else {
        out.writeln('$text\n');
      }
    }
    return out.toString().trim();
  }

  List<BookMedia> docxMedia(Uint8List bytes) {
    return _docxMedia(_decodeBoundedArchive(bytes));
  }

  List<BookMedia> _docxMedia(Archive archive) {
    int mediaBytes = 0;
    return archive.files
        .where((ArchiveFile file) {
          final String name = file.name.toLowerCase();
          return name.startsWith('word/media/') &&
              (name.endsWith('.png') ||
                  name.endsWith('.jpg') ||
                  name.endsWith('.jpeg') ||
                  name.endsWith('.gif') ||
                  name.endsWith('.webp'));
        })
        .map((ArchiveFile file) {
          mediaBytes += file.size;
          if (mediaBytes > maxMediaBytes) {
            throw const FormatException(
              'DOCX media exceeds the 24 MiB safety limit.',
            );
          }
          final String name = file.name.split('/').last;
          final String extension = name.contains('.')
              ? name.split('.').last.toLowerCase()
              : 'png';
          final Uint8List bytes = file.content;
          return BookMedia(
            name: name,
            mimeType: extension == 'jpg' || extension == 'jpeg'
                ? 'image/jpeg'
                : 'image/$extension',
            bytes: bytes,
          );
        })
        .toList();
  }

  Archive _decodeBoundedArchive(Uint8List bytes) {
    if (bytes.length > maxCompressedBytes) {
      throw const FormatException('DOCX exceeds the 32 MiB compressed limit.');
    }
    var entries = 0;
    var expandedBytes = 0;
    return ZipDecoder().decodeBytes(
      bytes,
      callback: (ArchiveFile file) {
        if (++entries > maxArchiveEntries) {
          throw const FormatException(
            'DOCX contains too many archive entries.',
          );
        }
        if (file.size < 0 || file.size > maxEntryBytes) {
          throw const FormatException(
            'DOCX archive entry exceeds the 16 MiB limit.',
          );
        }
        expandedBytes += file.size;
        if (expandedBytes > maxExpandedBytes) {
          throw const FormatException(
            'DOCX expanded content exceeds the 64 MiB limit.',
          );
        }
      },
    );
  }

  String titleFrom(String content, String fallback) {
    final RegExpMatch? heading = RegExp(
      r'^#\s+(.+)$',
      multiLine: true,
    ).firstMatch(content);
    if (heading != null) return heading.group(1)!.trim();
    return fallback
        .replaceFirst(RegExp(r'\.[^.]+$'), '')
        .replaceAll('_', ' ')
        .trim();
  }

  String sanitize(String value) {
    final String clean = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '');
    if (clean.length > 12000000)
      throw const FormatException('Book is too large to import safely.');
    return clean.trim();
  }
}

class GitHubService {
  static const int maxDownloadBytes = ImportService.maxCompressedBytes;
  static const Duration requestTimeout = Duration(seconds: 30);
  GitHubService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Map<String, String> headers(String token) => <String, String>{
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    if (token.trim().isNotEmpty) 'Authorization': 'Bearer ${token.trim()}',
  };

  Future<List<RepositoryBook>> scanBooks(
    RepositoryTarget target, {
    String token = '',
  }) async {
    final Uri uri = Uri.https(
      'api.github.com',
      '/repos/${target.fullName}/git/trees/${target.branch}',
      <String, String>{'recursive': '1'},
    );
    final http.Response response = await _client
        .get(uri, headers: headers(token))
        .timeout(requestTimeout);
    _check(response, 'scan repository');
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    if (data['truncated'] == true) {
      throw StateError(
        'GitHub returned a truncated repository tree. Narrow the repository or scan a subdirectory.',
      );
    }
    final List<dynamic> tree = data['tree'] as List<dynamic>? ?? <dynamic>[];
    final List<RepositoryBook> books = <RepositoryBook>[];
    for (final dynamic item in tree) {
      final Map<String, dynamic> node = item as Map<String, dynamic>;
      if (node['type'] != 'blob') continue;
      final String path = node['path'] as String? ?? '';
      if (path.isEmpty ||
          path.startsWith('/') ||
          path.contains('..') ||
          path.length > 512)
        continue;
      final String lower = path.toLowerCase();
      if (!lower.endsWith('.md') &&
          !lower.endsWith('.txt') &&
          !lower.endsWith('.docx'))
        continue;
      books.add(
        RepositoryBook(
          name: path.split('/').last,
          path: path,
          sha: node['sha'] as String? ?? '',
          size: node['size'] as int? ?? 0,
          downloadUrl: Uri.tryParse(
            'https://raw.githubusercontent.com/${target.fullName}/${target.branch}/$path',
          ),
          format: lower.endsWith('.docx')
              ? BookFormat.docx
              : lower.endsWith('.txt')
              ? BookFormat.plainText
              : BookFormat.markdown,
        ),
      );
    }
    books.sort(
      (RepositoryBook a, RepositoryBook b) => a.path.compareTo(b.path),
    );
    return books;
  }

  Future<BookDocument> downloadBook(
    RepositoryTarget target,
    RepositoryBook book, {
    String token = '',
  }) async {
    // The Contents API does not reliably return inline content for large files
    // (notably DOCX files). Fetch the raw blob instead so the ZIP remains intact.
    final Uri uri =
        book.downloadUrl ??
        Uri.https(
          'raw.githubusercontent.com',
          '/${target.fullName}/${target.branch}/${book.path}',
        );
    final Uint8List bytes = await _downloadBounded(
      uri,
      headers: headers(token),
      action: 'download ${book.path}',
    );
    final ImportService importer = ImportService();
    final String content = importer.sanitize(
      book.format == BookFormat.docx
          ? importer.docxToMarkdown(bytes)
          : utf8.decode(bytes, allowMalformed: true),
    );
    final DateTime now = DateTime.now();
    return BookDocument(
      id: '${now.microsecondsSinceEpoch}-${book.sha}',
      title: importer.titleFrom(content, book.name),
      author: 'Unknown author',
      content: content,
      format: book.format,
      origin: BookOrigin.repository,
      status: BookStatus.published,
      createdAt: now,
      updatedAt: now,
      sourcePath: book.path,
      repository: target.fullName,
      tags: const <String>['repository'],
      media: book.format == BookFormat.docx
          ? importer.docxMedia(bytes)
          : const <BookMedia>[],
    );
  }

  Future<Uint8List> _downloadBounded(
    Uri uri, {
    required Map<String, String> headers,
    required String action,
  }) async {
    final http.StreamedResponse response = await _client
        .send(http.Request('GET', uri)..headers.addAll(headers))
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Could not $action (${response.statusCode}).');
    }
    final int? advertised = int.tryParse(
      response.headers['content-length'] ?? '',
    );
    if (advertised != null && advertised > maxDownloadBytes) {
      throw const FormatException(
        'Repository download exceeds the 32 MiB limit.',
      );
    }
    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in response.stream) {
      received += chunk.length;
      if (received > maxDownloadBytes) {
        throw const FormatException(
          'Repository download exceeds the 32 MiB limit.',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<Uri> publishMarkdown({
    required RepositoryTarget target,
    required BookDocument book,
    required String token,
    bool allowOverwrite = false,
  }) async {
    if (token.trim().isEmpty)
      throw ArgumentError('A GitHub token is required to publish.');
    final String directory = target.directory.trim().replaceAll(
      RegExp(r'^/+|/+$'),
      '',
    );
    final String path =
        '${directory.isEmpty ? '' : '$directory/'}${_slug(book.title)}.md';
    final Uri uri = Uri.https(
      'api.github.com',
      '/repos/${target.fullName}/contents/$path',
    );
    String? existingSha;
    final http.Response existing = await _client
        .get(
          uri.replace(queryParameters: <String, String>{'ref': target.branch}),
          headers: headers(token),
        )
        .timeout(requestTimeout);
    if (existing.statusCode == 200) {
      existingSha =
          (jsonDecode(existing.body) as Map<String, dynamic>)['sha'] as String?;
    } else if (existing.statusCode != 404) {
      _check(existing, 'check existing file');
    }
    if (existingSha != null && !allowOverwrite) {
      throw StateError(
        'A file already exists at $path. Confirm overwrite explicitly before publishing.',
      );
    }

    final String escapedTitle = _yamlDoubleQuoted(book.title);
    final String escapedAuthor = _yamlDoubleQuoted(book.author);
    final String frontMatter =
        '''---
title: "$escapedTitle"
author: "$escapedAuthor"
status: published
updated: ${DateTime.now().toUtc().toIso8601String()}
tags: [${book.tags.map(_yamlDoubleQuoted).map((String value) => '"$value"').join(', ')}]
---

''';
    final Map<String, Object?> payload = <String, Object?>{
      'message': 'Publish ${book.title}',
      'content': base64Encode(
        utf8.encode('$frontMatter${book.content.trim()}\n'),
      ),
      'branch': target.branch,
      ...?existingSha == null ? null : <String, String>{'sha': existingSha},
    };
    final http.Response response = await _client
        .put(
          uri,
          headers: <String, String>{
            ...headers(token),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(requestTimeout);
    _check(response, 'publish $path');
    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    final Map<String, dynamic> content =
        body['content'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return Uri.parse(
      content['html_url'] as String? ??
          'https://github.com/${target.fullName}/blob/${target.branch}/$path',
    );
  }

  void _check(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message = response.body;
    try {
      message =
          (jsonDecode(response.body) as Map<String, dynamic>)['message']
              as String? ??
          message;
    } catch (_) {}
    throw StateError('Could not $action (${response.statusCode}): $message');
  }

  String _slug(String value) {
    final String slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .replaceAll(RegExp(r'-{2,}'), '-');
    if (slug.isNotEmpty) return slug;
    var hash = 2166136261;
    for (final int byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return 'book-$hash';
  }

  // Front matter is deliberately emitted with a strict double-quoted scalar.
  // Normalizing line breaks and control characters first prevents user data
  // from terminating a YAML field or introducing a new mapping key. Escaping
  // backslashes before quotes also avoids YAML escape-sequence confusion.
  String _yamlDoubleQuoted(String value) {
    final String oneLine = value
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return oneLine.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }
}

typedef NazaBookCompletion =
    Future<String> Function({
      required String systemInstruction,
      required String prompt,
      void Function(String text)? onPartial,
    });

final class GenerationCancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class GenerationService {
  static const Set<String> allowedApiHosts = <String>{'api.openai.com'};
  static const Duration requestTimeout = Duration(seconds: 90);

  GenerationService({http.Client? client, this.completion})
    : _client = client ?? http.Client();
  final http.Client _client;
  NazaBookCompletion? completion;

  /// Validates the egress boundary before an API key is attached. Custom
  /// endpoints remain usable for keyless/local providers, but an OpenAI key
  /// is never sent to an arbitrary host, plaintext transport, or non-default
  /// port. Redirects are also disabled in [_complete].
  static void validateApiKeyEndpoint(Uri uri) {
    if (uri.scheme != 'https' ||
        !allowedApiHosts.contains(uri.host.toLowerCase()) ||
        (uri.hasPort && uri.port != 443)) {
      throw ArgumentError(
        'API-key generation requires https://api.openai.com on port 443.',
      );
    }
  }

  Stream<GenerationProgress> generate({
    required GenerationRequest request,
    required String endpoint,
    required String model,
    required String apiKey,
    required void Function(String markdown) onDraft,
    void Function(String text)? onPartial,
    GenerationCancellationToken? cancellation,
  }) async* {
    void checkCancelled() {
      if (cancellation?.isCancelled == true) {
        throw const NazaBookGenerationCancelled();
      }
    }
    checkCancelled();
    final int total = request.chapterCount + 1;
    yield GenerationProgress(
      completed: 0,
      total: total,
      phase: 'Designing the book',
    );
    final String outline = await _complete(
      endpoint: endpoint,
      model: model,
      apiKey: apiKey,
      system:
          'You are a rigorous book architect. Return only a numbered chapter outline with concise chapter purposes.',
      prompt:
          '''Create ${request.chapterCount} chapters for "${request.title}".
Premise: ${request.premise}
Audience: ${request.audience}
Voice: ${request.voice}
Depth: ${request.depth}
Every chapter must make a distinct intellectual contribution.''',
      onPartial: onPartial,
    );
    checkCancelled();
    final List<String> titles = _parseOutline(outline, request.chapterCount);
    final List<String> chapters = <String>[];
    onDraft(_assemble(request.title, titles, chapters));

    for (int index = 0; index < titles.length; index++) {
      checkCancelled();
      String chapter = await _complete(
        endpoint: endpoint,
        model: model,
        apiKey: apiKey,
        system:
            'Write advanced, original nonfiction in Markdown. Explain how and why. Avoid filler and fabricated citations.',
        prompt:
            '''Book: ${request.title}
Premise: ${request.premise}
Audience: ${request.audience}
Voice: ${request.voice}
Depth: ${request.depth}
Outline:
${titles.asMap().entries.map((MapEntry<int, String> entry) => '${entry.key + 1}. ${entry.value}').join('\n')}

Write chapter ${index + 1}: ${titles[index]}.
Use a chapter heading, clear subsections, concrete examples, technical details, and a practical synthesis.${request.includeExercises ? '\nInclude three exercises.' : ''}${request.includeSources ? '\nAdd a Sources to Verify section with search targets, never invented citations.' : ''}''',
        onPartial: onPartial,
      );
      chapter = chapter.trim();
      if (chapter.isEmpty) {
        chapter = await _complete(
          endpoint: endpoint,
          model: model,
          apiKey: apiKey,
          system: 'Write the missing chapter now in Markdown.',
          prompt:
              'Write chapter ${index + 1}: ${titles[index]} for ${request.title}.',
          onPartial: onPartial,
        );
      }
      var continuation = 0;
      while (_wordCount(chapter) < request.chapterWordTarget &&
          continuation < 4) {
        checkCancelled();
        continuation++;
        final remaining = request.chapterWordTarget - _wordCount(chapter);
        final String context = chapter.length > 12000
            ? chapter.substring(chapter.length - 12000)
            : chapter;
        final addition = await _complete(
          endpoint: endpoint,
          model: model,
          apiKey: apiKey,
          system:
              'Continue the same chapter seamlessly. Return only new prose, no repeated heading or preamble.',
          prompt:
              'Continue chapter ${index + 1} of ${request.title}. Current word count: ${_wordCount(chapter)}. Add about $remaining words while preserving continuity. Use this bounded tail for continuity:\n$context',
          onPartial: onPartial,
        );
        if (addition.trim().isEmpty) break;
        chapter = '$chapter\n\n${addition.trim()}';
      }
      chapters.add(chapter);
      onDraft(_assemble(request.title, titles, chapters));
      yield GenerationProgress(
        completed: index + 1,
        total: total,
        phase: 'Writing chapter ${index + 1} of ${titles.length}',
      );
    }
    yield GenerationProgress(
      completed: total,
      total: total,
      phase: 'Draft complete',
    );
  }

  int _wordCount(String value) =>
      RegExp(r"\b[\w’'-]+\b").allMatches(value).length;

  String _assemble(String title, List<String> outline, List<String> chapters) {
    final String toc = outline
        .asMap()
        .entries
        .map(
          (MapEntry<int, String> entry) => '${entry.key + 1}. ${entry.value}',
        )
        .join('\n');
    return '# $title\n\n## Table of Contents\n\n$toc\n\n${chapters.join('\n\n---\n\n')}';
  }

  Future<String> _complete({
    required String endpoint,
    required String model,
    required String apiKey,
    required String system,
    required String prompt,
    void Function(String text)? onPartial,
  }) async {
    if (completion != null) {
      return completion!(
        systemInstruction: system,
        prompt: prompt,
        onPartial: onPartial,
      );
    }
    final Uri uri = Uri.parse(
      endpoint.trim().isEmpty
          ? 'https://api.openai.com/v1/chat/completions'
          : endpoint.trim(),
    );
    final String trimmedKey = apiKey.trim();
    if (trimmedKey.isNotEmpty) validateApiKeyEndpoint(uri);
    final http.Request request = http.Request('POST', uri)
      ..followRedirects = false
      ..headers.addAll(<String, String>{
        'Content-Type': 'application/json',
        if (trimmedKey.isNotEmpty) 'Authorization': 'Bearer $trimmedKey',
      })
      ..body = jsonEncode(<String, Object?>{
        'model': model,
        'messages': <Map<String, String>>[
          <String, String>{'role': 'system', 'content': system},
          <String, String>{'role': 'user', 'content': prompt},
        ],
      });
    final http.StreamedResponse streamed = await _client
        .send(request)
        .timeout(requestTimeout);
    final http.Response response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Generation failed (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> choices =
        data['choices'] as List<dynamic>? ?? <dynamic>[];
    if (choices.isEmpty)
      throw const FormatException('The model returned no choices.');
    final Map<String, dynamic> choice = choices.first as Map<String, dynamic>;
    final Map<String, dynamic> message =
        choice['message'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return message['content'] as String? ?? '';
  }

  List<String> _parseOutline(String outline, int count) {
    final List<String> titles = outline
        .split('\n')
        .map(
          (String line) => line
              .replaceFirst(
                RegExp(
                  r'^\s*(?:chapter\s*)?\d+[.):\-]\s*',
                  caseSensitive: false,
                ),
                '',
              )
              .trim(),
        )
        .where((String line) => line.isNotEmpty)
        .take(count)
        .toList();
    while (titles.length < count) {
      titles.add('Chapter ${titles.length + 1}');
    }
    return titles;
  }
}

final class NazaBookGenerationCancelled implements Exception {
  const NazaBookGenerationCancelled();

  @override
  String toString() => 'Book generation was cancelled.';
}

class BookForgeApp extends StatelessWidget {
  const BookForgeApp({super.key, this.completion});

  final NazaBookCompletion? completion;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context),
      child: StudioScreen(completion: completion),
    );
  }
}

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key, this.completion});

  final NazaBookCompletion? completion;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final LibraryStore _store = LibraryStore();
  final ImportService _importer = ImportService();
  final GitHubService _github = GitHubService();
  late final GenerationService _generation = GenerationService(
    completion: widget.completion,
  );

  final TextEditingController _search = TextEditingController();
  final TextEditingController _editor = TextEditingController();
  final TextEditingController _githubToken = TextEditingController();
  final TextEditingController _apiKey = TextEditingController();
  final TextEditingController _endpoint = TextEditingController(
    text: 'https://api.openai.com/v1/chat/completions',
  );
  final TextEditingController _model = TextEditingController(
    text: 'gpt-5-mini',
  );
  BookProvider _provider = BookProvider.gemma4;
  final TextEditingController _owner = TextEditingController(text: 'ornab74');
  final TextEditingController _repo = TextEditingController(text: 'books');
  final TextEditingController _branch = TextEditingController(text: 'main');
  final TextEditingController _directory = TextEditingController(
    text: 'generated',
  );

  List<BookDocument> _books = <BookDocument>[];
  List<RepositoryBook> _remoteBooks = <RepositoryBook>[];
  BookDocument? _selected;
  Timer? _saveTimer;
  Timer? _editorUiTimer;
  Future<void> _saveQueue = Future<void>.value();
  int _saveRevision = 0;
  int _page = 0;
  bool _loading = true;
  bool _saving = false;
  bool _busy = false;
  bool _preview = true;
  GenerationProgress? _progress;
  String _streamingText = '';
  String _pendingStreamText = '';
  Timer? _streamPaintTimer;
  GenerationCancellationToken? _generationCancellation;
  int _generationSerial = 0;

  RepositoryTarget get _target => RepositoryTarget(
    owner: _owner.text.trim(),
    name: _repo.text.trim(),
    branch: _branch.text.trim().isEmpty ? 'main' : _branch.text.trim(),
    directory: _directory.text.trim(),
  );

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
    _editor.addListener(_editorChanged);
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _editorUiTimer?.cancel();
    _streamPaintTimer?.cancel();
    _generationCancellation?.cancel();
    for (final TextEditingController controller in <TextEditingController>[
      _search,
      _editor,
      _githubToken,
      _apiKey,
      _endpoint,
      _model,
      _owner,
      _repo,
      _branch,
      _directory,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    List<BookDocument> books = <BookDocument>[];
    try {
      books = await _store.load();
    } catch (error) {
      _error(error);
    }
    try {
      final Object? savedKey = await NazaSecureDatabase.instance.readJson(
        'bookforge',
        'openai-api-key',
      );
      if (savedKey is String && savedKey.isNotEmpty) _apiKey.text = savedKey;
      final Object? savedModel = await NazaSecureDatabase.instance.readJson(
        'bookforge',
        'openai-model',
      );
      if (savedModel is String && savedModel.isNotEmpty)
        _model.text = savedModel;
      final Object? savedEndpoint = await NazaSecureDatabase.instance.readJson(
        'bookforge',
        'openai-endpoint',
      );
      if (savedEndpoint is String && savedEndpoint.isNotEmpty)
        _endpoint.text = savedEndpoint;
      final Object? savedProvider = await NazaSecureDatabase.instance.readJson(
        'bookforge',
        'provider',
      );
      if (savedProvider == 'gpt56Luna') _provider = BookProvider.gpt56Luna;
    } catch (_) {
      // The vault may still be locked during first paint; the key remains editable.
    }
    if (!mounted) return;
    setState(() {
      _books = books;
      _loading = false;
      _selected = books.isEmpty ? null : books.first;
      _editor.text = _selected?.content ?? '';
    });
  }

  void _select(BookDocument book) {
    if (_selected?.id == book.id) return;
    // Selection can race with the editor's debounce callback. Detach the
    // listener while replacing the document so the incoming book is never
    // treated as an edit to the outgoing book.
    _editor.removeListener(_editorChanged);
    _editor.text = book.content;
    _editor.addListener(_editorChanged);
    if (mounted) setState(() => _selected = book);
  }

  void _editorChanged() {
    final BookDocument? current = _selected;
    if (current == null || current.content == _editor.text) return;
    final int index = _books.indexWhere(
      (BookDocument book) => book.id == current.id,
    );
    if (index < 0) return;
    if (index < 0) return;
    final BookDocument updated = current.copyWith(
      content: _editor.text,
      status: BookStatus.draft,
      updatedAt: DateTime.now(),
    );
    _books[index] = updated;
    _selected = updated;
    // Do not rebuild the complete library/Markdown tree for every keystroke.
    // The editor owns its text rendering; header/status refresh is throttled.
    if (!_saving && mounted) setState(() => _saving = true);
    _editorUiTimer?.cancel();
    _editorUiTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() {});
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(_queueSaveBook(updated));
    });
  }

  Future<void> _queueSaveBook(BookDocument book) {
    final int revision = ++_saveRevision;
    _saveQueue = _saveQueue.then((_) async {
      try {
        await _store.saveBook(book);
        if (mounted && revision == _saveRevision) {
          setState(() => _saving = false);
        }
      } catch (error) {
        if (mounted && revision == _saveRevision) {
          setState(() => _saving = false);
          _error(error);
        }
      }
    });
    return _saveQueue;
  }

  Future<void> _import() async {
    try {
      final BookDocument? book = await _importer.pickAndImport();
      if (book == null) return;
      setState(() {
        _books.insert(0, book);
        _page = 0;
      });
      _select(book);
      await _store.saveBook(book);
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _newBook() async {
    final DateTime now = DateTime.now();
    final BookDocument book = BookDocument(
      id: now.microsecondsSinceEpoch.toString(),
      title: 'Untitled Book',
      author: 'Unknown author',
      content: '# Untitled Book\n\nBegin writing here.\n',
      format: BookFormat.markdown,
      origin: BookOrigin.local,
      status: BookStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    setState(() {
      _books.insert(0, book);
      _page = 0;
    });
    _select(book);
    await _store.saveBooks(_books);
  }

  Future<void> _editMetadata() async {
    final BookDocument? current = _selected;
    if (current == null) return;
    final TextEditingController title = TextEditingController(
      text: current.title,
    );
    final TextEditingController author = TextEditingController(
      text: current.author,
    );
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Book metadata'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: author,
                decoration: const InputDecoration(labelText: 'Author'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save != true || !mounted) return;
    final int index = _books.indexWhere(
      (BookDocument book) => book.id == current.id,
    );
    final BookDocument updated = current.copyWith(
      title: title.text.trim().isEmpty ? current.title : title.text.trim(),
      author: author.text.trim().isEmpty ? current.author : author.text.trim(),
      updatedAt: DateTime.now(),
    );
    setState(() {
      _books[index] = updated;
      _selected = updated;
    });
    await _store.saveBook(updated);
  }

  Future<void> _delete() async {
    final BookDocument? current = _selected;
    if (current == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete local copy?'),
        content: Text(
          'Remove “${current.title}” from the local BookForge library?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _books.removeWhere((BookDocument book) => book.id == current.id);
      _selected = _books.isEmpty ? null : _books.first;
    });
    _editor.removeListener(_editorChanged);
    _editor.text = _selected?.content ?? '';
    _editor.addListener(_editorChanged);
    await _store.deleteBook(current, _books);
  }

  Future<void> _scan() async {
    if (_target.owner.isEmpty || _target.name.isEmpty) {
      _error('Repository owner and name are required.');
      return;
    }
    setState(() => _busy = true);
    try {
      final List<RepositoryBook> books = await _github.scanBooks(
        _target,
        token: _githubToken.text,
      );
      if (!mounted) return;
      setState(() => _remoteBooks = books);
      _message('Found ${books.length} readable files.');
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(RepositoryBook remote) async {
    setState(() => _busy = true);
    try {
      final BookDocument book = await _github.downloadBook(
        _target,
        remote,
        token: _githubToken.text,
      );
      final int index = _books.indexWhere(
        (BookDocument item) =>
            item.repository == book.repository &&
            item.sourcePath == book.sourcePath,
      );
      if (index >= 0) {
        _books[index] = book;
      } else {
        _books.insert(0, book);
      }
      setState(() => _page = 0);
      _select(index >= 0 ? _books[index] : _books.first);
      await _store.saveBooks(_books);
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final BookDocument? current = _selected;
    if (current == null) return;
    setState(() => _busy = true);
    try {
      final Uri uri = await _github.publishMarkdown(
        target: _target,
        book: current,
        token: _githubToken.text,
      );
      final int index = _books.indexWhere(
        (BookDocument book) => book.id == current.id,
      );
      final BookDocument published = current.copyWith(
        status: BookStatus.published,
        repository: _target.fullName,
        updatedAt: DateTime.now(),
      );
      setState(() {
        _books[index] = published;
        _selected = published;
      });
      await _store.saveBook(published);
      _message('Published: $uri');
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate(GenerationRequest request) async {
    final int generationId = ++_generationSerial;
    if (_provider == BookProvider.gpt56Luna && _apiKey.text.trim().isEmpty) {
      _error('Add an API key in Settings before generating.');
      return;
    }
    _generation.completion = _provider == BookProvider.gemma4
        ? widget.completion
        : null;
    final cancellation = GenerationCancellationToken();
    _generationCancellation?.cancel();
    _generationCancellation = cancellation;
    final DateTime now = DateTime.now();
    BookDocument draft = BookDocument(
      id: 'generated-${now.microsecondsSinceEpoch}',
      title: request.title,
      author: 'Unknown author',
      content: '# ${request.title}\n\nDesigning the manuscript…',
      format: BookFormat.markdown,
      origin: BookOrigin.generated,
      status: BookStatus.draft,
      createdAt: now,
      updatedAt: now,
      tags: <String>['generated', request.depth.toLowerCase()],
    );
    setState(() {
      _books.insert(0, draft);
      _page = 0;
      _busy = true;
      _progress = const GenerationProgress(
        completed: 0,
        total: 1,
        phase: 'Starting',
      );
      _streamingText = 'Gemma is preparing the outline...\n\n';
      _page = 4;
    });
    _select(draft);
    await _queueSaveBook(draft);
    try {
      final Stream<GenerationProgress> stream = _generation.generate(
        request: request,
        endpoint: _endpoint.text,
        model: _provider == BookProvider.gpt56Luna
            ? _model.text.trim()
            : _model.text.trim(),
        apiKey: _apiKey.text,
        cancellation: cancellation,
        onDraft: (String markdown) {
          if (generationId != _generationSerial) return;
          final int index = _books.indexWhere(
            (BookDocument book) => book.id == draft.id,
          );
          if (index < 0 || !mounted) return;
          draft = draft.copyWith(content: markdown, updatedAt: DateTime.now());
          _editor.removeListener(_editorChanged);
          _editor.text = markdown;
          _editor.addListener(_editorChanged);
          setState(() {
            _books[index] = draft;
            _selected = draft;
            _streamingText = markdown;
          });
          unawaited(_queueSaveBook(draft));
        },
        onPartial: (String text) {
          if (!mounted || generationId != _generationSerial) return;
          _pendingStreamText = text;
          if (_streamPaintTimer?.isActive ?? false) return;
          _streamPaintTimer = Timer(const Duration(milliseconds: 90), () {
            if (mounted) setState(() => _streamingText = _pendingStreamText);
          });
        },
      );
      await for (final GenerationProgress progress in stream) {
        if (mounted && generationId == _generationSerial) {
          setState(() => _progress = progress);
        }
      }
      await _queueSaveBook(draft);
      _message('Generated draft complete.');
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<BookDocument> get _visibleBooks {
    final String query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _books;
    return _books.where((BookDocument book) {
      return book.title.toLowerCase().contains(query) ||
          book.author.toLowerCase().contains(query) ||
          book.tags.any((String tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: _page == 4
                  ? 1
                  : (_page >= 0 && _page < 4 ? _page : 0),
              onDestinationSelected: (int value) =>
                  setState(() => _page = value),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF9A7CFF), Color(0xFF4D7DFF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              destinations: const <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories),
                  label: Text('Library'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome),
                  label: Text('Generate'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.cloud_outlined),
                  selectedIcon: Icon(Icons.cloud),
                  label: Text('Repository'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, color: Color(0xFF202632)),
            Expanded(child: _pageBody()),
          ],
        ),
      ),
    );
  }

  Widget _pageBody() {
    return switch (_page) {
      0 => _library(),
      1 => GeneratorPanel(onGenerate: _generate, busy: _busy),
      2 => RepositoryPanel(
        owner: _owner,
        repo: _repo,
        branch: _branch,
        directory: _directory,
        books: _remoteBooks,
        busy: _busy,
        onScan: _scan,
        onOpen: _download,
      ),
      4 => _liveGenerationPage(),
      _ => SettingsPanel(
        githubToken: _githubToken,
        apiKey: _apiKey,
        endpoint: _endpoint,
        model: _model,
        provider: _provider,
        onProviderChanged: _setProvider,
        onSaveApiKey: _saveOpenAiSettings,
      ),
    };
  }

  Future<void> _saveOpenAiSettings() async {
    try {
      await NazaSecureDatabase.instance.writeJson(
        'bookforge',
        'openai-api-key',
        _apiKey.text.trim(),
      );
      await NazaSecureDatabase.instance.writeJson(
        'bookforge',
        'openai-model',
        'gpt-5.6-luna',
      );
      await NazaSecureDatabase.instance.writeJson(
        'bookforge',
        'openai-endpoint',
        _endpoint.text.trim(),
      );
      _model.text = 'gpt-5.6-luna';
      _message('OpenAI key saved in the encrypted Naza vault.');
    } catch (error) {
      _error('Unlock the Naza vault before saving the OpenAI key: $error');
    }
  }

  Future<void> _setProvider(BookProvider value) async {
    setState(() => _provider = value);
    try {
      await NazaSecureDatabase.instance.writeJson(
        'bookforge',
        'provider',
        value.name,
      );
      if (value == BookProvider.gpt56Luna)
        await NazaSecureDatabase.instance.writeJson(
          'bookforge',
          'openai-model',
          'gpt-5.6-luna',
        );
    } catch (error) {
      _error(
        'Provider changed for this session, but could not persist it until the vault is unlocked: $error',
      );
    }
  }

  Widget _liveGenerationPage() {
    final GenerationProgress? progress = _progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.auto_awesome, color: Color(0xFF7C5CFC)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                progress?.phase ?? 'Preparing Gemma',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _page = 0),
              icon: const Icon(Icons.menu_book),
              label: const Text('Library'),
            ),
          ],
        ),
        if (progress != null) LinearProgressIndicator(value: progress.fraction),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                _streamingText.isEmpty
                    ? 'Waiting for Gemma tokens...'
                    : _streamingText,
                style: const TextStyle(fontSize: 15, height: 1.55),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _library() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<BookDocument> visibleBooks = _visibleBooks;
    return Row(
      children: <Widget>[
        SizedBox(
          width: MediaQuery.sizeOf(context).width < 760 ? 240 : 330,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'BookForge',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _newBook,
                      tooltip: 'New book',
                      icon: const Icon(Icons.add_rounded),
                    ),
                    IconButton(
                      onPressed: _import,
                      tooltip: 'Import',
                      icon: const Icon(Icons.upload_file_rounded),
                    ),
                  ],
                ),
                Text(
                  '${visibleBooks.length} books',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search library',
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: visibleBooks.isEmpty
                      ? const EmptyPanel(
                          icon: Icons.library_books_outlined,
                          title: 'No books yet',
                          body:
                              'Import Markdown, text, or DOCX books, or generate a new manuscript.',
                        )
                      : ListView.separated(
                          itemCount: visibleBooks.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int index) {
                            final BookDocument book = visibleBooks[index];
                            final bool active = _selected?.id == book.id;
                            return Material(
                              color: active
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _select(book),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        width: 42,
                                        height: 54,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: active
                                                ? <Color>[
                                                    scheme.primary,
                                                    scheme.secondary,
                                                  ]
                                                : <Color>[
                                                    scheme.surfaceContainerHigh,
                                                    scheme.surfaceContainerHighest,
                                                  ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                        ),
                                        child: Text(
                                          book.title.isEmpty
                                              ? '?'
                                              : book.title[0].toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              book.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              '${book.wordCount} words · ${book.status.name}',
                                              style: const TextStyle(
                                                color: Color(0xFF7D8799),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, color: Color(0xFF202632)),
        Expanded(
          child: _selected == null
              ? const EmptyPanel(
                  icon: Icons.chrome_reader_mode_outlined,
                  title: 'Choose a book',
                  body: 'Select a manuscript to read or edit it.',
                )
              : Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 18, 12),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _selected!.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_selected!.author} · ${_selected!.wordCount} words · ${_selected!.estimatedMinutes} min${_saving ? ' · saving…' : ''}',
                                  style: const TextStyle(
                                    color: Color(0xFF848EA1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SegmentedButton<bool>(
                            segments: const <ButtonSegment<bool>>[
                              ButtonSegment<bool>(
                                value: true,
                                icon: Icon(Icons.visibility_outlined),
                                label: Text('Read'),
                              ),
                              ButtonSegment<bool>(
                                value: false,
                                icon: Icon(Icons.edit_outlined),
                                label: Text('Edit'),
                              ),
                            ],
                            selected: <bool>{_preview},
                            onSelectionChanged: (Set<bool> value) =>
                                setState(() => _preview = value.first),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _editMetadata,
                            tooltip: 'Metadata',
                            icon: const Icon(Icons.badge_outlined),
                          ),
                          IconButton(
                            onPressed: _delete,
                            tooltip: 'Delete local copy',
                            icon: const Icon(Icons.delete_outline),
                          ),
                          FilledButton.icon(
                            onPressed: _busy ? null : _publish,
                            icon: const Icon(Icons.publish_rounded),
                            label: const Text('Publish'),
                          ),
                        ],
                      ),
                    ),
                    if (_busy && _progress != null)
                      Column(
                        children: <Widget>[
                          LinearProgressIndicator(
                            value: _progress!.fraction,
                            minHeight: 3,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              _progress!.phase,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8993A6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    Expanded(
                      child: _preview
                          ? ReadingPane(book: _selected!)
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                12,
                                22,
                                22,
                              ),
                              child: TextField(
                                controller: _editor,
                                expands: true,
                                maxLines: null,
                                minLines: null,
                                textAlignVertical: TextAlignVertical.top,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  height: 1.55,
                                ),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.all(22),
                                  hintText: 'Write Markdown…',
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class ReadingPane extends StatelessWidget {
  const ReadingPane({super.key, required this.book});
  final BookDocument book;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 760;
    final List<String> lines = book.content.split('\n');
    const int linesPerChunk = 80;
    final int textChunks = (lines.length + linesPerChunk - 1) ~/ linesPerChunk;
    final int itemCount = textChunks + (book.media.isEmpty ? 0 : 1);
    return RepaintBoundary(
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 48,
          24,
          compact ? 16 : 48,
          80,
        ),
        itemCount: itemCount,
        itemBuilder: (BuildContext context, int index) {
        if (index < textChunks) {
          final int start = index * linesPerChunk;
          final int end = math.min(start + linesPerChunk, lines.length);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SelectableText(
              lines.sublist(start, end).join('\n'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.55,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Figures and diagrams', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              ...book.media.map(
                (BookMedia media) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      Uint8List.fromList(media.bytes),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Text('Unable to render ${media.name}'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        },
      ),
    );
    /*
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Keep preview scrolling responsive. MarkdownBody parses
                  // the complete manuscript synchronously; for large books
                  // that blocks the UI thread during every selection. The
                  // editor remains the authoritative Markdown surface, while
                  // preview uses a cheap selectable text layout.
                  SelectableText(
                    book.content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.55,
                    ),
                  ),
                  if (book.media.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 28),
                    const Text(
                      'Figures and diagrams',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...book.media.map(
                      (BookMedia media) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            Uint8List.fromList(media.bytes),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                Text('Unable to render ${media.name}'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );*/
  }
}

class MarkdownLine extends StatelessWidget {
  const MarkdownLine({super.key, required this.line});
  final String line;

  @override
  Widget build(BuildContext context) {
    if (line.trim().isEmpty) return const SizedBox(height: 12);
    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 18),
        child: Text(
          line.substring(2),
          style: const TextStyle(
            fontSize: 36,
            height: 1.12,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 10),
        child: Text(
          line.substring(3),
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
      );
    }
    if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(
          line.substring(4),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      );
    }
    if (line.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF171D29),
          border: Border(left: BorderSide(color: Color(0xFF7C5CFC), width: 4)),
        ),
        child: Text(
          line.substring(2),
          style: const TextStyle(fontStyle: FontStyle.italic, height: 1.65),
        ),
      );
    }
    if (line.trim() == '---')
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Divider(),
      );
    if (RegExp(r'^\s*[-*]\s+').hasMatch(line)) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('•  ', style: TextStyle(fontSize: 18)),
            Expanded(
              child: Text(
                line.replaceFirst(RegExp(r'^\s*[-*]\s+'), ''),
                style: const TextStyle(fontSize: 16, height: 1.65),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        line,
        style: const TextStyle(
          fontSize: 16,
          height: 1.72,
          color: Color(0xFFD7DCE6),
        ),
      ),
    );
  }
}

class GeneratorPanel extends StatefulWidget {
  const GeneratorPanel({
    super.key,
    required this.onGenerate,
    required this.busy,
  });
  final ValueChanged<GenerationRequest> onGenerate;
  final bool busy;

  @override
  State<GeneratorPanel> createState() => _GeneratorPanelState();
}

class _GeneratorPanelState extends State<GeneratorPanel> {
  final TextEditingController _title = TextEditingController(
    text: 'The Library That Writes Back',
  );
  final TextEditingController _premise = TextEditingController(
    text:
        'A rigorous account of libraries evolving from passive archives into systems that synthesize, question, explain, and revise knowledge.',
  );
  final TextEditingController _audience = TextEditingController(
    text: 'Technical readers, builders, researchers, and ambitious generalists',
  );
  final TextEditingController _voice = TextEditingController(
    text: 'Clear, visionary, evidence-aware, technically precise',
  );
  int _chapters = 8;
  String _depth = 'Advanced';
  bool _exercises = true;
  bool _sources = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _title.dispose();
    _premise.dispose();
    _audience.dispose();
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(34),
      children: <Widget>[
        const Text(
          'Generate a book',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Design the architecture first, then generate one chapter at a time into an editable manuscript.',
          style: TextStyle(color: Color(0xFF8A94A6)),
        ),
        const SizedBox(height: 28),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Book title',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _premise,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Premise and intellectual mission',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _audience,
                            decoration: const InputDecoration(
                              labelText: 'Audience',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _voice,
                            decoration: const InputDecoration(
                              labelText: 'Voice',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Chapters: $_chapters',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Slider(
                                value: _chapters.toDouble(),
                                min: 3,
                                max: 24,
                                divisions: 21,
                                onChanged: (double value) =>
                                    setState(() => _chapters = value.round()),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        DropdownMenu<String>(
                          initialSelection: _depth,
                          label: const Text('Depth'),
                          dropdownMenuEntries:
                              const <DropdownMenuEntry<String>>[
                                DropdownMenuEntry<String>(
                                  value: 'Accessible',
                                  label: 'Accessible',
                                ),
                                DropdownMenuEntry<String>(
                                  value: 'Advanced',
                                  label: 'Advanced',
                                ),
                                DropdownMenuEntry<String>(
                                  value: 'Research-grade',
                                  label: 'Research-grade',
                                ),
                              ],
                          onSelected: (String? value) =>
                              setState(() => _depth = value ?? _depth),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      value: _exercises,
                      onChanged: (bool? value) =>
                          setState(() => _exercises = value ?? false),
                      title: const Text(
                        'Include exercises and reflection prompts',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: _sources,
                      onChanged: (bool? value) =>
                          setState(() => _sources = value ?? false),
                      title: const Text(
                        'Include source-verification targets without fabricated citations',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.busy
                            ? null
                            : () => widget.onGenerate(
                                GenerationRequest(
                                  title: _title.text.trim(),
                                  premise: _premise.text.trim(),
                                  audience: _audience.text.trim(),
                                  voice: _voice.text.trim(),
                                  chapterCount: _chapters,
                                  depth: _depth,
                                  includeExercises: _exercises,
                                  includeSources: _sources,
                                ),
                              ),
                        icon: widget.busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(
                          widget.busy ? 'Generating…' : 'Build manuscript',
                        ),
                      ),
                    ),
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

class RepositoryPanel extends StatelessWidget {
  const RepositoryPanel({
    super.key,
    required this.owner,
    required this.repo,
    required this.branch,
    required this.directory,
    required this.books,
    required this.busy,
    required this.onScan,
    required this.onOpen,
  });

  final TextEditingController owner;
  final TextEditingController repo;
  final TextEditingController branch;
  final TextEditingController directory;
  final List<RepositoryBook> books;
  final bool busy;
  final VoidCallback onScan;
  final ValueChanged<RepositoryBook> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Repository library',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Recursively scan a GitHub repository, import its books, and publish edited Markdown editions.',
            style: TextStyle(color: Color(0xFF8A94A6)),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: owner,
                      decoration: const InputDecoration(labelText: 'Owner'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: repo,
                      decoration: const InputDecoration(
                        labelText: 'Repository',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: branch,
                      decoration: const InputDecoration(labelText: 'Branch'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 165,
                    child: TextField(
                      controller: directory,
                      decoration: const InputDecoration(
                        labelText: 'Publish folder',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: busy ? null : onScan,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.radar),
                    label: const Text('Scan'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: books.isEmpty
                ? const EmptyPanel(
                    icon: Icons.account_tree_outlined,
                    title: 'Repository not scanned',
                    body:
                        'Scan ornab74/books or another repository to catalog Markdown, text, and DOCX files.',
                  )
                : Card(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: books.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final RepositoryBook book = books[index];
                        return ListTile(
                          leading: Icon(
                            book.format == BookFormat.docx
                                ? Icons.description_outlined
                                : Icons.article_outlined,
                          ),
                          title: Text(book.name),
                          subtitle: Text(
                            '${book.path} · ${formatBytes(book.size)}',
                          ),
                          trailing: const Icon(Icons.download_rounded),
                          onTap: busy ? null : () => onOpen(book),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String formatBytes(int bytes) {
    if (bytes > 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes > 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.githubToken,
    required this.apiKey,
    required this.endpoint,
    required this.model,
    required this.provider,
    required this.onProviderChanged,
    required this.onSaveApiKey,
  });

  final TextEditingController githubToken;
  final TextEditingController apiKey;
  final TextEditingController endpoint;
  final TextEditingController model;
  final BookProvider provider;
  final ValueChanged<BookProvider> onProviderChanged;
  final VoidCallback onSaveApiKey;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(34),
      children: <Widget>[
        const Text(
          'Connections',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Secrets stay in memory for this session and are never written into the book library.',
          style: TextStyle(color: Color(0xFF8A94A6)),
        ),
        const SizedBox(height: 26),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.code),
                          title: Text(
                            'GitHub publishing',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Use a fine-grained token with Contents read/write permission only for target repositories.',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: githubToken,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'GitHub token',
                            prefixIcon: Icon(Icons.key),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.psychology_alt_outlined),
                          title: Text(
                            'OpenAI-compatible generation',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Works with hosted APIs or local servers exposing the chat-completions shape.',
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<BookProvider>(
                          initialValue: provider,
                          decoration: const InputDecoration(
                            labelText: 'Book generation model',
                            prefixIcon: Icon(Icons.tune_rounded),
                          ),
                          items: const <DropdownMenuItem<BookProvider>>[
                            DropdownMenuItem(
                              value: BookProvider.gemma4,
                              child: Text('Gemma 4 (local)'),
                            ),
                            DropdownMenuItem(
                              value: BookProvider.gpt56Luna,
                              child: Text('gpt-5.6-luna (OpenAI)'),
                            ),
                          ],
                          onChanged: (BookProvider? value) {
                            if (value != null) onProviderChanged(value);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: endpoint,
                          decoration: const InputDecoration(
                            labelText: 'Chat completions endpoint',
                            prefixIcon: Icon(Icons.link),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: model,
                                decoration: const InputDecoration(
                                  labelText: 'Model',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: apiKey,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'API key',
                                  prefixIcon: Icon(Icons.key),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: onSaveApiKey,
                          icon: const Icon(Icons.lock_rounded),
                          label: const Text(
                            'Save OpenAI key to encrypted vault',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 58, color: const Color(0xFF667085)),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8791A4), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
