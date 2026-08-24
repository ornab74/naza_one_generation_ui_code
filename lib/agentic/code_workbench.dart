import 'dart:io';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/material.dart';

/// Human-facing code viewer/editor for the Code Foundry.
///
/// Loading is bounded and saving is an explicit local mutation. Remote node
/// execution is deliberately not hidden behind this editor; a future
/// transport must supply its own approval and host-key policy boundary.
final class NazaCodeWorkbench extends StatefulWidget {
  const NazaCodeWorkbench({super.key});

  @override
  State<NazaCodeWorkbench> createState() => _NazaCodeWorkbenchState();
}

final class _NazaCodeWorkbenchState extends State<NazaCodeWorkbench> {
  static const _violet = Color(0xFFAA93FF);
  static const _cyan = Color(0xFF62D9F7);
  static const _mint = Color(0xFF76E3B4);
  static const _ink = Color(0xFF06100F);
  static const _panel = Color(0xFF0D1B19);
  static const _border = Color(0xFF29433D);
  static const _text = Color(0xFFF0FFF8);
  static const _subtext = Color(0xFFA8BDB5);
  static const _maxBytes = 320000;

  final _editor = TextEditingController();
  String _original = '';
  String _path = '';
  String _status = 'Select a source file to open the human code surface.';
  bool _diff = false;
  bool _saving = false;

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final selected = await file_selector.openFile(
      acceptedTypeGroups: [
        file_selector.XTypeGroup(
          label: 'Source',
          extensions: const [
            'dart',
            'py',
            'js',
            'ts',
            'tsx',
            'jsx',
            'rs',
            'go',
            'java',
            'kt',
            'swift',
            'c',
            'cpp',
            'h',
            'hpp',
            'json',
            'yaml',
            'yml',
            'md',
            'txt',
            'sql',
            'html',
            'css',
            'scss',
          ],
        ),
      ],
    );
    if (selected == null || selected.path.trim().isEmpty) return;
    final selectedPath = selected.path;
    final file = File(selectedPath);
    final stat = await file.stat();
    if (stat.size > _maxBytes) {
      if (mounted)
        setState(() => _status = 'File exceeds the 320 KiB viewer boundary.');
      return;
    }
    final text = await file.readAsString();
    if (!mounted) return;
    setState(() {
      _path = selectedPath;
      _original = text;
      _editor.text = text;
      _status = 'Opened ${_basename(selectedPath)} · ${text.length} characters';
      _diff = false;
    });
  }

  Future<void> _save() async {
    if (_path.isEmpty || _saving || _editor.text == _original) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Write local file?'),
        content: Text(
          'This will replace the contents of ${_basename(_path)}. The Code Foundry will not write remote nodes from this editor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save local file'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    setState(() {
      _saving = true;
      _status = 'Writing approved local edit';
    });
    try {
      await File(_path).writeAsString(_editor.text, flush: true);
      if (mounted)
        setState(() {
          _original = _editor.text;
          _saving = false;
          _status = 'Saved ${_basename(_path)}';
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _saving = false;
          _status = 'Save failed: $error';
        });
    }
  }

  String _diffText() {
    final before = _original.split('\n');
    final after = _editor.text.split('\n');
    final lines = <String>[
      '--- a/${_basename(_path)}',
      '+++ b/${_basename(_path)}',
    ];
    final count = before.length > after.length ? before.length : after.length;
    for (var i = 0; i < count; i++) {
      final left = i < before.length ? before[i] : null;
      final right = i < after.length ? after[i] : null;
      if (left == right && left != null) {
        lines.add(' $left');
      } else {
        if (left != null) lines.add('-$left');
        if (right != null) lines.add('+$right');
      }
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final changed = _editor.text != _original;
    return Card(
      color: _panel.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.code_rounded, color: _cyan),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Human code studio',
                    style: TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Open source file',
                  onPressed: _open,
                  icon: const Icon(Icons.folder_open_rounded, color: _subtext),
                ),
                IconButton(
                  tooltip: 'Toggle diff',
                  onPressed: _path.isEmpty
                      ? null
                      : () => setState(() => _diff = !_diff),
                  icon: Icon(
                    Icons.compare_arrows_rounded,
                    color: _diff ? _mint : _subtext,
                  ),
                ),
                IconButton(
                  tooltip: 'Save approved local edit',
                  onPressed: changed ? _save : null,
                  icon: Icon(
                    _saving ? Icons.hourglass_top_rounded : Icons.save_rounded,
                    color: changed ? _violet : _subtext,
                  ),
                ),
              ],
            ),
            Text(
              _path.isEmpty
                  ? _status
                  : '${_basename(_path)} · ${changed ? 'unsaved changes' : 'clean'}',
              style: const TextStyle(color: _subtext, fontSize: 11),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 380,
              child: _diff
                  ? SingleChildScrollView(
                      child: SelectableText(
                        _diffText(),
                        style: const TextStyle(
                          color: _text,
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    )
                  : TextField(
                      controller: _editor,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(
                        color: _text,
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        height: 1.45,
                      ),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: _ink,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: _border),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _basename(String path) =>
      path.split(RegExp(r'[/\\]')).where((part) => part.isNotEmpty).last;
}
