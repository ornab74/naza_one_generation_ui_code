import 'package:flutter/material.dart';

import '../security/boundary_sanitizer.dart';
import 'data_pipes.dart';

class NazaDataPipesSurface extends StatefulWidget {
  const NazaDataPipesSurface({super.key, this.store});
  final NazaDataPipeStore? store;
  @override
  State<NazaDataPipesSurface> createState() => _NazaDataPipesSurfaceState();
}

class _NazaDataPipesSurfaceState extends State<NazaDataPipesSurface> {
  late final NazaDataPipeStore _store = widget.store ?? NazaDataPipeStore();
  final _name = TextEditingController(text: 'Secure research pipe');
  final _url = TextEditingController();
  final _domains = TextEditingController();
  final _image = TextEditingController();
  int _maxPages = 10;
  bool _saving = false;
  String _status = 'No remote operation runs without explicit approval.';

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _domains.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _queue() async {
    setState(() => _saving = true);
    try {
      final now = DateTime.now().toUtc();
      final plan = NazaDataPipePlan(
        id: 'pipe-${now.microsecondsSinceEpoch}',
        name: NazaBoundarySanitizer.databaseText(
          _name.text,
          maxCharacters: 100,
        ),
        targetUrl: NazaBoundarySanitizer.remoteText(
          _url.text,
          maxCharacters: 2048,
          redactSecrets: true,
        ),
        allowedDomains: _domains.text
            .split(',')
            .map((v) => v.trim().toLowerCase())
            .where((v) => v.isNotEmpty)
            .take(32)
            .toList(),
        image: _image.text.trim(),
        maxPages: _maxPages,
        createdAt: now,
      );
      await _store.savePlan(plan);
      if (mounted)
        setState(
          () => _status =
              'Pipeline queued for human approval. No droplet was created.',
        );
    } catch (error) {
      if (mounted)
        setState(
          () => _status =
              'Rejected: ${NazaBoundarySanitizer.databaseText(error.toString(), maxCharacters: 300)}',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF06100F),
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Data Pipes / Scraping',
          style: TextStyle(
            color: Color(0xFFF0FFF8),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Plan an ephemeral DigitalOcean worker, pinned hardened Chromium container, proxy-only allowlisted crawl, verified result transfer, encrypted local SQLite import, and automatic teardown.',
          style: TextStyle(color: Color(0xFFA8BDB5), height: 1.4),
        ),
        const SizedBox(height: 18),
        _field(_name, 'Pipeline name'),
        _field(_url, 'HTTPS target URL'),
        _field(_domains, 'Allowed domains (comma separated)'),
        _field(_image, 'Pinned OCI image@sha256:<digest>'),
        Row(
          children: [
            const Text(
              'Maximum pages',
              style: TextStyle(color: Color(0xFFA8BDB5)),
            ),
            Expanded(
              child: Slider(
                value: _maxPages.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                label: '$_maxPages',
                onChanged: (v) => setState(() => _maxPages = v.round()),
              ),
            ),
            Text(
              '$_maxPages',
              style: const TextStyle(color: Color(0xFFF0FFF8)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving ? null : _queue,
          icon: const Icon(Icons.add_task_rounded),
          label: Text(_saving ? 'Validating…' : 'Queue for approval'),
        ),
        const SizedBox(height: 14),
        Text(_status, style: const TextStyle(color: Color(0xFF76E3B4))),
        const SizedBox(height: 20),
        const Text(
          'Enforced boundary',
          style: TextStyle(
            color: Color(0xFFF0FFF8),
            fontWeight: FontWeight.w700,
          ),
        ),
        const Text(
          '• robots.txt required • no cookies • immutable image digest • non-root/read-only/no-new-privileges • capabilities dropped • proxy-only egress • 64 MiB/10,000-row import bounds • sentinel checks at provision, deploy, scrape, and teardown • secrets never enter model prompts',
          style: TextStyle(color: Color(0xFFA8BDB5), height: 1.5),
        ),
      ],
    ),
  );

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      style: const TextStyle(color: Color(0xFFF0FFF8)),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFF0D1B19),
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
