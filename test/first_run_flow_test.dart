import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/model/pausable_model_downloader.dart';
import 'package:naza_one/onboarding/boot_theme_catalog.dart';

void main() {
  test('first-run source keeps password requirement opt-in', () async {
    final source = await File('lib/onboarding/boot_coordinator.dart').readAsString();

    // Product invariant: encryption is mandatory, but the interactive boot
    // password is opt-in. The unchecked path passes passwordRequired=false to
    // the encrypted vault and uses the OS secure credential store.
    expect(source, contains('bool _requirePassword = false;'));
    expect(source, contains('_requirePassword = false; // UX default'));
    expect(
      source,
      contains('Require a password every time Naza One starts'),
    );
    expect(source, contains('passwordRequired: _requirePassword'));
    expect(source, contains("password: _requirePassword ? password : ''"));
  });

  test('main entrypoint is vault-first rather than model-first', () async {
    final source = await File('lib/main.dart').readAsString();
    expect(source, contains("import 'onboarding/boot_coordinator.dart';"));
    expect(source, contains('NazaBootCoordinator.launch()'));
    expect(source, isNot(contains('NazaModelBootstrap.launch()')));
  });

  test('first-run theme catalog is large and identifiers are unique', () {
    expect(NazaBootThemeCatalog.all.length, greaterThanOrEqualTo(24));
    final ids = NazaBootThemeCatalog.all.map((theme) => theme.id).toSet();
    expect(ids.length, NazaBootThemeCatalog.all.length);
    expect(
      NazaBootThemeCatalog.byId(NazaBootThemeCatalog.defaultId).id,
      NazaBootThemeCatalog.defaultId,
    );
  });

  test('download controller actually blocks while paused and resumes', () async {
    final controller = NazaTransferController()..pause();
    var released = false;
    final checkpoint = controller.checkpoint().then((_) => released = true);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(released, isFalse);
    expect(controller.isPaused, isTrue);

    controller.resume();
    await checkpoint.timeout(const Duration(seconds: 1));
    expect(released, isTrue);
    expect(controller.isPaused, isFalse);
  });

  test('both retained GitHub workflows are manual-only', () async {
    for (final path in <String>[
      '.github/workflows/flutter-release.yml',
      '.github/workflows/windows-store-msix.yml',
    ]) {
      final source = await File(path).readAsString();
      expect(source, contains('workflow_dispatch:'));
      expect(source, isNot(contains('\n  push:')));
      expect(source, isNot(contains('\n  pull_request:')));
    }
  });

  test('desktop local model preference is encrypted and hash gated', () async {
    final source = await File('lib/model/local_model_preference.dart').readAsString();
    expect(source, contains('NazaSecureDatabase'));
    expect(source, contains('writeJson(namespace, key, selection.toJson())'));
    expect(source, contains('crypto.sha256.bind(file.openRead())'));
    expect(source, contains("Platform.environment['NAZA_MODEL_PATH']"));
    expect(source, contains('materializeForApp'));
  });
}
