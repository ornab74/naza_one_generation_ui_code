import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final onePixelPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  test('portable picker normalizes a selected image for Gemma', () async {
    final picker = NazaVisionPicker(
      fileOpener: () async => XFile.fromData(
        onePixelPng,
        path: '/tmp/camera.sample.png',
        mimeType: 'image/png',
      ),
    );

    final result = await picker.pick();

    expect(
      result.outcome,
      NazaVisionPickOutcome.selected,
      reason: result.message,
    );
    expect(result.image, isNotNull);
    expect(result.image!.name, 'camera.sample.png');
    expect(result.image!.width, 1);
    expect(result.image!.height, 1);
    expect(result.image!.bytes, isNotEmpty);
    expect(
      result.image!.bytes.length,
      lessThanOrEqualTo(NazaAppConfig.visionMaxImageBytes),
    );
  });

  test('portable picker keeps a real dialog cancellation distinct', () async {
    final picker = NazaVisionPicker(fileOpener: () async => null);

    final result = await picker.pick();

    expect(result.outcome, NazaVisionPickOutcome.cancelled);
    expect(result.image, isNull);
    expect(result.message, isNull);
  });

  test('missing portable plugin is unavailable, not cancelled', () async {
    final picker = NazaVisionPicker(
      fileOpener: () async => throw MissingPluginException(),
    );

    final result = await picker.pick();

    expect(result.outcome, NazaVisionPickOutcome.unavailable);
    expect(result.message, contains('restart or rebuild'));
  });

  test('unsupported portable files return an actionable failure', () async {
    final picker = NazaVisionPicker(
      fileOpener: () async => XFile.fromData(
        onePixelPng,
        path: '/tmp/not-an-image.txt',
        mimeType: 'text/plain',
      ),
    );

    final result = await picker.pick();

    expect(result.outcome, NazaVisionPickOutcome.failed);
    expect(result.message, contains('JPEG, PNG, or WebP'));
  });
}
