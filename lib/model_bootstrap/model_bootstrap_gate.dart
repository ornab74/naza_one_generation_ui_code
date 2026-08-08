import 'dart:async';

import 'package:flutter/material.dart';

import 'low_resource_model_seeder.dart';
import 'model_manifest.dart';
import 'secure_model_downloader.dart';

typedef AppLauncher = FutureOr<void> Function();

class ModelBootstrapGate extends StatefulWidget {
  const ModelBootstrapGate({
    required this.launchApp,
    required this.modelSeeder,
    super.key,
  });

  final AppLauncher launchApp;
  final LowResourceModelSeeder modelSeeder;

  @override
  State<ModelBootstrapGate> createState() => _ModelBootstrapGateState();
}

class _ModelBootstrapGateState extends State<ModelBootstrapGate> {
  late final SecureModelDownloader _downloader;
  ModelDownloadProgress _progress = const ModelDownloadProgress(
    phase: ModelDownloadPhase.checking,
  );
  ModelSeedStatus? _seedStatus;
  String? _error;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _downloader = SecureModelDownloader();
    scheduleMicrotask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    setState(() {
      _error = null;
      _seedStatus = null;
    });

    try {
      final model = await _downloader.ensureModel(
        manifest: primaryModelManifest,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );

      if (mounted) {
        setState(() {
          _seedStatus = const ModelSeedStatus(
            state: ModelSeedState.configuring,
            message: 'Preparing low-resource IPFS seeding.',
          );
        });
      }

      final seedStatus = await widget.modelSeeder.start(
        model: model,
        manifest: primaryModelManifest,
      );
      if (mounted) setState(() => _seedStatus = seedStatus);
      await _launch();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _launch() async {
    if (_launching) return;
    setState(() => _launching = true);
    await widget.launchApp();
  }

  @override
  void dispose() {
    _downloader.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF020806),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF07130F),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF1D5E49)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(blurRadius: 48, color: Color(0x5500E59B)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.shield_outlined,
                          size: 64,
                          color: Color(0xFF70F7C2),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Naza One Secure Model Setup',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _statusText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFB8CFC6), height: 1.45),
                        ),
                        const SizedBox(height: 24),
                        LinearProgressIndicator(
                          value: _seedStatus == null ? _progress.fraction : null,
                          minHeight: 9,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _detailText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF8CA79D),
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12,
                          ),
                        ),
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: 20),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D1510),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF80512F)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Color(0xFFFFD2AD)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: <Widget>[
                              FilledButton.icon(
                                onPressed: _bootstrap,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry securely'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _launch,
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('Continue without download'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 22),
                        const Text(
                          'Signed manifest • pinned key fingerprint • 3 immutable IPFS parts • SHA-256 verification',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF638579), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _statusText {
    if (_launching) return 'Opening the verified local AI workspace…';
    if (_error != null) return 'Model setup needs attention.';
    final seedStatus = _seedStatus;
    if (seedStatus != null) return seedStatus.message;
    switch (_progress.phase) {
      case ModelDownloadPhase.checking:
        return 'Checking the local model and pinned distribution identity.';
      case ModelDownloadPhase.fetchingManifest:
        return 'Fetching the immutable signed IPFS manifest bundle.';
      case ModelDownloadPhase.verifyingManifest:
        return 'Verifying the Ed25519 signature and pinned public-key fingerprint.';
      case ModelDownloadPhase.downloading:
        return 'Downloading and verifying the three immutable IPFS model parts.';
      case ModelDownloadPhase.reassembling:
        return 'Reassembling the verified parts in manifest order.';
      case ModelDownloadPhase.verifying:
        return 'Verifying the complete model SHA-256 before installation.';
      case ModelDownloadPhase.ready:
        return 'The model passed signed-manifest and full-file verification.';
    }
  }

  String get _detailText {
    final seedStatus = _seedStatus;
    if (seedStatus != null) {
      return switch (seedStatus.state) {
        ModelSeedState.seeding => '1 CPU thread • 256 MiB memory target • 8 connections max',
        ModelSeedState.unavailable => 'Kubo or cached seed parts unavailable; verified model still runs normally.',
        ModelSeedState.unsupported => 'Seeding is available on desktop platforms with Kubo.',
        _ => seedStatus.state.name.toUpperCase(),
      };
    }

    final host = _progress.gatewayHost;
    final received = _formatBytes(_progress.receivedBytes);
    final total = _progress.totalBytes;
    final part = _progress.partIndex;
    final partCount = _progress.partCount;
    final partText = part != null && partCount != null ? ' • part $part/$partCount' : '';
    if (host != null) {
      return total == null
          ? '$host • $received$partText'
          : '$host • $received / ${_formatBytes(total)}$partText';
    }
    if (total != null) return '$received / ${_formatBytes(total)}$partText';
    return _progress.phase.name.toUpperCase();
  }

  String _formatBytes(int bytes) {
    const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}
