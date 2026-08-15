import 'package:flutter/material.dart';

typedef NazaExplorePrompt = Future<String> Function({required String systemInstruction, required String prompt});

class NazaExplorationHub extends StatefulWidget {
  const NazaExplorationHub({super.key, required this.runPrompt});
  final NazaExplorePrompt runPrompt;
  @override State<NazaExplorationHub> createState() => _NazaExplorationHubState();
}

class _NazaExplorationHubState extends State<NazaExplorationHub> {
  final PageController _pages = PageController();
  final TextEditingController _input = TextEditingController();
  int _index = 0;
  bool _busy = false;
  String _result = '';
  String _model = 'Gemma 4 local';
  static const _sections = <String>['FindIt', 'Garden', 'Drive', 'Predict', 'Heart Flow'];
  @override void dispose() { _pages.dispose(); _input.dispose(); super.dispose(); }
  Future<void> _run() async {
    if (_input.text.trim().isEmpty) return;
    setState(() { _busy = true; _result = ''; });
    final name = _sections[_index];
    final prompt = 'Workspace: $name\nUser request: ${_input.text.trim()}\nReturn structured recommendations with assumptions, uncertainty, safety limits, and next actions. Do not invent live facts.';
    try { final text = await widget.runPrompt(systemInstruction: 'You are Naza $name intelligence. Be rigorous and privacy-preserving.', prompt: prompt); if (mounted) setState(() => _result = text); } catch (error) { if (mounted) setState(() => _result = 'Unable to run analysis: $error'); }
    if (mounted) setState(() => _busy = false);
  }
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
    Row(children: <Widget>[const Icon(Icons.explore_rounded, color: Color(0xFF64D8FF)), const SizedBox(width: 10), const Expanded(child: Text('Naza Intelligence', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))), DropdownButton<String>(value: _model, items: const [DropdownMenuItem(value: 'Gemma 4 local', child: Text('Gemma 4 local')), DropdownMenuItem(value: 'gpt-5.6-luna', child: Text('gpt-5.6-luna'))], onChanged: (v) { if (v != null) setState(() => _model = v); })]),
    const SizedBox(height: 12),
    SizedBox(height: 48, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _sections.length, separatorBuilder: (_, _) => const SizedBox(width: 8), itemBuilder: (_, i) => ChoiceChip(label: Text(_sections[i]), selected: i == _index, onSelected: (_) { setState(() { _index = i; _result = ''; }); _pages.animateToPage(i, duration: const Duration(milliseconds: 240), curve: Curves.easeOut); }))),
    const SizedBox(height: 12),
    Expanded(child: PageView.builder(controller: _pages, itemCount: _sections.length, onPageChanged: (i) => setState(() => _index = i), itemBuilder: (_, i) => _sectionBody(_sections[i]))),
  ]);
  Widget _sectionBody(String name) { const descriptions = <String, String>{'FindIt': 'Bake discovery, camping spots, and local place comparison.', 'Garden': 'Plant growth logs, photo observations, and care experiments.', 'Drive': 'Delivery location memory, route notes, and stop planning.', 'Predict': 'Demand, timing, purchase heatmaps, staffing, and inventory scenarios.', 'Heart Flow': 'Reflective heart-rate and recovery simulations, not diagnosis.'}; return ListView(children: <Widget>[Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(descriptions[name]!, style: const TextStyle(color: Color(0xFF9BA7B8))), const SizedBox(height: 18), TextField(controller: _input, maxLines: 4, decoration: InputDecoration(labelText: 'Explore $name', border: const OutlineInputBorder())), const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _busy ? null : _run, icon: const Icon(Icons.auto_awesome), label: Text(_busy ? 'Running...' : 'Run with $_model')))]))), if (_result.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(20), child: SelectableText(_result, style: const TextStyle(height: 1.5))))]); }
}
