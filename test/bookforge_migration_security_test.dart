import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory directory;
  late NazaSecureDatabase vault;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bookforge.library.v1': jsonEncode(<Object?>[_legacyBook()]),
    });
    directory = await Directory.systemTemp.createTemp('naza-bookforge-test-');
    vault = NazaSecureDatabase.forTesting(directory);
  });

  tearDown(() async {
    await vault.lock();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'legacy plaintext migration fails closed while vault is locked',
    () async {
      final store = LibraryStore(database: vault);

      await expectLater(
        store.load(),
        throwsA(
          isA<NazaVaultException>().having(
            (error) => error.code,
            'code',
            'locked',
          ),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bookforge.library.v1'), isNotNull);
    },
  );

  test(
    'successful migration removes plaintext before returning books',
    () async {
      await vault.create(password: 'bookforge-password');
      final store = LibraryStore(database: vault);

      final books = await store.load();

      expect(books, hasLength(1));
      expect(books.single.content, 'private manuscript');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bookforge.library.v1'), isNull);
      expect(
        await vault.readJson('bookforge', 'bookforge.library-index.v2'),
        <String>['book-1'],
      );
    },
  );
}

Map<String, Object?> _legacyBook() {
  final timestamp = DateTime.utc(2026, 1, 1).toIso8601String();
  return <String, Object?>{
    'id': 'book-1',
    'title': 'Private book',
    'author': 'Author',
    'content': 'private manuscript',
    'format': 'markdown',
    'origin': 'local',
    'status': 'draft',
    'createdAt': timestamp,
    'updatedAt': timestamp,
    'sourcePath': null,
    'repository': null,
    'tags': <String>[],
    'media': <Object?>[],
  };
}
