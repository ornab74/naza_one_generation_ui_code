import 'dart:io';

import 'package:flutter/services.dart';
import 'package:naza_one/naza_rev_recall/models/car_profile.dart';
import 'package:path_provider/path_provider.dart';

class EngineAudioService {
  Process? _process;
  final Map<String, File> _cache = <String, File>{};

  Future<void> play(CarProfile car, {required double volume}) async {
    await stopAll();
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
      await SystemSound.play(SystemSoundType.click);
      return;
    }
    final file = await _materialize(car.assetPath);
    final normalizedVolume = volume.clamp(0.0, 1.0).toDouble();
    if (Platform.isLinux) {
      if (await File('/usr/bin/pw-play').exists()) {
        _process = await Process.start('/usr/bin/pw-play', <String>[
          '--volume',
          '$normalizedVolume',
          file.path,
        ], mode: ProcessStartMode.detachedWithStdio);
        return;
      }
      if (await File('/usr/bin/ffplay').exists()) {
        _process = await Process.start('/usr/bin/ffplay', <String>[
          '-nodisp',
          '-autoexit',
          '-loglevel',
          'quiet',
          '-volume',
          '${(normalizedVolume * 100).round()}',
          file.path,
        ], mode: ProcessStartMode.detachedWithStdio);
        return;
      }
    } else if (Platform.isMacOS) {
      _process = await Process.start('/usr/bin/afplay', <String>[
        '-v',
        '$normalizedVolume',
        file.path,
      ], mode: ProcessStartMode.detachedWithStdio);
      return;
    }
    await SystemSound.play(SystemSoundType.click);
  }

  Future<File> _materialize(String assetPath) async {
    final cached = _cache[assetPath];
    if (cached != null && await cached.exists()) return cached;
    final name = assetPath.split('/').last;
    if (!RegExp(r'^[a-z0-9_]+\.wav$').hasMatch(name)) {
      throw const FormatException('Unsafe Rev Recall audio asset name.');
    }
    final data = await rootBundle.load('assets/$assetPath');
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/naza_rev_recall_$name');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    _cache[assetPath] = file;
    return file;
  }

  Future<void> stopAll() async {
    _process?.kill(ProcessSignal.sigterm);
    _process = null;
  }

  Future<void> dispose() => stopAll();
}
