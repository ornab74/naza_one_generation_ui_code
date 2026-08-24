// LLM-CONTEXT:BEGIN
// FILE: test/first_run_flow_test.dart
// ROLE: Owns first run flow test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/app.dart' as app;
import 'package:naza_one/model/pausable_model_downloader.dart';
import 'package:naza_one/onboarding/boot_theme_catalog.dart';

void main() {
  test('first-run source keeps password requirement platform-safe', () async {
    final source = await File(
      'lib/onboarding/boot_coordinator.dart',
    ).readAsString();

    // Product invariant: encryption is mandatory. Desktop Linux defaults to
    // a password because headless sessions may not expose Secret Service;
    // other platforms can use the OS secure credential store by default.
    expect(source, contains('bool _requirePassword = Platform.isLinux;'));
    expect(
      source,
      contains('false; // UX default: encrypted, no boot password.'),
    );
    expect(source, contains('Require a password every time Naza One starts'));
    expect(source, contains('passwordRequired: _requirePassword'));
    expect(source, contains("password: _requirePassword ? password : ''"));
  });

  test('main entrypoint is vault-first rather than model-first', () async {
    final source = await File('lib/main.dart').readAsString();
    expect(source, contains("import 'onboarding/boot_coordinator.dart';"));
    expect(source, contains('NazaBootCoordinator.launch()'));
    expect(source, isNot(contains('NazaModelBootstrap.launch()')));
  });

  test('password unlock can hand off to automatic model preparation', () async {
    final source = await File(
      'lib/onboarding/boot_coordinator.dart',
    ).readAsString();
    expect(source, contains('allowBusyHandoff: true'));
    expect(source, contains('if (_busy && !allowBusyHandoff) return;'));
  });

  test(
    'startup checks the managed model attestation before local preference hashing',
    () async {
      final source = await File(
        'lib/onboarding/boot_coordinator.dart',
      ).readAsString();
      final refresh = source.indexOf("'managed model cache refresh',");
      final restore = source.indexOf("'restore preferred local model',");
      expect(refresh, greaterThanOrEqualTo(0));
      expect(restore, greaterThan(refresh));
    },
  );

  test('startup traces each trusted-model handoff await', () async {
    final source = await File(
      'lib/onboarding/boot_coordinator.dart',
    ).readAsString();
    expect(source, contains("'managed model cache refresh'"));
    expect(source, contains("'restore preferred local model'"));
    expect(
      source,
      contains("'managed model cache refresh after local restore'"),
    );
    expect(source, contains("'authenticated automatic chat handoff'"));
    expect(source, contains("NazaBootDiagnostics.failure"));
  });

  test(
    'first run requires and downloads the separate safety sentinel',
    () async {
      final source = await File(
        'lib/onboarding/boot_coordinator.dart',
      ).readAsString();
      expect(source, contains('bool get _allModelsReady'));
      expect(source, contains('_modelReady && _sentinelReady'));
      expect(source, contains('NazaSentinelModelStore.isInstalled()'));
      expect(
        source,
        contains('NazaModelDistributionManifest.llama3SmallSentinel'),
      );
      expect(source, contains('Download safety sentinel'));
    },
  );

  test('remote frontier egress excludes Chat from the sentinel', () async {
    final source = await File('lib/app.dart').readAsString();
    expect(source, contains('feature != NazaModelFeature.chat'));
    expect(source, contains("'frontier.\${feature.name}.request'"));
  });

  test(
    'model store cannot poison refresh after target path resolution fails',
    () async {
      final source = await File('lib/app.dart').readAsString();
      final refresh = source.indexOf(
        'static Future<NazaModelStoreStatus> _refreshInner() async',
      );
      final target = source.indexOf(
        'final target = await _targetFile();',
        refresh,
      );
      final tryStart = source.indexOf('try {', refresh);
      final cleanup = source.indexOf('_refreshFuture = null;', target);
      expect(refresh, greaterThanOrEqualTo(0));
      expect(target, greaterThan(tryStart));
      expect(cleanup, greaterThan(target));
    },
  );

  test('first-run theme catalog is large and identifiers are unique', () {
    expect(NazaBootThemeCatalog.all.length, greaterThanOrEqualTo(24));
    final ids = NazaBootThemeCatalog.all.map((theme) => theme.id).toSet();
    expect(ids.length, NazaBootThemeCatalog.all.length);
    expect(
      NazaBootThemeCatalog.byId(NazaBootThemeCatalog.defaultId).id,
      NazaBootThemeCatalog.defaultId,
    );
  });

  test(
    'theme settings and closed-model recovery stay wired into the app',
    () async {
      final source = await File('lib/app.dart').readAsString();
      expect(source, contains('ValueNotifier<String> selectedId'));
      expect(source, contains('NazaThemeStore.select(option.id)'));
      expect(source, contains('bool _isClosedModelError(Object error)'));
      expect(source, contains('reopening the closed local model'));
      expect(source, contains('reloadClosedModel: true'));
      expect(source, contains('NazaThreadContext.fromRows'));
      expect(source, contains('class _HistoryThreadCard'));
      expect(source, isNot(contains('class _RecentConversationDrawer')));
      expect(source, contains('bool _followOutput = true;'));
    },
  );

  test('advanced memory settings remain bounded and backward compatible', () {
    final defaults = app.NazaMemorySettings.defaults();
    expect(defaults.enabled, isTrue);
    expect(defaults.maxRetrievedChunks, inInclusiveRange(2, 8));
    expect(defaults.candidateLimit, inInclusiveRange(24, 180));
    expect(defaults.diversity, inInclusiveRange(0.0, 0.72));

    final restored = app.NazaMemorySettings.fromJson({
      'enabled': true,
      'maxRetrievedChunks': 999,
      'candidateLimit': 1,
      'diversity': 4,
      'autoConsolidation': false,
    });
    expect(restored.maxRetrievedChunks, 8);
    expect(restored.candidateLimit, 24);
    expect(restored.diversity, 0.72);
    expect(restored.autoConsolidation, isFalse);
  });

  test(
    'download controller actually blocks while paused and resumes',
    () async {
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
    },
  );

  test(
    'both retained GitHub workflows gate pushes and pull requests',
    () async {
      for (final path in <String>[
        '.github/workflows/flutter-release.yml',
        '.github/workflows/windows-store-msix.yml',
      ]) {
        final source = await File(path).readAsString();
        expect(source, contains('workflow_dispatch:'));
        expect(source, contains('\n  push:'));
        expect(source, contains('\n  pull_request:'));
      }
    },
  );

  test('desktop local model preference is encrypted and hash gated', () async {
    final source = await File(
      'lib/model/local_model_preference.dart',
    ).readAsString();
    expect(source, contains('NazaSecureDatabase'));
    expect(source, contains('writeJson(namespace, key, selection.toJson())'));
    expect(source, contains('crypto.sha256.bind(file.openRead())'));
    expect(source, contains("Platform.environment['NAZA_MODEL_PATH']"));
    expect(source, contains('materializeForApp'));
  });
}
