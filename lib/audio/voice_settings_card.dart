// LLM-CONTEXT:BEGIN
// FILE: lib/audio/voice_settings_card.dart
// ROLE: Settings UI for read-aloud backend, speaker, cadence, and expression.
// DOMAIN: audio
// SECURITY-INVARIANT: Never reveal a saved token; persist it only through the encrypted settings store.
// CHANGE-GUARD: Keep Bark opt-in, label remote billing, and disclose synthetic speech.
// DOCS: See /docs/llm-context-schema.md and /lib/mermaid.md.
// LLM-CONTEXT:END
import 'dart:async';

import 'package:flutter/material.dart';

import 'voice_settings.dart';

final class NazaVoiceSettingsCard extends StatefulWidget {
  const NazaVoiceSettingsCard({super.key, required this.advanced});

  final bool advanced;

  @override
  State<NazaVoiceSettingsCard> createState() => _NazaVoiceSettingsCardState();
}

final class _NazaVoiceSettingsCardState extends State<NazaVoiceSettingsCard> {
  final NazaVoiceSettingsStore _store = NazaVoiceSettingsStore();
  final TextEditingController _replicateToken = TextEditingController();
  NazaVoiceSettings _settings = const NazaVoiceSettings();
  bool _loading = true;
  bool _saving = false;
  bool _showToken = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _replicateToken.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final settings = await _store.load();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = _message(error);
      });
    }
  }

  Future<void> _save() async {
    final enteredToken = _replicateToken.text.trim();
    final next = enteredToken.isEmpty
        ? _settings
        : _settings.copyWith(replicateApiToken: enteredToken);
    if (next.backend == NazaSpeechBackend.replicateBark &&
        next.replicateApiToken.isEmpty) {
      setState(() => _status = 'Enter a Replicate API token for Bark.');
      return;
    }
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      await _store.save(next);
      if (!mounted) return;
      setState(() {
        _settings = next;
        _replicateToken.clear();
        _status = next.backend == NazaSpeechBackend.replicateBark
            ? 'Bark voice and human cadence saved in the encrypted vault.'
            : 'OpenAI voice and human cadence saved.';
      });
    } catch (error) {
      if (mounted) setState(() => _status = _message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeReplicateToken() async {
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      final next = _settings.copyWith(
        backend: NazaSpeechBackend.openAi,
        clearReplicateApiToken: true,
      );
      await _store.save(next);
      if (!mounted) return;
      setState(() {
        _settings = next;
        _replicateToken.clear();
        _status = 'Replicate token removed; OpenAI voice restored.';
      });
    } catch (error) {
      if (mounted) setState(() => _status = _message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _update(NazaVoiceSettings next) => setState(() {
    _settings = next;
    _status = null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.spatial_audio_off_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Human voice performance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                if (_loading)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Clause-aware pacing changes speed gently, adds real rests, '
              'softens joins, and varies emotion without another model call. '
              'The voice you hear is AI-generated.',
              style: TextStyle(color: muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<NazaSpeechBackend>(
              key: ValueKey<NazaSpeechBackend>(_settings.backend),
              initialValue: _settings.backend,
              decoration: const InputDecoration(
                labelText: 'Read-aloud engine',
                prefixIcon: Icon(Icons.graphic_eq_rounded),
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<NazaSpeechBackend>>[
                for (final backend in NazaSpeechBackend.values)
                  DropdownMenuItem<NazaSpeechBackend>(
                    value: backend,
                    child: Text(backend.label),
                  ),
              ],
              onChanged: _saving || _loading
                  ? null
                  : (value) {
                      if (value != null) {
                        _update(_settings.copyWith(backend: value));
                      }
                    },
            ),
            const SizedBox(height: 12),
            if (_settings.backend == NazaSpeechBackend.openAi)
              _openAiControls(muted)
            else
              _barkControls(muted),
            if (widget.advanced) ...<Widget>[
              const Divider(height: 30),
              Text(
                'Performance shaping',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Values are intentionally bounded: human cadence drifts '
                'smoothly instead of jumping between sentences.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              _slider(
                title: 'Base speaking speed',
                value: _settings.baseSpeed,
                minimum: 0.84,
                maximum: 1.14,
                divisions: 30,
                valueLabel: '${_settings.baseSpeed.toStringAsFixed(2)}×',
                onChanged: (value) =>
                    _update(_settings.copyWith(baseSpeed: value)),
              ),
              _slider(
                title: 'Pace drift',
                value: _settings.paceVariation,
                minimum: 0,
                maximum: 0.16,
                divisions: 32,
                valueLabel: '±${(_settings.paceVariation * 100).round()}%',
                onChanged: (value) =>
                    _update(_settings.copyWith(paceVariation: value)),
              ),
              _slider(
                title: 'Rest length',
                value: _settings.pauseScale,
                minimum: 0.65,
                maximum: 1.65,
                divisions: 40,
                valueLabel: '${_settings.pauseScale.toStringAsFixed(2)}×',
                onChanged: (value) =>
                    _update(_settings.copyWith(pauseScale: value)),
              ),
              _slider(
                title: 'Rest variation',
                value: _settings.pauseVariation,
                minimum: 0,
                maximum: 0.60,
                divisions: 30,
                valueLabel: '±${(_settings.pauseVariation * 100).round()}%',
                onChanged: (value) =>
                    _update(_settings.copyWith(pauseVariation: value)),
              ),
              _slider(
                title: 'Emotional range',
                value: _settings.emotionStrength,
                minimum: 0,
                maximum: 1,
                divisions: 20,
                valueLabel: '${(_settings.emotionStrength * 100).round()}%',
                onChanged: (value) =>
                    _update(_settings.copyWith(emotionStrength: value)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rare conversational fillers'),
                subtitle: const Text(
                  'Context-safe “um/uh”; “ugh” only in negative passages.',
                ),
                value: _settings.disfluenciesEnabled,
                onChanged: _saving
                    ? null
                    : (value) => _update(
                        _settings.copyWith(disfluenciesEnabled: value),
                      ),
              ),
              if (_settings.disfluenciesEnabled)
                _slider(
                  title: 'Filler chance per thought',
                  value: _settings.disfluencyRate,
                  minimum: 0,
                  maximum: 0.25,
                  divisions: 25,
                  valueLabel: '${(_settings.disfluencyRate * 100).round()}%',
                  onChanged: (value) =>
                      _update(_settings.copyWith(disfluencyRate: value)),
                ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Subtle breaths'),
                subtitle: const Text(
                  'Very quiet shaped breaths are placed only inside long rests.',
                ),
                value: _settings.breathsEnabled,
                onChanged: _saving
                    ? null
                    : (value) =>
                          _update(_settings.copyWith(breathsEnabled: value)),
              ),
              if (_settings.breathsEnabled)
                _slider(
                  title: 'Breath chance per long rest',
                  value: _settings.breathRate,
                  minimum: 0,
                  maximum: 0.40,
                  divisions: 20,
                  valueLabel: '${(_settings.breathRate * 100).round()}%',
                  onChanged: (value) =>
                      _update(_settings.copyWith(breathRate: value)),
                ),
              _slider(
                title: 'Parallel voice requests',
                value: _settings.parallelRequests.toDouble(),
                minimum: 1,
                maximum: 3,
                divisions: 2,
                valueLabel: '${_settings.parallelRequests}',
                onChanged: (value) => _update(
                  _settings.copyWith(parallelRequests: value.round()),
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _saving || _loading ? null : _save,
              icon: const Icon(Icons.lock_rounded),
              label: Text(_saving ? 'Saving…' : 'Save voice setup'),
            ),
            if (_status != null) ...<Widget>[
              const SizedBox(height: 9),
              Text(_status!, style: TextStyle(color: muted)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _openAiControls(Color muted) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      DropdownButtonFormField<String>(
        key: ValueKey<String>(_settings.openAiVoice),
        initialValue: _settings.openAiVoice,
        decoration: const InputDecoration(
          labelText: 'OpenAI voice',
          helperText: 'Marin and Cedar are tuned for highest quality.',
          border: OutlineInputBorder(),
        ),
        items: <DropdownMenuItem<String>>[
          for (final voice in NazaVoiceSettings.openAiVoices)
            DropdownMenuItem<String>(value: voice, child: Text(_title(voice))),
        ],
        onChanged: _saving
            ? null
            : (value) {
                if (value != null) {
                  _update(_settings.copyWith(openAiVoice: value));
                }
              },
      ),
      const SizedBox(height: 8),
      Text(
        'Uses the enabled OpenAI profile already stored in the provider vault.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
    ],
  );

  Widget _barkControls(Color muted) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Bark is remote, generative, slower on a cold start, and billed by '
          'Replicate. Long readings use several short predictions. It can '
          'occasionally deviate from the written script.',
          style: TextStyle(height: 1.35, fontSize: 12),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey<String>(_settings.barkVoice),
        initialValue:
            NazaVoiceSettings.barkEnglishVoices.contains(_settings.barkVoice)
            ? _settings.barkVoice
            : NazaVoiceSettings.barkEnglishVoices.first,
        decoration: const InputDecoration(
          labelText: 'Bark speaker history prompt',
          border: OutlineInputBorder(),
        ),
        items: <DropdownMenuItem<String>>[
          for (final voice in NazaVoiceSettings.barkEnglishVoices)
            DropdownMenuItem<String>(value: voice, child: Text(voice)),
        ],
        onChanged: _saving
            ? null
            : (value) {
                if (value != null) {
                  _update(_settings.copyWith(barkVoice: value));
                }
              },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _replicateToken,
        obscureText: !_showToken,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: _settings.replicateApiToken.isEmpty
              ? 'Replicate API token'
              : 'Replicate token saved · leave blank to keep it',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: _showToken ? 'Hide token' : 'Show token',
            onPressed: () => setState(() => _showToken = !_showToken),
            icon: Icon(_showToken ? Icons.visibility_off : Icons.visibility),
          ),
        ),
      ),
      if (_settings.replicateApiToken.isNotEmpty)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _saving ? null : _removeReplicateToken,
            icon: const Icon(Icons.key_off_rounded, size: 17),
            label: const Text('Remove saved token'),
          ),
        ),
      if (widget.advanced) ...<Widget>[
        _slider(
          title: 'Bark text diversity',
          value: _settings.barkTextTemperature,
          minimum: 0.35,
          maximum: 1,
          divisions: 26,
          valueLabel: _settings.barkTextTemperature.toStringAsFixed(2),
          onChanged: (value) =>
              _update(_settings.copyWith(barkTextTemperature: value)),
        ),
        _slider(
          title: 'Bark waveform diversity',
          value: _settings.barkWaveformTemperature,
          minimum: 0.35,
          maximum: 1,
          divisions: 26,
          valueLabel: _settings.barkWaveformTemperature.toStringAsFixed(2),
          onChanged: (value) =>
              _update(_settings.copyWith(barkWaveformTemperature: value)),
        ),
      ],
      Text(
        'The token is never shown again and is sent only to api.replicate.com.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
    ],
  );

  Widget _slider({
    required String title,
    required double value,
    required double minimum,
    required double maximum,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) => Row(
    children: <Widget>[
      SizedBox(width: 164, child: Text(title)),
      Expanded(
        child: Slider(
          value: value.clamp(minimum, maximum),
          min: minimum,
          max: maximum,
          divisions: divisions,
          label: valueLabel,
          onChanged: _saving ? null : onChanged,
        ),
      ),
      SizedBox(width: 48, child: Text(valueLabel, textAlign: TextAlign.right)),
    ],
  );

  static String _title(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';

  static String _message(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('FormatException: ', '');
}
