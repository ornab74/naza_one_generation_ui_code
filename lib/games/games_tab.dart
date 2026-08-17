import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../chess/chess_tab.dart';

class NazaGamesTab extends StatefulWidget {
  const NazaGamesTab({super.key});
  @override State<NazaGamesTab> createState() => _NazaGamesTabState();
}

class _NazaGamesTabState extends State<NazaGamesTab> {
  String? _open;
  @override
  Widget build(BuildContext context) {
    if (_open == 'chess') return const NazaChessTab();
    if (_open == 'revrecall') return _RevRecallGame(onBack: () => setState(() => _open = null));
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Games', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('Local games with resumable state, memory, and future agent modules.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 18),
      _GameCard(icon: Icons.grid_4x4_rounded, title: 'Chess Agent', subtitle: 'Deterministic board play with local agent guidance.', color: const Color(0xFFB8A1FF), onTap: () => setState(() => _open = 'chess')),
      _GameCard(icon: Icons.graphic_eq_rounded, title: 'REV//RECALL', subtitle: 'A neon sequence-memory game inspired by the referenced car-sound portfolio.', color: const Color(0xFFFF668D), onTap: () => setState(() => _open = 'revrecall')),
      Card(child: ListTile(leading: const Icon(Icons.lock_clock_rounded), title: const Text('Game memory'), subtitle: const Text('Scores, streaks, achievements, and resumable runs are designed for encrypted local persistence.'))),
    ]);
  }
}

class _GameCard extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final Color color; final VoidCallback onTap;
  const _GameCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  @override Widget build(BuildContext context) => Card(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Icon(icon, size: 38, color: color), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))])), const Icon(Icons.chevron_right_rounded)]))));
}

class _RevRecallGame extends StatefulWidget {
  final VoidCallback onBack; const _RevRecallGame({required this.onBack});
  @override State<_RevRecallGame> createState() => _RevRecallGameState();
}
class _RevRecallGameState extends State<_RevRecallGame> {
  final _random = math.Random(); final List<int> _sequence = []; final List<int> _input = [];
  int _round = 0; bool _showing = false; int? _flash; String _status = 'Start a memory run';
  void _start() { setState(() { _sequence..clear()..add(_random.nextInt(8)); _input.clear(); _round = 1; _status = 'Watch the sequence'; }); _replay(); }
  Future<void> _replay() async { setState(() => _showing = true); for (final value in _sequence) { if (!mounted) return; setState(() => _flash = value); await Future<void>.delayed(const Duration(milliseconds: 360)); if (!mounted) return; setState(() => _flash = null); await Future<void>.delayed(const Duration(milliseconds: 100)); } if (mounted) setState(() { _showing = false; _status = 'Your turn'; }); }
  void _tap(int value) { if (_showing || _sequence.isEmpty) return; setState(() { _input.add(value); _flash = value; }); if (_input.last != _sequence[_input.length - 1]) { setState(() => _status = 'Run over — ${_round - 1} rounds'); return; } if (_input.length == _sequence.length) { setState(() { _round++; _sequence.add(_random.nextInt(8)); _input.clear(); _status = 'Next sequence'; }); Future<void>.delayed(const Duration(milliseconds: 450), _replay); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)), title: const Text('REV//RECALL')), body: ListView(padding: const EdgeInsets.all(20), children: [Text('Round $_round', style: Theme.of(context).textTheme.headlineSmall), Text(_status), const SizedBox(height: 20), GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: 8, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10), itemBuilder: (_, i) => FilledButton(onPressed: () => _tap(i), style: FilledButton.styleFrom(backgroundColor: _flash == i ? Colors.white : Colors.pinkAccent), child: Text('${i + 1}'))), const SizedBox(height: 20), FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow), label: const Text('New memory run'))]));
}
