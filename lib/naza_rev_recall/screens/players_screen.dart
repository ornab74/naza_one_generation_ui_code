import 'package:flutter/material.dart';
import 'package:naza_one/naza_rev_recall/app/app_scope.dart';
import 'package:naza_one/naza_rev_recall/app/app_theme.dart';
import 'package:naza_one/naza_rev_recall/models/game_models.dart';
import 'package:naza_one/naza_rev_recall/widgets/neon_widgets.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'PARTY PLAYERS',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        Text(
                          '${app.partyPlayers.length}/8',
                          style: const TextStyle(color: AppColors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ...app.partyPlayers.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _PlayerTile(
                          player: entry.value,
                          position: entry.key + 1,
                          canRemove: app.partyPlayers.length > 2,
                          onRemove: () => app.removePartyPlayer(entry.value.id),
                          onRename: () => _renamePlayer(context, entry.value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    NeonButton(
                      label: 'Add Driver',
                      icon: Icons.person_add_alt_1_rounded,
                      enabled: app.partyPlayers.length < 8,
                      onPressed: () => _addPlayer(context),
                    ),
                    const SizedBox(height: 14),
                    NeonPanel(
                      borderColor: AppColors.cyan.withValues(alpha: 0.4),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.cyan,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Party Mode uses one phone. Pass it to the highlighted driver after each round. '
                              'Each driver has three lives and an independent score.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addPlayer(BuildContext context) async {
    final name = await _nameDialog(context, title: 'Add driver');
    if (name != null && context.mounted) {
      AppScope.of(context).addPartyPlayer(name);
    }
  }

  Future<void> _renamePlayer(BuildContext context, PartyPlayer player) async {
    final name = await _nameDialog(
      context,
      title: 'Rename driver',
      initialValue: player.name,
    );
    if (name != null && context.mounted) {
      AppScope.of(context).renamePartyPlayer(player.id, name);
    }
  }

  Future<String?> _nameDialog(
    BuildContext context, {
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 12,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Driver name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.trim().isEmpty == true ? null : result;
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.player,
    required this.position,
    required this.canRemove,
    required this.onRemove,
    required this.onRename,
  });

  final PartyPlayer player;
  final int position;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return NeonPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: player.color.withValues(alpha: 0.55),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: player.color.withValues(alpha: 0.18),
            foregroundColor: player.color,
            child: Text(
              '$position',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '3 starting lives',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(onPressed: onRename, icon: const Icon(Icons.edit_rounded)),
          IconButton(
            onPressed: canRemove ? onRemove : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: AppColors.red,
          ),
        ],
      ),
    );
  }
}
