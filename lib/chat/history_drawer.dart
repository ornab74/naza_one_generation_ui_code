// LLM-CONTEXT:BEGIN
// FILE: lib/chat/history_drawer.dart
// ROLE: Owns history drawer behavior within the conversation subsystem.
// DOMAIN: conversation
// SECURITY-INVARIANT: Preserve turn identity, cancellation semantics, and encrypted-history ownership across async work.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:async';

import 'package:flutter/material.dart';

final class NazaHistoryEntry {
  const NazaHistoryEntry({
    required this.threadId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.preview = '',
    this.pinned = false,
    this.messageCount = 0,
  });

  final String threadId;
  final String title;
  final String preview;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pinned;
  final int messageCount;

  NazaHistoryEntry copyWith({
    String? title,
    String? preview,
    DateTime? updatedAt,
    bool? pinned,
    int? messageCount,
  }) => NazaHistoryEntry(
    threadId: threadId,
    title: title ?? this.title,
    preview: preview ?? this.preview,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    pinned: pinned ?? this.pinned,
    messageCount: messageCount ?? this.messageCount,
  );
}

final class NazaConversationTitlePolicy {
  const NazaConversationTitlePolicy._();

  static String fallback(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'https?://\S+'), ' ')
        .replaceAll(RegExp(r'[`*_#>\[\]{}()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'New conversation';

    final words = cleaned
        .split(' ')
        .where((word) => word.length > 1)
        .where((word) => !_stop.contains(word.toLowerCase()))
        .take(6)
        .toList(growable: false);
    if (words.isEmpty) return 'New conversation';
    final title = words.join(' ');
    return '${title[0].toUpperCase()}${title.substring(1)}';
  }

  static String sanitizeModelTitle(String generated, String fallbackText) {
    var title = generated
        .replaceAll(RegExp(r'''^[\s"'`#*-]+|[\s"'`#*.-]+$'''), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final words = title.split(' ').where((word) => word.isNotEmpty).toList();
    if (title.isEmpty || words.length > 8 || title.length > 72) {
      return fallback(fallbackText);
    }
    if (words.length > 6) title = words.take(6).join(' ');
    return title;
  }

  static const Set<String> _stop = <String>{
    'a',
    'an',
    'the',
    'please',
    'can',
    'could',
    'would',
    'you',
    'me',
    'my',
    'i',
    'we',
    'our',
    'this',
    'that',
    'with',
    'for',
    'to',
    'of',
    'in',
    'on',
  };
}

typedef NazaGenerateConversationTitle =
    Future<String> Function({
      required String userText,
      required String assistantText,
    });

final class NazaConversationTitleCoordinator {
  NazaConversationTitleCoordinator({required this.generateTitle});

  final NazaGenerateConversationTitle generateTitle;
  final Set<String> _attempted = <String>{};
  final Map<String, Future<String>> _inFlight = <String, Future<String>>{};
  final Map<String, String> _completed = <String, String>{};

  Future<String> titleFor({
    required String threadId,
    required String userText,
    required String assistantText,
    bool force = false,
  }) {
    final fallback = NazaConversationTitlePolicy.fallback(userText);
    final completed = _completed[threadId];
    if (!force && completed != null) return Future.value(completed);
    if (!force && _attempted.contains(threadId)) return Future.value(fallback);
    final active = _inFlight[threadId];
    if (active != null) return active;

    _attempted.add(threadId);
    final future = () async {
      try {
        final generated = await generateTitle(
          userText: userText,
          assistantText: assistantText,
        );
        final title = NazaConversationTitlePolicy.sanitizeModelTitle(
          generated,
          userText,
        );
        _completed[threadId] = title;
        return title;
      } catch (_) {
        _attempted.remove(threadId);
        return fallback;
      } finally {
        _inFlight.remove(threadId);
      }
    }();
    _inFlight[threadId] = future;
    return future;
  }

  void allowRegeneration(String threadId) => _attempted.remove(threadId);
}

final class NazaHistoryDrawer extends StatefulWidget {
  const NazaHistoryDrawer({
    super.key,
    required this.entries,
    required this.activeThreadId,
    required this.onOpenThread,
    required this.onNewChat,
    required this.onClose,
    this.onRename,
    this.onDelete,
    this.onTogglePinned,
  });

  final List<NazaHistoryEntry> entries;
  final String? activeThreadId;
  final ValueChanged<String> onOpenThread;
  final VoidCallback onNewChat;
  final VoidCallback onClose;
  final FutureOr<void> Function(String threadId, String newTitle)? onRename;
  final FutureOr<void> Function(String threadId)? onDelete;
  final FutureOr<void> Function(String threadId, bool pinned)? onTogglePinned;

  @override
  State<NazaHistoryDrawer> createState() => _NazaHistoryDrawerState();
}

final class _NazaHistoryDrawerState extends State<NazaHistoryDrawer> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = _group(_filteredEntries(widget.entries, _query));

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: MediaQuery.sizeOf(context).width.clamp(300.0, 390.0),
            margin: const EdgeInsets.fromLTRB(10, 10, 0, 10),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: ColoredBox(
              color: scheme.surface,
              child: Column(
                children: <Widget>[
                  _header(context),
                  _searchBar(context),
                  Expanded(
                    child: groups.isEmpty
                        ? Center(
                            child: Text(
                              _query.isEmpty
                                  ? 'Your conversations will appear here.'
                                  : 'No conversations match “$_query”.',
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
                            children: <Widget>[
                              for (final group in groups) ...<Widget>[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    13,
                                    8,
                                    6,
                                  ),
                                  child: Text(
                                    group.key,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.7,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                for (final entry in group.value)
                                  _entryTile(context, entry),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary,
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Conversations',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                Text('Private local history', style: TextStyle(fontSize: 11.5)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close history',
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _searchBar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
    child: Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search past chats',
              prefixIcon: const Icon(Icons.search_rounded, size: 19),
              isDense: true,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: widget.onNewChat,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New'),
        ),
      ],
    ),
  );

  Widget _entryTile(BuildContext context, NazaHistoryEntry entry) {
    final active = entry.threadId == widget.activeThreadId;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active
            ? scheme.primaryContainer.withValues(alpha: 0.52)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => widget.onOpenThread(entry.threadId),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
            child: Row(
              children: <Widget>[
                Icon(
                  entry.pinned
                      ? Icons.push_pin_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 17,
                  color: active ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.title.isEmpty ? 'New conversation' : entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(entry),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _entryMenu(context, entry),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _entryMenu(BuildContext context, NazaHistoryEntry entry) {
    if (widget.onRename == null &&
        widget.onDelete == null &&
        widget.onTogglePinned == null) {
      return const SizedBox(width: 8);
    }
    return PopupMenuButton<String>(
      tooltip: 'Conversation actions',
      iconSize: 19,
      onSelected: (action) async {
        if (action == 'pin') {
          await widget.onTogglePinned?.call(entry.threadId, !entry.pinned);
        } else if (action == 'rename') {
          await _rename(context, entry);
        } else if (action == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Delete conversation?'),
              content: const Text(
                'This removes the conversation and its presentation metadata from the encrypted vault.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) await widget.onDelete?.call(entry.threadId);
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        if (widget.onTogglePinned != null)
          PopupMenuItem(
            value: 'pin',
            child: Text(entry.pinned ? 'Unpin' : 'Pin'),
          ),
        if (widget.onRename != null)
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
        if (widget.onDelete != null)
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Future<void> _rename(BuildContext context, NazaHistoryEntry entry) async {
    final controller = TextEditingController(text: entry.title);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 72,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.isNotEmpty) {
      await widget.onRename?.call(entry.threadId, value);
    }
  }

  static List<NazaHistoryEntry> _filteredEntries(
    List<NazaHistoryEntry> input,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    final entries = input
        .where((entry) {
          if (needle.isEmpty) return true;
          return entry.title.toLowerCase().contains(needle) ||
              entry.preview.toLowerCase().contains(needle);
        })
        .toList(growable: false);
    entries.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return entries;
  }

  static List<MapEntry<String, List<NazaHistoryEntry>>> _group(
    List<NazaHistoryEntry> entries,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<NazaHistoryEntry>>{};
    for (final entry in entries) {
      final local = entry.updatedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final delta = today.difference(day).inDays;
      final label = entry.pinned
          ? 'PINNED'
          : delta == 0
          ? 'TODAY'
          : delta == 1
          ? 'YESTERDAY'
          : delta < 7
          ? 'PREVIOUS 7 DAYS'
          : delta < 30
          ? 'PREVIOUS 30 DAYS'
          : 'OLDER';
      groups.putIfAbsent(label, () => <NazaHistoryEntry>[]).add(entry);
    }
    const order = <String>[
      'PINNED',
      'TODAY',
      'YESTERDAY',
      'PREVIOUS 7 DAYS',
      'PREVIOUS 30 DAYS',
      'OLDER',
    ];
    return order
        .where(groups.containsKey)
        .map(
          (key) => MapEntry<String, List<NazaHistoryEntry>>(key, groups[key]!),
        )
        .toList(growable: false);
  }

  static String _subtitle(NazaHistoryEntry entry) {
    final local = entry.updatedAt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    final preview = entry.preview.trim().replaceAll(RegExp(r'\s+'), ' ');
    final time = '$hour:$minute $suffix';
    return preview.isEmpty
        ? '$time · ${entry.messageCount} messages'
        : '$time · $preview';
  }
}
