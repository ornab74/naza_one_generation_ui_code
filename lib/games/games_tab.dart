import 'package:flutter/material.dart';
import '../chess/chess_tab.dart';
import '../naza_rev_recall/rev_recall.dart';

class NazaGamesTab extends StatefulWidget {
  const NazaGamesTab({super.key, this.initialGame});
  final String? initialGame;
  @override
  State<NazaGamesTab> createState() => _NazaGamesTabState();
}

class _NazaGamesTabState extends State<NazaGamesTab> {
  late String? _open = widget.initialGame;
  @override
  Widget build(BuildContext context) {
    if (_open == 'chess') return const NazaChessTab();
    if (_open == 'revrecall') return const RevRecallBootstrap();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Games',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Local games with resumable state, memory, and future agent modules.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        _GameCard(
          icon: Icons.grid_4x4_rounded,
          title: 'Chess Agent',
          subtitle: 'Deterministic board play with local agent guidance.',
          color: const Color(0xFFB8A1FF),
          onTap: () => setState(() => _open = 'chess'),
        ),
        _GameCard(
          icon: Icons.graphic_eq_rounded,
          title: 'REV//RECALL',
          subtitle:
              'A neon sequence-memory game inspired by the referenced car-sound portfolio.',
          color: const Color(0xFFFF668D),
          onTap: () => setState(() => _open = 'revrecall'),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_clock_rounded),
            title: const Text('Game memory'),
            subtitle: const Text(
              'Scores, streaks, achievements, and resumable runs are designed for encrypted local persistence.',
            ),
          ),
        ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _GameCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 38, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}
