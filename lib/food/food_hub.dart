import 'dart:async';

import 'package:flutter/material.dart';

import 'food_hub_legacy.dart' as legacy;
import 'models.dart';
import 'photo_picker.dart';
import 'repository.dart';
import 'shelf_scanner.dart';

export 'food_hub_legacy.dart' hide FoodVisionHub;

/// Cleaner public food-scanner workspace.
///
/// Mature recipe/bake/safety surfaces are preserved in [legacy.FoodVisionHub]
/// under More while Fridge and Shelf get dedicated responsive scanner flows.
class FoodVisionHub extends StatefulWidget {
  final FoodRepository repository;
  final FoodPhotoPicker photoPicker;
  final legacy.FridgeImageAnalyzer analyzeFridgeImage;
  final legacy.BakeImageAnalyzer analyzeBakeImage;
  final legacy.FoodRecipeRegenerator regenerateRecipes;
  final VoidCallback onCancel;
  final Widget? foodSafetyChild;
  final legacy.FoodVisionDraftController? draftController;

  const FoodVisionHub({
    super.key,
    required this.repository,
    required this.photoPicker,
    required this.analyzeFridgeImage,
    required this.analyzeBakeImage,
    required this.regenerateRecipes,
    required this.onCancel,
    this.foodSafetyChild,
    this.draftController,
  });

  @override
  State<FoodVisionHub> createState() => _FoodVisionHubState();
}

enum _WorkspaceTab { fridge, shelf, more }

enum _PhotoChoice { camera, gallery, files }

class _FoodVisionHubState extends State<FoodVisionHub> {
  final ShelfRepository _shelfRepository = EncryptedShelfRepository();
  _WorkspaceTab _tab = _WorkspaceTab.fridge;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final body = IndexedStack(
          index: _tab.index,
          children: <Widget>[
            _CleanFridgePane(
              repository: widget.repository,
              photoPicker: widget.photoPicker,
              analyzer: widget.analyzeFridgeImage,
              onCancel: widget.onCancel,
            ),
            ShelfScannerPane(
              repository: _shelfRepository,
              photoPicker: widget.photoPicker,
              analyzeVision: widget.analyzeFridgeImage,
              onCancel: widget.onCancel,
            ),
            legacy.FoodVisionHub(
              repository: widget.repository,
              photoPicker: widget.photoPicker,
              analyzeFridgeImage: widget.analyzeFridgeImage,
              analyzeBakeImage: widget.analyzeBakeImage,
              regenerateRecipes: widget.regenerateRecipes,
              onCancel: widget.onCancel,
              foodSafetyChild: widget.foodSafetyChild,
              draftController: widget.draftController,
            ),
          ],
        );

        return Scaffold(
          body: wide
              ? Row(
                  children: <Widget>[
                    NavigationRail(
                      selectedIndex: _tab.index,
                      onDestinationSelected: (index) =>
                          setState(() => _tab = _WorkspaceTab.values[index]),
                      labelType: NavigationRailLabelType.all,
                      destinations: const <NavigationRailDestination>[
                        NavigationRailDestination(
                          icon: Icon(Icons.kitchen_outlined),
                          selectedIcon: Icon(Icons.kitchen_rounded),
                          label: Text('Fridge'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.shelves),
                          selectedIcon: Icon(Icons.inventory_2_rounded),
                          label: Text('Shelf'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_customize_outlined),
                          selectedIcon: Icon(Icons.dashboard_customize_rounded),
                          label: Text('More'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _tab.index,
                  onDestinationSelected: (index) =>
                      setState(() => _tab = _WorkspaceTab.values[index]),
                  destinations: const <NavigationDestination>[
                    NavigationDestination(
                      icon: Icon(Icons.kitchen_outlined),
                      selectedIcon: Icon(Icons.kitchen_rounded),
                      label: 'Fridge',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.shelves),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: 'Shelf',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_customize_outlined),
                      selectedIcon: Icon(Icons.dashboard_customize_rounded),
                      label: 'More',
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _CleanFridgePane extends StatefulWidget {
  final FoodRepository repository;
  final FoodPhotoPicker photoPicker;
  final legacy.FridgeImageAnalyzer analyzer;
  final VoidCallback onCancel;

  const _CleanFridgePane({
    required this.repository,
    required this.photoPicker,
    required this.analyzer,
    required this.onCancel,
  });

  @override
  State<_CleanFridgePane> createState() => _CleanFridgePaneState();
}

class _CleanFridgePaneState extends State<_CleanFridgePane> {
  final TextEditingController _note = TextEditingController();
  FoodVisionImage? _image;
  FridgeLog? _latest;
  bool _started = false;
  bool _busy = false;
  String _status = 'Ready for a private fridge scan';

  @override
  void initState() {
    super.initState();
    unawaited(_loadLatest());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadLatest() async {
    try {
      final logs = await widget.repository.listFridgeLogs(limit: 1);
      if (!mounted || logs.isEmpty) return;
      setState(() => _latest = logs.first);
    } catch (_) {
      // A locked/unavailable vault is surfaced when an explicit action runs.
    }
  }

  Future<void> _pickPhoto() async {
    if (_busy) return;
    final choice = await _choosePhotoSource(context);
    if (choice == null || !mounted) return;
    setState(() {
      _busy = true;
      _status = 'Preparing photo securely';
    });
    final result = switch (choice) {
      _PhotoChoice.camera => await widget.photoPicker.captureCamera(),
      _PhotoChoice.gallery => await widget.photoPicker.pickGallery(),
      _PhotoChoice.files => await widget.photoPicker.pickFiles(),
    };
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.selected) {
        _image = result.image;
        _status = 'Picture ready • source metadata discarded';
      } else {
        _status = result.message ?? 'Picture selection cancelled';
      }
    });
  }

  Future<void> _analyze() async {
    final image = _image;
    if (_busy || image == null) return;
    setState(() {
      _busy = true;
      _status = 'Analyzing visible fridge inventory locally';
    });
    try {
      final analysis = await widget.analyzer(image, _note.text.trim());
      final log = FridgeLog(
        id: newFoodId('fridge'),
        capturedAt: DateTime.now().toUtc(),
        image: image,
        note: _note.text.trim(),
        analysis: analysis,
      );
      await widget.repository.saveFridgeLog(log);
      if (!mounted) return;
      setState(() {
        _latest = log;
        _busy = false;
        _status = analysis.status == FoodAnalysisStatus.complete
            ? 'Encrypted fridge scan saved'
            : 'Encrypted scan saved • review uncertainty';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Fridge scan failed: $error';
      });
    }
  }

  void _stop() {
    try {
      widget.onCancel();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = 'Scan stopped';
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final controls = _FridgeControls(
      image: _image,
      note: _note,
      busy: _busy,
      onPicture: _pickPhoto,
      onClear: _busy
          ? null
          : () => setState(() {
                _image = null;
                _status = 'Picture cleared';
              }),
      onAnalyze: _busy || _image == null ? null : _analyze,
    );
    final results = _FridgeResults(log: _latest);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(wide ? 20 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ScannerHeader(
              title: 'Fridge Scanner',
              subtitle: _status,
              started: _started,
              busy: _busy,
              onStart: () => setState(() => _started = true),
              onStop: _stop,
              onPicture: _started && !_busy ? _pickPhoto : null,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: !_started
                  ? _StartFridgeCard(
                      onStart: () => setState(() => _started = true),
                    )
                  : wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(child: controls),
                            const SizedBox(width: 12),
                            Expanded(child: results),
                          ],
                        )
                      : ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          children: <Widget>[
                            controls,
                            const SizedBox(height: 12),
                            results,
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool started;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback? onPicture;

  const _ScannerHeader({
    required this.title,
    required this.subtitle,
    required this.started,
    required this.busy,
    required this.onStart,
    required this.onStop,
    required this.onPicture,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.kitchen_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (started && onPicture != null)
                IconButton.filledTonal(
                  onPressed: onPicture,
                  tooltip: 'Photo Scanner',
                  icon: const Icon(Icons.add_a_photo_rounded),
                ),
              const SizedBox(width: 6),
              if (!started)
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start'),
                )
              else if (busy)
                FilledButton.tonalIcon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop'),
                ),
            ],
          ),
        ),
      );
}

class _StartFridgeCard extends StatelessWidget {
  final VoidCallback onStart;
  const _StartFridgeCard({required this.onStart});

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.kitchen_outlined, size: 52),
                  const SizedBox(height: 14),
                  Text(
                    'A cleaner private fridge scan',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start, take or choose one picture, add an optional note, then review the encrypted structured inventory beside the image.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start fridge scanner'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _FridgeControls extends StatelessWidget {
  final FoodVisionImage? image;
  final TextEditingController note;
  final bool busy;
  final VoidCallback onPicture;
  final VoidCallback? onClear;
  final VoidCallback? onAnalyze;

  const _FridgeControls({
    required this.image,
    required this.note,
    required this.busy,
    required this.onPicture,
    required this.onClear,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.photo_camera_back_outlined),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Photo Scanner',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onPicture,
                    icon: const Icon(Icons.add_a_photo_rounded),
                    label: Text(image == null ? 'Picture' : 'Replace'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (image == null)
                Container(
                  height: 190,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: const Text('No fridge picture selected'),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.memory(
                      image!.bytes,
                      fit: BoxFit.cover,
                      cacheWidth: 1280,
                    ),
                  ),
                ),
              if (image != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Clear'),
                  ),
                ),
              const SizedBox(height: 4),
              TextField(
                controller: note,
                enabled: !busy,
                maxLines: 2,
                maxLength: 1200,
                decoration: const InputDecoration(
                  labelText: 'Optional note',
                  hintText: 'Grocery day, leftovers on top shelf…',
                ),
              ),
              FilledButton.icon(
                onPressed: onAnalyze,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(busy ? 'Analyzing locally…' : 'Analyze & save encrypted'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      );
}

class _FridgeResults extends StatelessWidget {
  final FridgeLog? log;
  const _FridgeResults({required this.log});

  @override
  Widget build(BuildContext context) {
    final current = log;
    if (current == null) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Your latest encrypted structured fridge result will appear here.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final analysis = current.analysis;
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.lock_outline_rounded),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Encrypted inventory',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Chip(label: Text(analysis.status.name)),
            ],
          ),
          const SizedBox(height: 10),
          Text(analysis.summary),
          const SizedBox(height: 14),
          for (final item in analysis.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.inventory_2_outlined),
              ),
              title: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${item.approximateQuantity} • ${item.location}\n${item.useWindow}',
              ),
              trailing: Chip(label: Text(item.confidence.label)),
            ),
          if (analysis.uncertainties.isNotEmpty) ...<Widget>[
            const Divider(height: 26),
            const Text(
              'Verify directly',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            for (final uncertainty in analysis.uncertainties)
              Text('• $uncertainty'),
          ],
        ],
      ),
    );
  }
}

Future<_PhotoChoice?> _choosePhotoSource(BuildContext context) =>
    showModalBottomSheet<_PhotoChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Photo Scanner',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Images are normalized locally before scanner storage; original EXIF/GPS metadata is not retained.',
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Camera'),
                subtitle: const Text('Take a new picture'),
                onTap: () => Navigator.pop(context, _PhotoChoice.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photo library'),
                subtitle: const Text('Use the system photo picker'),
                onTap: () => Navigator.pop(context, _PhotoChoice.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_rounded),
                title: const Text('Files'),
                subtitle: const Text('Choose JPG, PNG, or WebP from files'),
                onTap: () => Navigator.pop(context, _PhotoChoice.files),
              ),
            ],
          ),
        ),
      ),
    );
