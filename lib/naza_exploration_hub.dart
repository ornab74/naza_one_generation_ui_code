// LLM-CONTEXT:BEGIN
// FILE: lib/naza_exploration_hub.dart
// ROLE: Owns naza exploration hub behavior within the application-core subsystem.
// DOMAIN: application-core
// SECURITY-INVARIANT: Preserve local-first privacy, bounded resource use, and explicit error handling.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef NazaExplorePrompt =
    Future<String> Function({
      required String systemInstruction,
      required String prompt,
      Uint8List? imageBytes,
    });
typedef NazaExploreImagePicker = Future<NazaExploreImage?> Function();

final class NazaExploreImage {
  final String name;
  final Uint8List bytes;
  final int width;
  final int height;
  const NazaExploreImage({
    required this.name,
    required this.bytes,
    this.width = 1,
    this.height = 1,
  });
}

final class _GardenLogEntry {
  final DateTime date;
  final String plant;
  final double height;
  final double width;
  final int health;
  final String kind;
  const _GardenLogEntry({required this.date, required this.plant, required this.height, required this.width, required this.health, required this.kind});
}

final class _GardenChartPainter extends CustomPainter {
  final List<_GardenLogEntry> entries;
  const _GardenChartPainter(this.entries);

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;
    final maxHeight = entries.map((e) => e.height).reduce(math.max);
    final maxWidth = entries.map((e) => e.width).reduce(math.max);
    final paint = Paint()..strokeWidth = 3..style = PaintingStyle.stroke;
    void line(double Function(_GardenLogEntry) value, Color color, double max) {
      paint.color = color;
      final path = Path();
      for (var i = 0; i < entries.length; i++) {
        final x = entries.length == 1 ? size.width / 2 : i * size.width / (entries.length - 1);
        final y = size.height - (value(entries[i]) / max.clamp(1, double.infinity)) * (size.height - 20);
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
      }
      canvas.drawPath(path, paint);
    }
    line((e) => e.height, const Color(0xFF42A5F5), maxHeight);
    line((e) => e.width, const Color(0xFF66BB6A), maxWidth);
    line((e) => e.health.toDouble(), const Color(0xFFFFB74D), 10);
  }

  @override
  bool shouldRepaint(covariant _GardenChartPainter oldDelegate) => oldDelegate.entries != entries;
}

enum NazaExplorationSection { findIt, garden, drive, predict, heartFlow }

extension NazaExplorationSectionX on NazaExplorationSection {
  String get label => switch (this) {
    NazaExplorationSection.findIt => 'FindIt',
    NazaExplorationSection.garden => 'Garden',
    NazaExplorationSection.drive => 'Drive',
    NazaExplorationSection.predict => 'Predict',
    NazaExplorationSection.heartFlow => 'Heart Flow',
  };
  IconData get icon => switch (this) {
    NazaExplorationSection.findIt => Icons.travel_explore_rounded,
    NazaExplorationSection.garden => Icons.eco_rounded,
    NazaExplorationSection.drive => Icons.directions_car_rounded,
    NazaExplorationSection.predict => Icons.query_stats_rounded,
    NazaExplorationSection.heartFlow => Icons.favorite_rounded,
  };
}

class NazaExplorationHub extends StatefulWidget {
  const NazaExplorationHub({
    super.key,
    required this.runPrompt,
    required this.pickGardenImage,
    this.initialSection = NazaExplorationSection.findIt,
  });
  final NazaExplorePrompt runPrompt;
  final NazaExploreImagePicker pickGardenImage;
  final NazaExplorationSection initialSection;
  @override
  State<NazaExplorationHub> createState() => _NazaExplorationHubState();
}

class _NazaExplorationHubState extends State<NazaExplorationHub> {
  static const int _maxGardenImages = 4;
  static const int _maxGardenBytes = 24 * 1024 * 1024;
  late final PageController _pages = PageController(
    initialPage: widget.initialSection.index,
  );
  final Map<NazaExplorationSection, TextEditingController> _details = {
    for (final section in NazaExplorationSection.values)
      section: TextEditingController(),
  };
  final _findLocation = TextEditingController(),
      _driveLocation = TextEditingController(),
      _driveDestination = TextEditingController();
  final _predictLocation = TextEditingController(),
      _heartName = TextEditingController(),
      _heartAge = TextEditingController(),
      _heartBaseline = TextEditingController();
  late NazaExplorationSection _section = widget.initialSection;
  bool _busy = false, _pickingImage = false;
  int _runGeneration = 0;
  String _result = '';
  String? _error;
  String _findPrompt = 'Compare nearby options',
      _gardenPrompt = 'Identify plant and health signals';
  String _drivePrompt = 'Plan a safe efficient route',
      _predictPrompt = 'Forecast demand and timing';
  String _heartPrompt = 'Recovery and readiness reflection';
  final List<NazaExploreImage> _gardenImages = <NazaExploreImage>[];
  final _gardenPlant = TextEditingController();
  final _gardenHeight = TextEditingController();
  final _gardenWidth = TextEditingController();
  final _gardenHealth = TextEditingController(text: '7');
  String _gardenKind = 'Plant';
  String? _selectedGardenOrganism;
  final List<_GardenLogEntry> _gardenLog = <_GardenLogEntry>[];

  @override
  void didUpdateWidget(covariant NazaExplorationHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection &&
        _section != widget.initialSection)
      _select(widget.initialSection, animate: false);
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final c in _details.values) {
      c.dispose();
    }
    for (final c in [
      _findLocation,
      _driveLocation,
      _driveDestination,
      _predictLocation,
      _heartName,
      _heartAge,
      _heartBaseline,
      _gardenPlant,
      _gardenHeight,
      _gardenWidth,
      _gardenHealth,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _select(NazaExplorationSection section, {bool animate = true}) {
    setState(() {
      _section = section;
      _result = '';
      _error = null;
    });
    if (!_pages.hasClients) return;
    animate
        ? _pages.animateToPage(
            section.index,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          )
        : _pages.jumpToPage(section.index);
  }

  Future<void> _pickGardenImage() async {
    if (_pickingImage || _busy) return;
    setState(() {
      _pickingImage = true;
      _error = null;
    });
    try {
      final image = await widget.pickGardenImage();
      if (!mounted || image == null) return;
      final totalBytes = _gardenImages.fold<int>(
        0,
        (sum, item) => sum + item.bytes.length,
      );
      if (image.bytes.isEmpty || image.bytes.length > 8 * 1024 * 1024) {
        setState(() => _error = 'Choose a non-empty image under 8 MB.');
        return;
      }
      if (_gardenImages.length >= _maxGardenImages ||
          totalBytes + image.bytes.length > _maxGardenBytes) {
        setState(() => _error = 'Garden supports up to 4 photos and 24 MB total.');
        return;
      }
      setState(() => _gardenImages.add(image));
    } catch (_) {
      if (mounted)
        setState(() => _error = 'The camera image could not be opened.');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  String? _validate() {
    if (_details[_section]!.text.trim().isEmpty)
      return 'Add details about what you want analyzed.';
    return switch (_section) {
      NazaExplorationSection.findIt when _findLocation.text.trim().isEmpty =>
        'Add a city, neighborhood, address, or area for FindIt.',
      NazaExplorationSection.garden when _gardenImages.isEmpty =>
        'Capture or choose a garden photo first.',
      NazaExplorationSection.drive when _driveLocation.text.trim().isEmpty =>
        'Add your starting location or service area.',
      NazaExplorationSection.predict
          when _predictLocation.text.trim().isEmpty =>
        'Add the market or operating location for this prediction.',
      NazaExplorationSection.heartFlow when _heartName.text.trim().isEmpty =>
        'Add a name or private profile label.',
      _ => null,
    };
  }

  Future<void> _run() async {
    final int runId = ++_runGeneration;
    final NazaExplorationSection requestedSection = _section;
    final invalid = _validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _result = '';
      _error = null;
    });
    try {
      final text = await widget.runPrompt(
        systemInstruction: _systemInstruction,
        prompt: _buildPrompt(),
        imageBytes: _section == NazaExplorationSection.garden
            ? (_gardenImages.isEmpty ? null : _gardenImages.first.bytes)
            : null,
      );
      if (text.trim().isEmpty) {
        throw const FormatException('The model returned no usable analysis.');
      }
      if (mounted && runId == _runGeneration && _section == requestedSection) {
        setState(() => _result = text);
      }
    } catch (_) {
      if (mounted && runId == _runGeneration)
        setState(() => _error = 'Unable to run the local analysis. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _systemInstruction => switch (_section) {
    NazaExplorationSection.findIt =>
      'You are Naza FindIt. Use only the supplied location. Never claim live availability, distance, hours, or prices. Label assumptions and verification steps.',
    NazaExplorationSection.garden =>
      'You are Naza Garden vision intelligence. Describe visible evidence before hypotheses. Never claim certainty from one image. Give low-risk care steps.',
    NazaExplorationSection.drive =>
      'You are Naza Drive. Prioritize safety. Never claim live traffic, closures, or route status. Use location details only for this response.',
    NazaExplorationSection.predict =>
      'You are Naza Predict. Produce scenarios, not facts. State assumptions, confidence, sensitivity, missing data, and invalidation signals.',
    NazaExplorationSection.heartFlow =>
      'You are Naza Heart Flow. Provide reflective wellness modeling, not diagnosis or emergency guidance. Avoid identity inference and explain uncertainty.',
  };
  String _buildPrompt() {
    final details = _details[_section]!.text.trim();
    final context = switch (_section) {
      NazaExplorationSection.findIt =>
        'Task: $_findPrompt\nLocation: ${_findLocation.text.trim()}\nPreferences: $details',
      NazaExplorationSection.garden =>
        'Task: $_gardenPrompt\nSubject type: $_gardenKind\nImages (${_gardenImages.length}): ${_gardenImages.map((image) => '${image.name} (${image.width}x${image.height})').join(', ')}\nLogged observations: ${_gardenLog.map((e) => '${e.kind}:${e.plant}, height=${e.height}cm, width=${e.width}cm, health=${e.health}/10').join('; ')}\nObservations/request: $details',
      NazaExplorationSection.drive =>
        'Task: $_drivePrompt\nStart/service area: ${_driveLocation.text.trim()}\nDestination: ${_optional(_driveDestination)}\nConstraints: $details',
      NazaExplorationSection.predict =>
        'Task: $_predictPrompt\nMarket/location: ${_predictLocation.text.trim()}\nScenario/timeframe/signals: $details',
      NazaExplorationSection.heartFlow =>
        'Task: $_heartPrompt\nPrivate profile: ${_heartName.text.trim()}\nAge/range: ${_optional(_heartAge)}\nResting baseline: ${_optional(_heartBaseline)}\nActivity/sleep/stress/symptoms/goals: $details',
    };
    return 'Workspace: ${_section.label}\n$context\n\nReturn: supplied context, analysis, assumptions, uncertainty/confidence, safety limits, and next actions. Do not invent live facts or missing measurements.';
  }

  String _optional(TextEditingController c) =>
      c.text.trim().isEmpty ? 'not supplied' : c.text.trim();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Icon(Icons.explore_rounded, color: Color(0xFF64D8FF)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Naza Intelligence',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const Chip(
            avatar: Icon(Icons.lock_outline_rounded, size: 16),
            label: Text('Gemma 4 · local only'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: NazaExplorationSection.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = NazaExplorationSection.values[i];
            return ChoiceChip(
              avatar: Icon(s.icon, size: 17),
              label: Text(s.label),
              selected: s == _section,
              onSelected: (_) => _select(s),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: PageView.builder(
          controller: _pages,
          itemCount: NazaExplorationSection.values.length,
          onPageChanged: (i) => setState(() {
            _section = NazaExplorationSection.values[i];
            _result = '';
            _error = null;
          }),
          itemBuilder: (_, i) => _body(NazaExplorationSection.values[i]),
        ),
      ),
    ],
  );

  Widget _body(NazaExplorationSection section) {
    final descriptions = {
      NazaExplorationSection.findIt:
          'Location-grounded discovery with explicit verification steps.',
      NazaExplorationSection.garden:
          'Photo-assisted plant observations and care experiments.',
      NazaExplorationSection.drive:
          'Private route context, stops, delivery areas, and driving constraints.',
      NazaExplorationSection.predict:
          'Location-aware demand, timing, staffing, and inventory scenarios.',
      NazaExplorationSection.heartFlow:
          'Personalized recovery and readiness reflections—not diagnosis.',
    };
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(section.icon, size: 30),
                    const SizedBox(width: 10),
                    Text(
                      section.label,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  descriptions[section]!,
                  style: const TextStyle(color: Color(0xFF9BA7B8)),
                ),
                const SizedBox(height: 18),
                ..._fields(section),
                if (_error != null && section == _section) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    key: const ValueKey('explore-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _busy || section != _section ? null : _run,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _busy ? 'Running locally…' : 'Run with Gemma 4 local',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_result.isNotEmpty && section == _section)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                _result,
                style: const TextStyle(height: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _fields(NazaExplorationSection s) {
    final details = TextField(
      controller: _details[s],
      minLines: 3,
      maxLines: 6,
      maxLength: 4000,
      decoration: InputDecoration(
        labelText: _detailLabel(s),
        hintText: _detailHint(s),
        border: const OutlineInputBorder(),
      ),
    );
    return switch (s) {
      NazaExplorationSection.findIt => [
        _field(
          _findLocation,
          'Location or search area',
          'City, neighborhood, address, landmark, or region',
          Icons.location_on_rounded,
        ),
        _gap,
        _dropdown('FindIt request', _findPrompt, [
          'Compare nearby options',
          'Find a specific place or service',
          'Plan a local outing',
          'Compare camping or outdoor areas',
          'Build a verification checklist',
        ], (v) => _findPrompt = v),
                _gap,
        if (s == NazaExplorationSection.garden) ...[
          _dropdown('Garden subject', _gardenKind, const ['Plant', 'Mushroom', 'Soil / habitat'], (v) => _gardenKind = v),
          _gap,
          if (_gardenLog.isNotEmpty)
            _dropdown('Previously logged subject', _selectedGardenOrganism ?? 'New observation', [
              'New observation',
              ..._gardenLog.map((e) => e.plant).toSet(),
            ], (v) {
              _selectedGardenOrganism = v == 'New observation' ? null : v;
              if (_selectedGardenOrganism != null) _gardenPlant.text = _selectedGardenOrganism!;
            }),
          if (_gardenLog.isNotEmpty) _gap,
          Row(children: [
            Expanded(child: _field(_gardenPlant, 'Plant name', 'Tomato, basil, unknown…', Icons.local_florist)),
            const SizedBox(width: 8),
            Expanded(child: _field(_gardenHeight, 'Height (cm)', 'Estimated or measured', Icons.height)),
            const SizedBox(width: 8),
            Expanded(child: _field(_gardenWidth, 'Width (cm)', 'Estimated canopy width', Icons.straighten)),
          ]),
          _gap,
          _field(_gardenHealth, 'Health rating (0–10)', 'Your observation; not a diagnosis', Icons.health_and_safety_outlined),
          _gap,
          OutlinedButton.icon(
            onPressed: _gardenLogEntry,
            icon: const Icon(Icons.add_chart_rounded),
            label: const Text('Save garden observation'),
          ),
          if (_gardenLog.isNotEmpty) ...[
            _gap,
            SizedBox(height: 180, child: CustomPaint(painter: _GardenChartPainter(_gardenLog))),
          ],
          _gap,
        ],
        details,
      ],
      NazaExplorationSection.garden => [
        _dropdown('Garden request', _gardenPrompt, [
          'Identify plant and health signals',
          'Diagnose visible stress cautiously',
          'Create a care schedule',
          'Compare growth over time',
          'Plan soil, watering, and light experiment',
          'Check pest or disease evidence',
        ], (v) => _gardenPrompt = v),
        _gap,
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('garden-camera'),
                onPressed: _pickingImage || _gardenImages.length >= _maxGardenImages
                    ? null
                    : _pickGardenImage,
                icon: Icon(
                  _gardenImages.isEmpty
                      ? Icons.add_a_photo_rounded
                      : Icons.photo_camera_back_rounded,
                ),
                label: Text(
                  _pickingImage
                      ? 'Opening camera…'
                      : _gardenImages.isEmpty
                      ? 'Capture / choose photo'
                      : 'Add another photo (${_gardenImages.length}/$_maxGardenImages)',
                ),
              ),
            ),
            if (_gardenImages.isNotEmpty)
              IconButton(
                tooltip: 'Remove all photos',
                onPressed: () => setState(() => _gardenImages.clear()),
                icon: const Icon(Icons.delete_sweep_rounded),
              ),
          ],
        ),
        if (_gardenImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _gardenImages.length; i++)
                  InputChip(
                    label: Text('${i + 1}. ${_gardenImages[i].name}'),
                    onDeleted: () => setState(() => _gardenImages.removeAt(i)),
                  ),
              ],
            ),
          ),
        _gap,
        details,
      ],
      NazaExplorationSection.drive => [
        _field(
          _driveLocation,
          'Starting location or service area',
          'Address, neighborhood, city, or operating zone',
          Icons.my_location_rounded,
        ),
        _gap,
        _field(
          _driveDestination,
          'Destination or route area (optional)',
          'Destination, stops, or delivery zone',
          Icons.flag_rounded,
        ),
        _gap,
        _dropdown('Drive request', _drivePrompt, [
          'Plan a safe efficient route',
          'Organize multiple stops',
          'Create a delivery-area plan',
          'Compare route scenarios',
          'Prepare a pre-drive safety checklist',
        ], (v) => _drivePrompt = v),
        _gap,
        details,
      ],
      NazaExplorationSection.predict => [
        _field(
          _predictLocation,
          'Prediction market or location',
          'Store area, city, region, route, venue, or market',
          Icons.public_rounded,
        ),
        _gap,
        _dropdown('Prediction type', _predictPrompt, [
          'Forecast demand and timing',
          'Model staffing scenarios',
          'Estimate inventory pressure',
          'Compare purchase or traffic heat',
          'Run best/base/worst-case scenarios',
        ], (v) => _predictPrompt = v),
        _gap,
        details,
      ],
      NazaExplorationSection.heartFlow => [
        _field(
          _heartName,
          'Name or private profile label',
          'Alex or Morning training profile',
          Icons.person_rounded,
        ),
        _gap,
        Row(
          children: [
            Expanded(
              child: _field(
                _heartAge,
                'Age / range (optional)',
                '34 or 30–39',
                Icons.cake_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _field(
                _heartBaseline,
                'Resting baseline (optional)',
                '62 bpm',
                Icons.monitor_heart_rounded,
              ),
            ),
          ],
        ),
        _gap,
        _dropdown('Heart Flow request', _heartPrompt, [
          'Recovery and readiness reflection',
          'Compare exertion and baseline',
          'Explore stress and sleep patterns',
          'Prepare questions for a clinician',
          'Build a gentle activity scenario',
        ], (v) => _heartPrompt = v),
        _gap,
        details,
      ],
    };
  }

  Widget get _gap => const SizedBox(height: 12);
  Widget _field(
    TextEditingController c,
    String label,
    String hint,
    IconData icon,
  ) => TextField(
    controller: c,
    maxLength: 500,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
      counterText: '',
    ),
  );
  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> change,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: options
        .map(
          (o) => DropdownMenuItem(
            value: o,
            child: Text(o, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (v) {
      if (v != null) setState(() => change(v));
    },
  );

  void _gardenLogEntry() {
    final height = double.tryParse(_gardenHeight.text.trim());
    final width = double.tryParse(_gardenWidth.text.trim());
    final health = int.tryParse(_gardenHealth.text.trim());
    if (height == null || width == null || health == null || height <= 0 || width <= 0 || health < 0 || health > 10) {
      setState(() => _error = 'Enter positive height and width estimates to save a garden observation.');
      return;
    }
    setState(() {
      _gardenLog.add(_GardenLogEntry(
        date: DateTime.now(),
        plant: _gardenPlant.text.trim().isEmpty ? 'Unnamed plant' : _gardenPlant.text.trim(),
        height: height,
        width: width,
        health: health,
        kind: _gardenKind,
      ));
      _error = null;
    });
  }
  String _detailLabel(NazaExplorationSection s) => switch (s) {
    NazaExplorationSection.findIt => 'What should FindIt locate or compare?',
    NazaExplorationSection.garden => 'Garden details and your request',
    NazaExplorationSection.drive => 'Route constraints and request details',
    NazaExplorationSection.predict =>
      'Scenario, timeframe, signals, and constraints',
    NazaExplorationSection.heartFlow =>
      'Recent activity, sleep, stress, symptoms, and goals',
  };
  String _detailHint(NazaExplorationSection s) => switch (s) {
    NazaExplorationSection.findIt =>
      'Budget, distance, accessibility, dates, must-haves…',
    NazaExplorationSection.garden =>
      'Plant type, weather, watering, soil, light, visible changes…',
    NazaExplorationSection.drive =>
      'Stops, vehicle, timing, avoidances, delivery constraints…',
    NazaExplorationSection.predict =>
      'What to predict, horizon, known data, assumptions…',
    NazaExplorationSection.heartFlow =>
      'Include only what you are comfortable using locally.',
  };
}
