// LLM-CONTEXT:BEGIN
// FILE: lib/navigation/unified_feature_drawer.dart
// ROLE: Owns unified feature drawer behavior within the navigation subsystem.
// DOMAIN: navigation
// SECURITY-INVARIANT: Resolve navigation only through the closed in-process destination registry; persisted IDs never carry callbacks.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A closed, in-process navigation target. Persisted data contains IDs only;
/// callbacks and labels always come from this trusted registry.
final class NazaFeatureDestination {
  final String id;
  final String label;
  final String description;
  final String category;
  final IconData icon;
  final Color accent;
  final VoidCallback onOpen;

  const NazaFeatureDestination({
    required this.id,
    required this.label,
    required this.description,
    required this.category,
    required this.icon,
    required this.accent,
    required this.onOpen,
  });
}

final class NazaFeaturePinPolicy {
  static const String requiredId = 'chat';
  static const int maxPins = 7;
  static const List<String> defaults = <String>[
    requiredId,
    'road-scanner',
    'food-scanner',
  ];

  const NazaFeaturePinPolicy._();

  static List<String> sanitize(Iterable<Object?> raw, Set<String> allowed) {
    final clean = <String>[requiredId];
    for (final value in raw) {
      if (value is! String ||
          value == requiredId ||
          !allowed.contains(value) ||
          clean.contains(value)) {
        continue;
      }
      clean.add(value);
      if (clean.length == maxPins) break;
    }
    return clean;
  }

  static List<String> initial(Set<String> allowed) =>
      sanitize(defaults, allowed);
}

final class NazaFeaturePinStore {
  static const _key = 'naza.navigation.feature_pins.v1';

  const NazaFeaturePinStore();

  Future<List<String>> load(Set<String> allowed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key);
      return raw == null
          ? NazaFeaturePinPolicy.initial(allowed)
          : NazaFeaturePinPolicy.sanitize(raw, allowed);
    } catch (_) {
      return NazaFeaturePinPolicy.initial(allowed);
    }
  }

  Future<bool> save(Iterable<String> ids, Set<String> allowed) async {
    final clean = NazaFeaturePinPolicy.sanitize(ids, allowed);
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setStringList(_key, clean);
    } catch (_) {
      return false;
    }
  }
}

/// The single mobile navigation entry point. A compact pinned dock opens the
/// same drawer used for discovery, rotation, deep links, and pin management.
final class NazaUnifiedFeatureDrawer extends StatefulWidget {
  final List<NazaFeatureDestination> destinations;
  final String selectedId;
  final Color surface;
  final Color panel;
  final Color border;
  final Color text;
  final Color subtext;

  const NazaUnifiedFeatureDrawer({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.surface,
    required this.panel,
    required this.border,
    required this.text,
    required this.subtext,
  });

  @override
  State<NazaUnifiedFeatureDrawer> createState() =>
      _NazaUnifiedFeatureDrawerState();
}

class _NazaUnifiedFeatureDrawerState extends State<NazaUnifiedFeatureDrawer> {
  final NazaFeaturePinStore _store = const NazaFeaturePinStore();
  List<String> _pins = NazaFeaturePinPolicy.defaults;
  bool _loaded = false;

  Set<String> get _allowed => widget.destinations.map((e) => e.id).toSet();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant NazaUnifiedFeatureDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.destinations, widget.destinations)) {
      final clean = NazaFeaturePinPolicy.sanitize(_pins, _allowed);
      if (!_sameIds(clean, _pins)) {
        _pins = clean;
        unawaited(_store.save(clean, _allowed));
      }
    }
  }

  Future<void> _load() async {
    final pins = await _store.load(_allowed);
    if (!mounted) return;
    setState(() {
      _pins = pins;
      _loaded = true;
    });
  }

  Future<void> _togglePin(String id) async {
    if (!_loaded) {
      _message('Loading your saved wheel settings…');
      return;
    }
    if (!_allowed.contains(id)) return;
    if (id == NazaFeaturePinPolicy.requiredId) {
      _message('Chat stays pinned in the center.');
      return;
    }
    final next = List<String>.from(_pins);
    if (next.remove(id)) {
      _message('Removed from your wheel.');
    } else {
      if (next.length >= NazaFeaturePinPolicy.maxPins) {
        _message(
          'Your wheel can hold up to ${NazaFeaturePinPolicy.maxPins} pins.',
        );
        return;
      }
      next.add(id);
      _message('Pinned to your wheel.');
    }
    final clean = NazaFeaturePinPolicy.sanitize(next, _allowed);
    final previous = List<String>.from(_pins);
    final saved = await _store.save(clean, _allowed);
    if (!mounted) return;
    if (saved) {
      setState(() => _pins = clean);
      _message(next.contains(id) ? 'Pinned to your wheel.' : 'Removed from your wheel.');
    } else {
      setState(() => _pins = previous);
      _message('Could not save wheel settings. Your previous pins were kept.');
    }
  }

  void _message(String value) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(value),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
        ),
      );
  }

  NazaFeatureDestination? _byId(String id) {
    for (final destination in widget.destinations) {
      if (destination.id == id) return destination;
    }
    return null;
  }

  void _open(NazaFeatureDestination destination) {
    HapticFeedback.selectionClick();
    destination.onOpen();
  }

  Future<void> _showDrawer() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _FeatureWheelSheet(
          destinations: widget.destinations,
          pins: _pins,
          selectedId: widget.selectedId,
          surface: widget.surface,
          panel: widget.panel,
          border: widget.border,
          text: widget.text,
          subtext: widget.subtext,
          onOpen: (destination) {
            Navigator.of(sheetContext).pop();
            _open(destination);
          },
          onTogglePin: (id) async {
            await _togglePin(id);
            if (sheetContext.mounted) setSheetState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _pins
        .map(_byId)
        .whereType<NazaFeatureDestination>()
        .toList();
    return Semantics(
      container: true,
      label: 'Feature wheel navigation',
      child: Container(
        key: const ValueKey<String>('unified-feature-drawer'),
        height: 72,
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
        decoration: BoxDecoration(
          color: widget.surface,
          border: Border(top: BorderSide(color: widget.border)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pinned.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (context, index) {
                  final item = pinned[index];
                  final selected = item.id == widget.selectedId;
                  return _PinnedDockButton(
                    destination: item,
                    selected: selected,
                    text: widget.text,
                    subtext: widget.subtext,
                    border: widget.border,
                    onTap: () => _open(item),
                    onLongPress: item.id == NazaFeaturePinPolicy.requiredId
                        ? null
                        : () => _togglePin(item.id),
                  );
                },
              ),
            ),
            const SizedBox(width: 7),
            Semantics(
              button: true,
              label: 'Open all features',
              hint: 'Tap to open the draggable feature wheel',
              child: IconButton.filled(
                key: const ValueKey<String>('open-feature-wheel'),
                tooltip: 'Explore features',
                onPressed: _loaded ? _showDrawer : null,
                icon: const Icon(Icons.blur_circular_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: widget.panel,
                  foregroundColor: widget.text,
                  side: BorderSide(color: widget.border),
                  minimumSize: const Size(52, 52),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Desktop presentation of the same allowlisted registry and persisted pins.
/// The rail stays compact while its orbit button reveals every destination.
final class NazaUnifiedFeatureRail extends StatefulWidget {
  final List<NazaFeatureDestination> destinations;
  final String selectedId;
  final Color surface, panel, border, text, subtext;

  const NazaUnifiedFeatureRail({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.surface,
    required this.panel,
    required this.border,
    required this.text,
    required this.subtext,
  });

  @override
  State<NazaUnifiedFeatureRail> createState() => _NazaUnifiedFeatureRailState();
}

class _NazaUnifiedFeatureRailState extends State<NazaUnifiedFeatureRail> {
  final _store = const NazaFeaturePinStore();
  List<String> _pins = NazaFeaturePinPolicy.defaults;
  Set<String> get _allowed => widget.destinations.map((e) => e.id).toSet();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final pins = await _store.load(_allowed);
    if (mounted) setState(() => _pins = pins);
  }

  @override
  void didUpdateWidget(covariant NazaUnifiedFeatureRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.destinations, widget.destinations)) {
      final clean = NazaFeaturePinPolicy.sanitize(_pins, _allowed);
      if (clean.length != _pins.length ||
          clean.asMap().entries.any((entry) => entry.value != _pins[entry.key])) {
        _pins = clean;
        unawaited(_store.save(clean, _allowed));
      }
    }
  }

  NazaFeatureDestination? _byId(String id) {
    for (final item in widget.destinations) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _toggle(String id) async {
    if (!_allowed.contains(id) || id == NazaFeaturePinPolicy.requiredId) return;
    final next = List<String>.from(_pins);
    if (!next.remove(id)) {
      if (next.length >= NazaFeaturePinPolicy.maxPins) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unpin a feature before adding another.'),
            ),
          );
        return;
      }
      next.add(id);
    }
    final clean = NazaFeaturePinPolicy.sanitize(next, _allowed);
    setState(() => _pins = clean);
    await _store.save(clean, _allowed);
  }

  void _open(NazaFeatureDestination item) {
    HapticFeedback.selectionClick();
    item.onOpen();
  }

  Future<void> _showAll() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => Dialog(
          backgroundColor: widget.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: widget.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 10, 10),
                  child: Row(
                    children: [
                      Icon(Icons.blur_circular_rounded, color: widget.text),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Feature orbit',
                              style: TextStyle(
                                color: widget.text,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Open any feature · hold to pin or unpin',
                              style: TextStyle(color: widget.subtext),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisExtent: 126,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: widget.destinations.length,
                    itemBuilder: (_, index) {
                      final item = widget.destinations[index],
                          pinned = _pins.contains(item.id),
                          selected = item.id == widget.selectedId;
                      return Semantics(
                        button: true,
                        selected: selected,
                        label: item.label,
                        hint: pinned
                            ? 'Long press to unpin'
                            : 'Long press to pin',
                        child: Material(
                          color: Color.alphaBlend(
                            item.accent.withValues(alpha: selected ? .22 : .10),
                            widget.panel,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _open(item);
                            },
                            onLongPress: () async {
                              await _toggle(item.id);
                              if (dialogContext.mounted) updateDialog(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: pinned ? item.accent : widget.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: item.accent.withValues(
                                          alpha: .18,
                                        ),
                                        child: Icon(
                                          item.icon,
                                          color: item.accent,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        pinned
                                            ? Icons.push_pin_rounded
                                            : Icons.push_pin_outlined,
                                        color: pinned
                                            ? item.accent
                                            : widget.subtext,
                                        size: 17,
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: widget.text,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    item.category,
                                    style: TextStyle(
                                      color: widget.subtext,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _pins
        .map(_byId)
        .whereType<NazaFeatureDestination>()
        .toList();
    final settings = _byId('settings');
    final history = _byId('history');
    return Container(
      key: const ValueKey('unified-feature-rail'),
      width: 92,
      decoration: BoxDecoration(
        color: widget.surface,
        border: Border(right: BorderSide(color: widget.border)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
              itemCount: pinned.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (_, index) {
                final item = pinned[index],
                    selected = item.id == widget.selectedId;
                return Tooltip(
                  message: item.label,
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: item.label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _open(item),
                      onLongPress: item.id == NazaFeaturePinPolicy.requiredId
                          ? null
                          : () => _toggle(item.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 64,
                        decoration: BoxDecoration(
                          color: selected
                              ? item.accent.withValues(alpha: .18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? item.accent : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              color: selected ? item.accent : widget.subtext,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.id == NazaFeaturePinPolicy.requiredId
                                  ? 'Chat'
                                  : item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected ? widget.text : widget.subtext,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (history != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 2, 9, 2),
              child: Tooltip(
                message: 'History',
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _open(history),
                  child: SizedBox(
                    height: 42,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            color: widget.subtext,
                            size: 19,
                          ),
                          Text(
                            'History',
                            style: TextStyle(
                              color: widget.subtext,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (settings != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 2, 9, 4),
              child: Tooltip(
                message: 'Settings',
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _open(settings),
                  child: SizedBox(
                    height: 48,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.settings_rounded,
                            color: widget.subtext,
                            size: 20,
                          ),
                          Text(
                            'Settings',
                            style: TextStyle(
                              color: widget.subtext,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(9),
            child: IconButton.filled(
              tooltip: 'View and configure all features',
              onPressed: _showAll,
              icon: const Icon(Icons.blur_circular_rounded),
              style: IconButton.styleFrom(
                backgroundColor: widget.panel,
                foregroundColor: widget.text,
                side: BorderSide(color: widget.border),
                minimumSize: const Size(58, 52),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _PinnedDockButton extends StatelessWidget {
  final NazaFeatureDestination destination;
  final bool selected;
  final Color text;
  final Color subtext;
  final Color border;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PinnedDockButton({
    required this.destination,
    required this.selected,
    required this.text,
    required this.subtext,
    required this.border,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: destination.label,
    hint: onLongPress == null ? null : 'Long press to unpin',
    child: Material(
      color: selected
          ? destination.accent.withValues(alpha: 0.18)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minWidth: 58, maxWidth: 88),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: selected ? destination.accent : border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                destination.icon,
                color: selected ? destination.accent : subtext,
                size: 21,
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? text : subtext,
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final class _FeatureWheelSheet extends StatefulWidget {
  final List<NazaFeatureDestination> destinations;
  final List<String> pins;
  final String selectedId;
  final Color surface;
  final Color panel;
  final Color border;
  final Color text;
  final Color subtext;
  final ValueChanged<NazaFeatureDestination> onOpen;
  final Future<void> Function(String id) onTogglePin;

  const _FeatureWheelSheet({
    required this.destinations,
    required this.pins,
    required this.selectedId,
    required this.surface,
    required this.panel,
    required this.border,
    required this.text,
    required this.subtext,
    required this.onOpen,
    required this.onTogglePin,
  });

  @override
  State<_FeatureWheelSheet> createState() => _FeatureWheelSheetState();
}

class _FeatureWheelSheetState extends State<_FeatureWheelSheet> {
  late final PageController _controller;
  double _page = 0;
  String _category = 'All';
  String _query = '';

  List<NazaFeatureDestination> get _visible => widget.destinations.where((e) {
    final categoryMatch = _category == 'All' || e.category == _category;
    final query = _query.trim().toLowerCase();
    final queryMatch = query.isEmpty ||
        e.label.toLowerCase().contains(query) ||
        e.category.toLowerCase().contains(query) ||
        e.description.toLowerCase().contains(query);
    return categoryMatch && queryMatch;
  }).toList(growable: false);

  @override
  void initState() {
    super.initState();
    final selected = widget.destinations.indexWhere(
      (e) => e.id == widget.selectedId,
    );
    final initial = selected < 0 ? 0 : selected;
    _page = initial.toDouble();
    _controller = PageController(initialPage: initial, viewportFraction: 0.38)
      ..addListener(_trackPage);
  }

  void _trackPage() {
    final page = _controller.page;
    if (page != null && mounted) setState(() => _page = page);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_trackPage)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>{
      'All',
      ...widget.destinations.map((e) => e.category),
    }.toList();
    final visible = _visible;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: widget.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: widget.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Your feature wheel',
                        style: TextStyle(
                          color: widget.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Drag to explore · hold a card to pin',
                        style: TextStyle(color: widget.subtext, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: TextField(
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
                if (_controller.hasClients) _controller.jumpToPage(0);
              }),
              style: TextStyle(color: widget.text),
              decoration: InputDecoration(
                hintText: 'Search all ${widget.destinations.length} features',
                hintStyle: TextStyle(color: widget.subtext),
                prefixIcon: Icon(Icons.search_rounded, color: widget.subtext),
                filled: true,
                fillColor: widget.panel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: widget.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: widget.border),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (_, index) {
                final category = categories[index];
                return ChoiceChip(
                  label: Text(category),
                  selected: category == _category,
                  onSelected: (_) => setState(() {
                    _category = category;
                    _query = '';
                    _page = 0;
                    if (_controller.hasClients) _controller.jumpToPage(0);
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 210,
            child: PageView.builder(
              key: ValueKey<String>(_category),
              controller: _controller,
              padEnds: true,
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final distance = (index - _page).abs().clamp(0.0, 1.0);
                final scale = 1 - distance * 0.18;
                final lift = math.sin((1 - distance) * math.pi / 2) * 14;
                final item = visible[index];
                final pinned = widget.pins.contains(item.id);
                return Transform.translate(
                  offset: Offset(0, -lift),
                  child: Transform.scale(
                    scale: scale,
                    child: Semantics(
                      button: true,
                      selected: item.id == widget.selectedId,
                      label: item.label,
                      hint: pinned
                          ? 'Long press to unpin'
                          : 'Long press to pin',
                      child: Card(
                        color: Color.alphaBlend(
                          item.accent.withValues(alpha: 0.13),
                          widget.panel,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                          side: BorderSide(
                            color: pinned ? item.accent : widget.border,
                            width: pinned ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => widget.onOpen(item),
                          onLongPress: () => widget.onTogglePin(item.id),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: item.accent.withValues(
                                    alpha: 0.18,
                                  ),
                                  child: Icon(
                                    item.icon,
                                    color: item.accent,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: widget.text,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Icon(
                                  pinned
                                      ? Icons.push_pin_rounded
                                      : Icons.push_pin_outlined,
                                  size: 15,
                                  color: pinned ? item.accent : widget.subtext,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (visible.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
              child: Text(
                visible[_page.round().clamp(0, visible.length - 1)].description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: widget.subtext, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}
