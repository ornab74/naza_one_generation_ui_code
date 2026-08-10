import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart' as app;
import '../onboarding/boot_theme_catalog.dart';
import '../security/secure_database.dart';

/// Fast-path launcher for an already-onboarded installation.
///
/// The first-run coordinator remains authoritative for vault setup, password
/// unlock, model installation, guide, and theme selection. Once onboarding is
/// complete, this shell opens the same stable home surface with a frame-paced
/// chat sender so native token delivery cannot force unbounded Flutter text
/// layout work on the UI thread.
final class NazaPerformanceRuntime {
  const NazaPerformanceRuntime._();

  static const String _onboardingNamespace = 'naza-first-run-v3';
  static const String _onboardingCompleteKey = 'complete';

  static Future<bool> tryLaunch() async {
    try {
      final inspection = await app.NazaVault.instance.inspect();
      switch (inspection.access) {
        case NazaVaultAccess.setupRequired:
          return false;
        case NazaVaultAccess.locked:
          if (inspection.passwordRequired) return false;
          await app.NazaVault.instance.unlockWithDeviceKey();
          break;
        case NazaVaultAccess.unlocked:
          break;
      }

      final completeRaw = await NazaSecureDatabase.instance.readJson(
        _onboardingNamespace,
        _onboardingCompleteKey,
      );
      final complete = completeRaw is Map && completeRaw['complete'] == true;
      if (!complete) return false;

      await app.NazaThemeStore.load();
      unawaited(app.NazaLocalGemma.instance.prepareBackendPreference());
      unawaited(app.NazaSecureModelStore.refresh());

      runApp(const _NazaPerformanceApp());
      return true;
    } catch (_) {
      // Fall back to the existing coordinator. It owns recovery UX and should
      // remain the single source of truth when the fast path cannot prove the
      // normal ready-state invariants.
      return false;
    }
  }
}

final class _NazaPerformanceApp extends StatelessWidget {
  const _NazaPerformanceApp();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: app.NazaThemeStore.selectedId,
      builder: (_, themeId, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Naza One',
          theme: NazaBootThemeCatalog.byId(themeId).build(),
          // Theme swaps should be atomic. Cross-fading a full desktop shell
          // creates avoidable UI-thread work exactly when every themed widget
          // is already rebuilding.
          themeAnimationDuration: Duration.zero,
          home: app.NazaStableHome(
            chatPromptSender: NazaFramePacedChatSender.send,
          ),
        );
      },
    );
  }
}

/// Adapts cumulative native streaming text to a bounded presentation surface.
///
/// The model still generates and retains the complete response. During the
/// active turn, Flutter only receives a compact head + live tail preview at an
/// adaptive cadence. This prevents the entire ever-growing response from being
/// reshaped and laid out on every native partial callback. The normal home
/// widget replaces this preview with the complete final response when [send]
/// returns, so no model output is lost.
final class NazaFramePacedChatSender {
  const NazaFramePacedChatSender._();

  static const int _maxLivePreviewChars = 1320;
  static const int _headChars = 360;
  static const int _tailChars = 860;

  static Future<app.NazaResponse> send(app.NazaChatPromptRequest request) async {
    Timer? pendingPaint;
    var latestNativeText = '';
    var lastVisibleText = '';
    var lastPaintAt = DateTime.fromMillisecondsSinceEpoch(0);
    var closed = false;

    void paintNow() {
      pendingPaint?.cancel();
      pendingPaint = null;
      if (closed || latestNativeText.isEmpty || request.onPartial == null) {
        return;
      }

      final visible = _livePreview(latestNativeText);
      if (visible == lastVisibleText) return;
      lastVisibleText = visible;
      lastPaintAt = DateTime.now();
      request.onPartial!(visible);
    }

    void onNativePartial(String partialText) {
      latestNativeText = partialText;
      if (request.onPartial == null || partialText.trim().isEmpty) return;

      // Preserve fast first-token feedback. Once text exists, pace future UI
      // updates according to how expensive the growing response would be to
      // shape and lay out if rendered in full.
      if (lastVisibleText.isEmpty) {
        paintNow();
        return;
      }

      final cadence = _cadenceFor(partialText.length);
      final elapsed = DateTime.now().difference(lastPaintAt);
      if (elapsed >= cadence) {
        paintNow();
        return;
      }

      pendingPaint ??= Timer(cadence - elapsed, paintNow);
    }

    try {
      return await app.NazaLocalGemma.instance.send(
        request.prompt,
        onPartial: onNativePartial,
        historyUserText: request.historyUserText,
        visionImage: request.visionImage,
        useMemory: request.useMemory,
        historyThreadId: request.historyThreadId,
        historyTurnId: request.historyTurnId,
        threadContext: request.threadContext,
        excludedMemoryTurnIds: request.excludedMemoryTurnIds,
        maxContinuationsOverride: request.maxContinuationsOverride,
        systemInstructionOverride: request.systemInstruction,
      );
    } finally {
      // Do not force one more expensive preview build immediately before the
      // home widget installs the complete final message.
      closed = true;
      pendingPaint?.cancel();
    }
  }

  static Duration _cadenceFor(int chars) {
    if (chars < 900) return const Duration(milliseconds: 480);
    if (chars < 2400) return const Duration(milliseconds: 760);
    return const Duration(milliseconds: 1100);
  }

  static String _livePreview(String text) {
    if (text.length <= _maxLivePreviewChars) return text;

    var headEnd = _headChars < text.length ? _headChars : text.length;
    var tailStart = text.length > _tailChars ? text.length - _tailChars : 0;

    // Avoid splitting UTF-16 surrogate pairs at either preview boundary.
    if (headEnd > 0 &&
        headEnd < text.length &&
        _isHighSurrogate(text.codeUnitAt(headEnd - 1))) {
      headEnd--;
    }
    if (tailStart > 0 &&
        tailStart < text.length &&
        _isLowSurrogate(text.codeUnitAt(tailStart))) {
      tailStart++;
    }

    if (tailStart <= headEnd) return text;
    return '${text.substring(0, headEnd)}\n\n'
        '… live response preview bounded for smooth rendering …\n\n'
        '${text.substring(tailStart)}';
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  static bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
}
