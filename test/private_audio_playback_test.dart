import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('naza audio test ');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('creates unique owner-only containers before writing audio', () async {
    final directories = await Future.wait(
      List.generate(
        8,
        (_) =>
            NazaPrivateAudioPlaybackDirectory.create(root, prefix: 'playback-'),
      ),
    );
    expect(
      directories.map((directory) => directory.path).toSet(),
      hasLength(8),
    );
    for (final directory in directories) {
      expect(directory.parent.path, root.path);
      expect(await directory.list().toList(), isEmpty);
      if (!Platform.isWindows) {
        expect((await directory.stat()).mode & 0x1ff, 0x1c0);
      }
      final wav = File('${directory.path}${Platform.pathSeparator}voice.wav');
      await wav.writeAsBytes([1, 2, 3], flush: true);
      expect(await wav.readAsBytes(), [1, 2, 3]);
      await wav.delete();
      await directory.delete();
    }
    expect(await root.list().toList(), isEmpty);
  });

  test('fails closed if private directory creation fails', () async {
    await expectLater(
      NazaPrivateAudioPlaybackDirectory.create(
        Directory('${root.path}/missing/parent'),
        prefix: 'playback-',
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await root.list().toList(), isEmpty);
  });

  test('rejects path traversal and NULs without creating artifacts', () async {
    for (final prefix in ['../outside-', '/outside-', 'bad\u0000prefix']) {
      await expectLater(
        NazaPrivateAudioPlaybackDirectory.create(root, prefix: prefix),
        throwsA(isA<FileSystemException>()),
      );
    }
    expect(await root.list().toList(), isEmpty);
  });
}
