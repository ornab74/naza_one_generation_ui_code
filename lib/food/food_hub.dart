import 'dart:async';

import 'package:flutter/material.dart';

import 'bake_simulation.dart';
import 'models.dart';
import 'photo_picker.dart';
import 'repository.dart';

typedef FridgeImageAnalyzer =
    Future<FridgeAnalysis> Function(FoodVisionImage image, String note);
typedef BakeImageAnalyzer =
    Future<BakeVisualAssessment> Function(
      FoodVisionImage image,
      BakeInput input,
    );
typedef FoodRecipeRegenerator =
    Future<List<RecipeSuggestion>> Function(FridgeAnalysis analysis);

/// Owns unfinished food-form text independently from the selected app panel.
///
/// The top-level app can retain one of these while [FoodVisionHub] is offstage
/// or rebuilt, so a navigation tap never discards a fridge note or bake setup.
class FoodVisionDraftController {
  final TextEditingController fridgeNote = TextEditingController();
  final TextEditingController bakeName = TextEditingController(text: 'Pizza');
  final TextEditingController elapsedMinutes = TextEditingController();
  final TextEditingController plannedMinutes = TextEditingController();
  final TextEditingController ovenTemperature = TextEditingController();
  final TextEditingController probeTemperature = TextEditingController();
  final TextEditingController targetTemperature = TextEditingController();
  final TextEditingController bakeNotes = TextEditingController();

  void dispose() {
    fridgeNote.dispose();
    bakeName.dispose();
    elapsedMinutes.dispose();
    plannedMinutes.dispose();
    ovenTemperature.dispose();
    probeTemperature.dispose();
    targetTemperature.dispose();
    bakeNotes.dispose();
  }
}

/// A self-contained food-vision workspace with no chat or continuation state.
///
/// Vision and recipe generation are injected so the UI stays independent from
/// any particular local-model runtime. Completed analyses are persisted through
/// [repository] as authenticated food records.
class FoodVisionHub extends StatefulWidget {
  final FoodRepository repository;
  final FoodPhotoPicker photoPicker;
  final FridgeImageAnalyzer analyzeFridgeImage;
  final BakeImageAnalyzer analyzeBakeImage;
  final FoodRecipeRegenerator regenerateRecipes;
  final VoidCallback onCancel;
  final Widget? foodSafetyChild;
  final FoodVisionDraftController? draftController;

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

enum _FoodHubTab { fridge, recipes, bake, safety }

enum _HubTask {
  loadingHistory,
  fridgePhoto,
  fridgeAnalysis,
  recipeGeneration,
  bakePhoto,
  bakeAnalysis,
}

extension on _HubTask {
  bool get canCancel => switch (this) {
    _HubTask.fridgeAnalysis ||
    _HubTask.recipeGeneration ||
    _HubTask.bakeAnalysis => true,
    _ => false,
  };
}

class _FoodVisionHubState extends State<FoodVisionHub> {
  late final FoodVisionDraftController _draft;
  late final bool _ownsDraft;

  TextEditingController get _fridgeNote => _draft.fridgeNote;
  TextEditingController get _bakeName => _draft.bakeName;
  TextEditingController get _elapsedMinutes => _draft.elapsedMinutes;
  TextEditingController get _plannedMinutes => _draft.plannedMinutes;
  TextEditingController get _ovenTemperature => _draft.ovenTemperature;
  TextEditingController get _probeTemperature => _draft.probeTemperature;
  TextEditingController get _targetTemperature => _draft.targetTemperature;
  TextEditingController get _bakeNotes => _draft.bakeNotes;

  _FoodHubTab _tab = _FoodHubTab.fridge;
  _HubTask? _task;
  FoodVisionImage? _fridgeImage;
  FoodVisionImage? _bakeImage;
  BakeItemKind _bakeKind = BakeItemKind.pizza;
  List<FridgeLog> _fridgeLogs = const [];
  List<BakeLog> _bakeLogs = const [];
  String _status = 'Private kitchen ready';
  String? _notice;
  bool _noticeIsError = false;
  int _operationSerial = 0;

  @override
  void initState() {
    super.initState();
    _ownsDraft = widget.draftController == null;
    _draft = widget.draftController ?? FoodVisionDraftController();
    widget.repository.revision.addListener(_handleRepositoryRevision);
    unawaited(_loadLogs());
  }

  @override
  void didUpdateWidget(covariant FoodVisionHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      oldWidget.repository.revision.removeListener(_handleRepositoryRevision);
      widget.repository.revision.addListener(_handleRepositoryRevision);
      unawaited(_loadLogs());
    }
  }

  @override
  void dispose() {
    _operationSerial++;
    widget.repository.revision.removeListener(_handleRepositoryRevision);
    if (_ownsDraft) _draft.dispose();
    super.dispose();
  }

  bool get _busy => _task != null;

  FridgeLog? get _latestFridgeLog =>
      _fridgeLogs.isEmpty ? null : _fridgeLogs.first;

  BakeLog? get _latestBakeLog => _bakeLogs.isEmpty ? null : _bakeLogs.first;

  void _handleRepositoryRevision() {
    if (_busy) return;
    unawaited(_loadLogs());
  }

  Future<void> _loadLogs() async {
    final token = _beginTask(
      _HubTask.loadingHistory,
      'Opening encrypted food journal',
      clearNotice: false,
    );
    try {
      final results = await Future.wait<Object>([
        widget.repository.listFridgeLogs(),
        widget.repository.listBakeLogs(),
      ]);
      if (!_isCurrent(token)) return;
      final fridge = List<FridgeLog>.from(results[0] as List<FridgeLog>)
        ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      final bake = List<BakeLog>.from(results[1] as List<BakeLog>)
        ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      setState(() {
        _fridgeLogs = List<FridgeLog>.unmodifiable(fridge);
        _bakeLogs = List<BakeLog>.unmodifiable(bake);
        _task = null;
        _status = 'Private kitchen ready';
      });
    } catch (error) {
      _finishWithError(
        token,
        'Encrypted food history could not be opened: $error',
      );
    }
  }

  int _beginTask(_HubTask task, String status, {bool clearNotice = true}) {
    final token = ++_operationSerial;
    if (mounted) {
      setState(() {
        _task = task;
        _status = status;
        if (clearNotice) _notice = null;
      });
    }
    return token;
  }

  bool _isCurrent(int token) => mounted && token == _operationSerial;

  void _finishTask(int token, String status, {String? notice}) {
    if (!_isCurrent(token)) return;
    setState(() {
      _task = null;
      _status = status;
      _notice = notice;
      _noticeIsError = false;
    });
  }

  void _finishWithError(int token, Object error) {
    if (!_isCurrent(token)) return;
    setState(() {
      _task = null;
      _status = 'Needs attention';
      _notice = error.toString();
      _noticeIsError = true;
    });
  }

  void _cancelActiveTask() {
    final task = _task;
    if (task == null || !task.canCancel) return;
    _operationSerial++;
    try {
      widget.onCancel();
    } catch (_) {
      // Cancellation remains best-effort; stale operation results are ignored.
    }
    setState(() {
      _task = null;
      _status = 'Analysis stopped';
      _notice =
          'The active local-model task was stopped. Your selected photo and form values were kept.';
      _noticeIsError = false;
    });
  }

  Future<void> _pickFridgePhoto(FoodPhotoSource source) async {
    if (_busy) return;
    final token = _beginTask(
      _HubTask.fridgePhoto,
      'Opening ${_sourceLabel(source)}',
    );
    try {
      final result = await widget.photoPicker.pick(source);
      if (!_isCurrent(token)) return;
      switch (result.outcome) {
        case FoodPhotoPickOutcome.selected:
          final image = result.image;
          if (image == null) {
            _finishWithError(token, 'The photo picker returned no image.');
            return;
          }
          setState(() {
            _fridgeImage = image;
            _task = null;
            _status = 'Fridge photo ready';
            _notice =
                'Review the photo, add an optional note, then analyze and save it to the encrypted journal.';
            _noticeIsError = false;
          });
          break;
        case FoodPhotoPickOutcome.cancelled:
          _finishTask(token, 'Photo selection cancelled');
          break;
        case FoodPhotoPickOutcome.unavailable:
        case FoodPhotoPickOutcome.failed:
          _finishWithError(
            token,
            result.message ?? 'The selected photo could not be prepared.',
          );
          break;
      }
    } catch (error) {
      _finishWithError(token, 'Photo selection failed: $error');
    }
  }

  Future<void> _pickBakePhoto(FoodPhotoSource source) async {
    if (_busy) return;
    final token = _beginTask(
      _HubTask.bakePhoto,
      'Opening ${_sourceLabel(source)}',
    );
    try {
      final result = await widget.photoPicker.pick(source);
      if (!_isCurrent(token)) return;
      switch (result.outcome) {
        case FoodPhotoPickOutcome.selected:
          final image = result.image;
          if (image == null) {
            _finishWithError(token, 'The photo picker returned no image.');
            return;
          }
          setState(() {
            _bakeImage = image;
            _task = null;
            _status = 'Bake photo ready';
            _notice =
                'Add timing and temperature evidence before running the completion simulation.';
            _noticeIsError = false;
          });
          break;
        case FoodPhotoPickOutcome.cancelled:
          _finishTask(token, 'Photo selection cancelled');
          break;
        case FoodPhotoPickOutcome.unavailable:
        case FoodPhotoPickOutcome.failed:
          _finishWithError(
            token,
            result.message ?? 'The selected photo could not be prepared.',
          );
          break;
      }
    } catch (error) {
      _finishWithError(token, 'Photo selection failed: $error');
    }
  }

  Future<void> _analyzeFridge() async {
    final image = _fridgeImage;
    if (_busy || image == null) {
      _showError('Take or choose a fridge photo first.');
      return;
    }
    final note = _fridgeNote.text.trim();
    final token = _beginTask(
      _HubTask.fridgeAnalysis,
      'Analyzing fridge locally',
    );
    try {
      final analysis = await widget.analyzeFridgeImage(image, note);
      if (!_isCurrent(token)) return;
      final log = FridgeLog(
        id: newFoodId('fridge'),
        capturedAt: DateTime.now().toUtc(),
        image: image,
        note: note,
        analysis: analysis,
      );
      await widget.repository.saveFridgeLog(log);
      if (!_isCurrent(token)) return;
      setState(() {
        _fridgeLogs = List<FridgeLog>.unmodifiable(<FridgeLog>[
          log,
          ..._fridgeLogs.where((entry) => entry.id != log.id),
        ]);
        _task = null;
        _status = 'Fridge log saved';
        _notice = analysis.status == FoodAnalysisStatus.complete
            ? 'The photo and structured inventory were saved in the encrypted SQLite journal.'
            : 'The photo was saved. Review the uncertainty notes before relying on the partial analysis.';
        _noticeIsError = analysis.status == FoodAnalysisStatus.failed;
      });
    } catch (error) {
      _finishWithError(
        token,
        'Fridge analysis or encrypted save did not complete: $error',
      );
    }
  }

  Future<void> _regenerateRecipes() async {
    final sourceLog = _latestFridgeLog;
    if (_busy || sourceLog == null) {
      _showError('Save a fridge analysis before generating recipes.');
      return;
    }
    final token = _beginTask(
      _HubTask.recipeGeneration,
      'Building recipes from the latest log',
    );
    try {
      final recipes = await widget.regenerateRecipes(sourceLog.analysis);
      if (!_isCurrent(token)) return;
      final updatedAnalysis = _analysisWithRecipes(sourceLog.analysis, recipes);
      final updatedLog = sourceLog.copyWith(analysis: updatedAnalysis);
      await widget.repository.saveFridgeLog(updatedLog);
      if (!_isCurrent(token)) return;
      setState(() {
        _fridgeLogs = List<FridgeLog>.unmodifiable(
          _fridgeLogs
              .map((entry) => entry.id == updatedLog.id ? updatedLog : entry)
              .toList(growable: false),
        );
        _task = null;
        _status = 'Recipe ideas refreshed';
        _notice = recipes.isEmpty
            ? 'No recipe passed structured validation. Confirm the visible inventory and try again.'
            : '${recipes.length} recipe ${recipes.length == 1 ? 'idea was' : 'ideas were'} saved with the latest fridge log.';
        _noticeIsError = false;
      });
    } catch (error) {
      _finishWithError(token, 'Recipe generation did not complete: $error');
    }
  }

  Future<void> _analyzeBake() async {
    final image = _bakeImage;
    if (_busy || image == null) {
      _showError('Take or choose a bake photo first.');
      return;
    }
    final input = _buildBakeInput();
    if (input == null) return;

    final token = _beginTask(
      _HubTask.bakeAnalysis,
      'Inspecting visible bake cues',
    );
    try {
      final visual = await widget.analyzeBakeImage(image, input);
      if (!_isCurrent(token)) return;
      final simulation = BakeSimulationEngine.estimate(
        input: input,
        visual: visual,
      );
      final log = BakeLog(
        id: newFoodId('bake'),
        capturedAt: DateTime.now().toUtc(),
        image: image,
        input: input,
        visual: visual,
        simulation: simulation,
      );
      await widget.repository.saveBakeLog(log);
      if (!_isCurrent(token)) return;
      setState(() {
        _bakeLogs = List<BakeLog>.unmodifiable(<BakeLog>[
          log,
          ..._bakeLogs.where((entry) => entry.id != log.id),
        ]);
        _task = null;
        _status = 'Bake estimate saved';
        _notice =
            'The visual assessment and deterministic simulation were saved. Completion percentage is not a food-safety verdict.';
        _noticeIsError = false;
      });
    } catch (error) {
      _finishWithError(token, 'Bake analysis or encrypted save failed: $error');
    }
  }

  BakeInput? _buildBakeInput() {
    final elapsed = _requiredNumber(_elapsedMinutes, 'Elapsed minutes');
    final planned = _requiredNumber(_plannedMinutes, 'Planned minutes');
    if (elapsed == null || planned == null) return null;
    if (planned <= 0) {
      _showError('Planned minutes must be greater than zero.');
      return null;
    }

    final oven = _optionalNumber(_ovenTemperature, 'Oven temperature');
    final probe = _optionalNumber(_probeTemperature, 'Probe temperature');
    final target = _optionalNumber(_targetTemperature, 'Target temperature');
    if (_hasInvalidOptionalNumber) {
      _hasInvalidOptionalNumber = false;
      return null;
    }
    if ((probe == null) != (target == null)) {
      _showError(
        'Enter both probe and target temperatures, or leave both blank.',
      );
      return null;
    }

    return BakeInput(
      kind: _bakeKind,
      itemName: _bakeName.text.trim().isEmpty
          ? _kindLabel(_bakeKind)
          : _bakeName.text.trim(),
      elapsedMinutes: elapsed,
      plannedMinutes: planned,
      ovenTemperatureF: oven,
      startingTemperatureF: null,
      probeTemperatureF: probe,
      targetTemperatureF: target,
      notes: _bakeNotes.text.trim(),
    );
  }

  bool _hasInvalidOptionalNumber = false;

  double? _requiredNumber(TextEditingController controller, String label) {
    final value = double.tryParse(controller.text.trim());
    if (value == null || !value.isFinite || value < 0) {
      _showError('$label must be a non-negative number.');
      return null;
    }
    return value;
  }

  double? _optionalNumber(TextEditingController controller, String label) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || !value.isFinite || value < 0) {
      _hasInvalidOptionalNumber = true;
      _showError('$label must be a non-negative number or left blank.');
      return null;
    }
    return value;
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _notice = message;
      _noticeIsError = true;
      _status = 'Needs attention';
    });
  }

  FridgeAnalysis _analysisWithRecipes(
    FridgeAnalysis source,
    List<RecipeSuggestion> recipes,
  ) {
    return FridgeAnalysis(
      status: source.status,
      summary: source.summary,
      items: source.items,
      useSoon: source.useSoon,
      ingredientSuggestions: source.ingredientSuggestions,
      recipes: List<RecipeSuggestion>.unmodifiable(recipes),
      uncertainties: source.uncertainties,
      rawModelText: source.rawModelText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inherited = Theme.of(context);
    final scheme = ColorScheme.fromSeed(
      seedColor: _FoodColors.mint,
      brightness: Brightness.dark,
      surface: _FoodColors.surface,
    );
    final theme = inherited.copyWith(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: _FoodColors.background,
      cardColor: _FoodColors.surface,
      dividerColor: _FoodColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _FoodColors.field,
        labelStyle: const TextStyle(color: _FoodColors.subtext),
        hintStyle: const TextStyle(color: _FoodColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _FoodColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _FoodColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _FoodColors.mint, width: 1.6),
        ),
      ),
    );

    return Theme(
      data: theme,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Scaffold(
            appBar: AppBar(
              backgroundColor: _FoodColors.appBar,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              titleSpacing: wide ? 24 : 16,
              title: Row(
                children: [
                  const _HubMark(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Naza Kitchen',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          _status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _FoodColors.subtext,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (_task?.canCancel == true)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: FilledButton.tonalIcon(
                      onPressed: _cancelActiveTask,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Stop'),
                      style: FilledButton.styleFrom(
                        foregroundColor: _FoodColors.warning,
                      ),
                    ),
                  ),
              ],
            ),
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _FoodColors.background,
                    Color(0xFF071A13),
                    _FoodColors.background,
                  ],
                ),
              ),
              child: wide
                  ? Row(
                      children: [
                        _HubRail(tab: _tab, onSelected: _selectTab),
                        const VerticalDivider(width: 1),
                        Expanded(child: _buildTabBody()),
                      ],
                    )
                  : _buildTabBody(),
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: _tab.index,
                    onDestinationSelected: (index) =>
                        _selectTab(_FoodHubTab.values[index]),
                    backgroundColor: _FoodColors.appBar,
                    indicatorColor: _FoodColors.mint.withAlpha(42),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.kitchen_outlined),
                        selectedIcon: Icon(Icons.kitchen_rounded),
                        label: 'Fridge',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book_rounded),
                        label: 'Recipes',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.bakery_dining_outlined),
                        selectedIcon: Icon(Icons.bakery_dining_rounded),
                        label: 'Bake Lab',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.health_and_safety_outlined),
                        selectedIcon: Icon(Icons.health_and_safety_rounded),
                        label: 'Safety',
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  void _selectTab(_FoodHubTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
  }

  Widget _buildTabBody() {
    return Column(
      children: [
        if (_notice != null)
          _HubNotice(
            message: _notice!,
            error: _noticeIsError,
            onDismiss: () => setState(() => _notice = null),
          ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: IndexedStack(
            index: _tab.index,
            children: [
              _FridgeLogTab(
                image: _fridgeImage,
                noteController: _fridgeNote,
                latestLog: _latestFridgeLog,
                recentLogs: _fridgeLogs,
                busy: _busy,
                onCamera: () =>
                    unawaited(_pickFridgePhoto(FoodPhotoSource.camera)),
                onGallery: () =>
                    unawaited(_pickFridgePhoto(FoodPhotoSource.gallery)),
                onRemovePhoto: _busy
                    ? null
                    : () => setState(() => _fridgeImage = null),
                onAnalyze: _busy || _fridgeImage == null
                    ? null
                    : () => unawaited(_analyzeFridge()),
                onOpenRecipes: () => _selectTab(_FoodHubTab.recipes),
              ),
              _RecipesTab(
                sourceLog: _latestFridgeLog,
                busy: _busy,
                onRegenerate: _busy || _latestFridgeLog == null
                    ? null
                    : () => unawaited(_regenerateRecipes()),
                onOpenFridge: () => _selectTab(_FoodHubTab.fridge),
              ),
              _BakeLabTab(
                image: _bakeImage,
                latestLog: _latestBakeLog,
                recentLogs: _bakeLogs,
                busy: _busy,
                kind: _bakeKind,
                onKindChanged: _busy
                    ? null
                    : (kind) {
                        if (kind == null) return;
                        setState(() {
                          _bakeKind = kind;
                          if (_bakeName.text.trim().isEmpty) {
                            _bakeName.text = _kindLabel(kind);
                          }
                        });
                      },
                nameController: _bakeName,
                elapsedController: _elapsedMinutes,
                plannedController: _plannedMinutes,
                ovenController: _ovenTemperature,
                probeController: _probeTemperature,
                targetController: _targetTemperature,
                notesController: _bakeNotes,
                onCamera: () =>
                    unawaited(_pickBakePhoto(FoodPhotoSource.camera)),
                onGallery: () =>
                    unawaited(_pickBakePhoto(FoodPhotoSource.gallery)),
                onRemovePhoto: _busy
                    ? null
                    : () => setState(() => _bakeImage = null),
                onAnalyze: _busy || _bakeImage == null
                    ? null
                    : () => unawaited(_analyzeBake()),
              ),
              _SafetyTab(child: widget.foodSafetyChild),
            ],
          ),
        ),
      ],
    );
  }

  static String _sourceLabel(FoodPhotoSource source) => switch (source) {
    FoodPhotoSource.camera => 'camera',
    FoodPhotoSource.gallery => 'photo library',
  };
}

final class _FoodColors {
  const _FoodColors._();

  static const background = Color(0xFF020906);
  static const appBar = Color(0xFF06130E);
  static const surface = Color(0xFF0B1D16);
  static const field = Color(0xFF0A1812);
  static const mint = Color(0xFF74F5B3);
  static const mintSoft = Color(0xFFC5FFE2);
  static const text = Color(0xFFF1FFF7);
  static const subtext = Color(0xFFA7CDBA);
  static const muted = Color(0xFF6F8F80);
  static const border = Color(0x334DCA91);
  static const warning = Color(0xFFFFCF70);
  static const danger = Color(0xFFFF927B);
  static const sky = Color(0xFF7FD7FF);
}

class _HubMark extends StatelessWidget {
  const _HubMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _FoodColors.mint.withAlpha(26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _FoodColors.mint.withAlpha(110)),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.eco_rounded, color: _FoodColors.mintSoft),
    );
  }
}

class _HubRail extends StatelessWidget {
  final _FoodHubTab tab;
  final ValueChanged<_FoodHubTab> onSelected;

  const _HubRail({required this.tab, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: tab.index,
      onDestinationSelected: (index) => onSelected(_FoodHubTab.values[index]),
      backgroundColor: _FoodColors.appBar,
      indicatorColor: _FoodColors.mint.withAlpha(42),
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.kitchen_outlined),
          selectedIcon: Icon(Icons.kitchen_rounded),
          label: Text('Fridge'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book_rounded),
          label: Text('Recipes'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.bakery_dining_outlined),
          selectedIcon: Icon(Icons.bakery_dining_rounded),
          label: Text('Bake Lab'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.health_and_safety_outlined),
          selectedIcon: Icon(Icons.health_and_safety_rounded),
          label: Text('Safety'),
        ),
      ],
    );
  }
}

class _HubNotice extends StatelessWidget {
  final String message;
  final bool error;
  final VoidCallback onDismiss;

  const _HubNotice({
    required this.message,
    required this.error,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = error ? _FoodColors.danger : _FoodColors.mint;
    return Material(
      color: color.withAlpha(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _FoodColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageScroll extends StatelessWidget {
  final List<Widget> children;

  const _PageScroll({required this.children});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PageHeading extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;

  const _PageHeading({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _FoodColors.mint.withAlpha(26),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _FoodColors.border),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: _FoodColors.mintSoft, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: const TextStyle(
                    color: _FoodColors.mint,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _FoodColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: _FoodColors.subtext,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: _FoodColors.surface.withAlpha(238),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: accent?.withAlpha(100) ?? _FoodColors.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SectionHeading({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _FoodColors.mintSoft, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _FoodColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: _FoodColors.subtext,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class _PhotoSurface extends StatelessWidget {
  final FoodVisionImage? image;
  final bool enabled;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onRemove;
  final String emptyTitle;
  final String emptyBody;

  const _PhotoSurface({
    required this.image,
    required this.enabled,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
    required this.emptyTitle,
    required this.emptyBody,
  });

  @override
  Widget build(BuildContext context) {
    final current = image;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _FoodColors.field,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _FoodColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (current == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
              child: Column(
                children: [
                  const Icon(
                    Icons.add_a_photo_outlined,
                    color: _FoodColors.mintSoft,
                    size: 42,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    emptyTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _FoodColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    emptyBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _FoodColors.subtext,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            )
          else
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.memory(
                    current.bytes,
                    cacheWidth: 1200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: _FoodColors.danger,
                        size: 42,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: _FoodColors.background.withAlpha(220),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: onRemove,
                      tooltip: 'Remove photo',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _FoodColors.background.withAlpha(220),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${current.name} • ${current.dimensions}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _FoodColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: enabled ? onCamera : null,
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: Text(current == null ? 'Take photo' : 'Retake'),
                ),
                OutlinedButton.icon(
                  onPressed: enabled ? onGallery : null,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose from gallery'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FridgeLogTab extends StatelessWidget {
  final FoodVisionImage? image;
  final TextEditingController noteController;
  final FridgeLog? latestLog;
  final List<FridgeLog> recentLogs;
  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onRemovePhoto;
  final VoidCallback? onAnalyze;
  final VoidCallback onOpenRecipes;

  const _FridgeLogTab({
    required this.image,
    required this.noteController,
    required this.latestLog,
    required this.recentLogs,
    required this.busy,
    required this.onCamera,
    required this.onGallery,
    required this.onRemovePhoto,
    required this.onAnalyze,
    required this.onOpenRecipes,
  });

  @override
  Widget build(BuildContext context) {
    final analysis = latestLog?.analysis;
    return _PageScroll(
      children: [
        const _PageHeading(
          icon: Icons.kitchen_rounded,
          eyebrow: 'Daily food journal',
          title: 'Fridge Log',
          body:
              'Capture what is visible, review uncertainty, and save a private inventory snapshot in the encrypted vault.',
        ),
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionHeading(
                icon: Icons.camera_alt_outlined,
                title: 'Today’s fridge photo',
                subtitle:
                    'Use a bright, steady image. Labels and hidden items may remain unknown.',
              ),
              _PhotoSurface(
                image: image,
                enabled: !busy,
                onCamera: onCamera,
                onGallery: onGallery,
                onRemove: onRemovePhoto,
                emptyTitle: 'Photograph the open fridge',
                emptyBody:
                    'Keep the full shelves in frame. The model processes one normalized image locally.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                enabled: !busy,
                maxLength: 1200,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Optional note',
                  hintText:
                      'Grocery day, freezer not pictured, leftovers from Monday…',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: onAnalyze,
                icon: Icon(
                  busy
                      ? Icons.hourglass_top_rounded
                      : Icons.auto_awesome_rounded,
                ),
                label: Text(
                  busy
                      ? 'Local analysis in progress…'
                      : 'Analyze & save encrypted log',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
        if (analysis == null)
          const _EmptyAnalysisCard(
            icon: Icons.inventory_2_outlined,
            title: 'No structured fridge log yet',
            body:
                'Your most recent confirmed analysis will appear here with visible items, use-soon cues, ingredient ideas, and recipe starters.',
          )
        else ...[
          _FridgeSummaryCard(log: latestLog!),
          _InventoryItemsCard(items: analysis.items),
          _UseSoonCard(items: analysis.useSoon),
          _IngredientIdeasCard(items: analysis.ingredientSuggestions),
          _RecipePreviewCard(
            recipes: analysis.recipes,
            onOpenRecipes: onOpenRecipes,
          ),
        ],
        if (recentLogs.isNotEmpty) _RecentFridgeLogs(logs: recentLogs),
      ],
    );
  }
}

class _FridgeSummaryCard extends StatelessWidget {
  final FridgeLog log;

  const _FridgeSummaryCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final analysis = log.analysis;
    final complete = analysis.status == FoodAnalysisStatus.complete;
    return _Surface(
      accent: complete ? _FoodColors.mint : _FoodColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: complete
                ? Icons.check_circle_outline_rounded
                : Icons.rule_rounded,
            title: complete ? 'Latest structured inventory' : 'Review required',
            subtitle: _formatDateTime(log.capturedAt),
            trailing: _StatusChip(
              label: analysis.status.name,
              color: complete ? _FoodColors.mint : _FoodColors.warning,
            ),
          ),
          Text(
            analysis.summary,
            style: const TextStyle(
              color: _FoodColors.text,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (analysis.uncertainties.isNotEmpty) ...[
            const SizedBox(height: 12),
            _WarningBox(
              icon: Icons.visibility_off_outlined,
              title: 'Uncertainty to verify',
              lines: analysis.uncertainties,
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'A photo cannot prove freshness, expiration, allergen safety, or the condition of hidden food. Verify packaging, smell, temperature, and labels yourself.',
            style: TextStyle(
              color: _FoodColors.subtext,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryItemsCard extends StatelessWidget {
  final List<FridgeItemObservation> items;

  const _InventoryItemsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(
            icon: Icons.inventory_2_outlined,
            title: 'Visible items',
            subtitle:
                '${items.length} structured observation${items.length == 1 ? '' : 's'}',
          ),
          if (items.isEmpty)
            const _InlineEmpty('No item passed structured parsing.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 820
                    ? 3
                    : constraints.maxWidth >= 540
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: width,
                        child: _InventoryItemTile(item: item),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _InventoryItemTile extends StatelessWidget {
  final FridgeItemObservation item;

  const _InventoryItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final confidenceColor = switch (item.confidence) {
      FoodConfidence.high => _FoodColors.mint,
      FoodConfidence.medium => _FoodColors.warning,
      FoodConfidence.low => _FoodColors.danger,
    };
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _FoodColors.field,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: confidenceColor.withAlpha(75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    color: _FoodColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusChip(
                label: '${item.confidence.label} confidence',
                color: confidenceColor,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MiniFact(
            icon: Icons.numbers_rounded,
            text: item.approximateQuantity,
          ),
          _MiniFact(icon: Icons.place_outlined, text: item.location),
          _MiniFact(icon: Icons.schedule_rounded, text: item.useWindow),
          if (item.visibleCues.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.visibleCues.join(' • '),
              style: const TextStyle(
                color: _FoodColors.subtext,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniFact extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniFact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: _FoodColors.muted, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _FoodColors.subtext,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UseSoonCard extends StatelessWidget {
  final List<String> items;

  const _UseSoonCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return _Surface(
      accent: _FoodColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeading(
            icon: Icons.schedule_rounded,
            title: 'Use-soon review',
            subtitle: 'Model cues only—confirm labels and actual condition.',
          ),
          if (items.isEmpty)
            const _InlineEmpty('No use-soon cue was returned.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items)
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 17),
                    label: Text(item),
                    side: BorderSide(color: _FoodColors.warning.withAlpha(90)),
                    backgroundColor: _FoodColors.warning.withAlpha(18),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _IngredientIdeasCard extends StatelessWidget {
  final List<IngredientSuggestion> items;

  const _IngredientIdeasCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeading(
            icon: Icons.shopping_basket_outlined,
            title: 'Ingredient ideas',
            subtitle:
                'Optional additions that complement the visible inventory.',
          ),
          if (items.isEmpty)
            const _InlineEmpty('No ingredient suggestion was returned.')
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _priorityColor(item.priority).withAlpha(28),
                  child: Icon(
                    Icons.add_shopping_cart_rounded,
                    color: _priorityColor(item.priority),
                  ),
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(item.reason),
                trailing: _StatusChip(
                  label: item.priority,
                  color: _priorityColor(item.priority),
                  compact: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecipePreviewCard extends StatelessWidget {
  final List<RecipeSuggestion> recipes;
  final VoidCallback onOpenRecipes;

  const _RecipePreviewCard({
    required this.recipes,
    required this.onOpenRecipes,
  });

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(
            icon: Icons.restaurant_menu_rounded,
            title: 'Recipe starters',
            subtitle:
                '${recipes.length} idea${recipes.length == 1 ? '' : 's'} from this log',
            trailing: TextButton(
              onPressed: onOpenRecipes,
              child: const Text('Open planner'),
            ),
          ),
          if (recipes.isEmpty)
            const _InlineEmpty(
              'Open Recipes to generate ideas from this inventory.',
            )
          else
            ...recipes
                .take(3)
                .map(
                  (recipe) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x2674F5B3),
                      child: Icon(
                        Icons.restaurant_rounded,
                        color: _FoodColors.mint,
                      ),
                    ),
                    title: Text(
                      recipe.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${recipe.estimatedMinutes} min • uses ${recipe.usesVisibleItems.length} visible item${recipe.usesVisibleItems.length == 1 ? '' : 's'}',
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _RecentFridgeLogs extends StatelessWidget {
  final List<FridgeLog> logs;

  const _RecentFridgeLogs({required this.logs});

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(
            icon: Icons.lock_clock_outlined,
            title: 'Recent encrypted logs',
            subtitle:
                '${logs.length} locally stored snapshot${logs.length == 1 ? '' : 's'}',
          ),
          for (final log in logs.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  log.image.bytes,
                  width: 52,
                  height: 52,
                  cacheWidth: 160,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(
                log.analysis.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_formatDateTime(log.capturedAt)} • ${log.analysis.items.length} items',
              ),
              trailing: const Icon(Icons.lock_outline_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}

class _RecipesTab extends StatelessWidget {
  final FridgeLog? sourceLog;
  final bool busy;
  final VoidCallback? onRegenerate;
  final VoidCallback onOpenFridge;

  const _RecipesTab({
    required this.sourceLog,
    required this.busy,
    required this.onRegenerate,
    required this.onOpenFridge,
  });

  @override
  Widget build(BuildContext context) {
    final analysis = sourceLog?.analysis;
    final recipes = analysis?.recipes ?? const <RecipeSuggestion>[];
    return _PageScroll(
      children: [
        const _PageHeading(
          icon: Icons.menu_book_rounded,
          eyebrow: 'Inventory-aware planning',
          title: 'Recipes',
          body:
              'Turn the latest fridge observation into practical meals, missing-ingredient lists, and explicit verification steps.',
        ),
        if (sourceLog == null)
          _Surface(
            child: Column(
              children: [
                const _EmptyAnalysisCardContent(
                  icon: Icons.kitchen_outlined,
                  title: 'Start with a fridge log',
                  body:
                      'Recipes are generated only from a saved structured inventory snapshot.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onOpenFridge,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Open Fridge Log'),
                ),
              ],
            ),
          )
        else ...[
          _Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeading(
                  icon: Icons.inventory_2_outlined,
                  title: 'Recipe source',
                  subtitle:
                      '${analysis!.items.length} visible items • ${_formatDateTime(sourceLog!.capturedAt)}',
                  trailing: _StatusChip(
                    label: analysis.status.name,
                    color: analysis.status == FoodAnalysisStatus.complete
                        ? _FoodColors.mint
                        : _FoodColors.warning,
                  ),
                ),
                Text(
                  analysis.summary,
                  style: const TextStyle(
                    color: _FoodColors.subtext,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onRegenerate,
                  icon: Icon(
                    busy
                        ? Icons.hourglass_top_rounded
                        : Icons.auto_awesome_rounded,
                  ),
                  label: Text(
                    recipes.isEmpty
                        ? 'Generate recipes'
                        : 'Regenerate recipe set',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ],
            ),
          ),
          if (recipes.isEmpty)
            const _EmptyAnalysisCard(
              icon: Icons.no_meals_outlined,
              title: 'No validated recipes yet',
              body:
                  'Generate a fresh set. Invalid or incomplete structured recipes are not silently converted into meal instructions.',
            )
          else
            ...recipes.asMap().entries.map(
              (entry) =>
                  _RecipeDetailCard(recipe: entry.value, number: entry.key + 1),
            ),
        ],
      ],
    );
  }
}

class _RecipeDetailCard extends StatelessWidget {
  final RecipeSuggestion recipe;
  final int number;

  const _RecipeDetailCard({required this.recipe, required this.number});

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _FoodColors.mint.withAlpha(28),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: _FoodColors.mintSoft,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        color: _FoodColors.text,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${recipe.estimatedMinutes} estimated minutes',
                      style: const TextStyle(color: _FoodColors.subtext),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RecipeList(
            icon: Icons.check_circle_outline_rounded,
            title: 'Uses visible items',
            color: _FoodColors.mint,
            values: recipe.usesVisibleItems,
            emptyText: 'No visible ingredient mapping was returned.',
          ),
          const SizedBox(height: 10),
          _RecipeList(
            icon: Icons.shopping_cart_outlined,
            title: 'Still needed',
            color: _FoodColors.warning,
            values: recipe.missingIngredients,
            emptyText: 'No missing ingredient was reported.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Method',
            style: TextStyle(
              color: _FoodColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          if (recipe.steps.isEmpty)
            const _InlineEmpty('No structured preparation steps were returned.')
          else
            ...recipe.steps.asMap().entries.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 25,
                      child: Text(
                        '${step.key + 1}.',
                        style: const TextStyle(
                          color: _FoodColors.mint,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        step.value,
                        style: const TextStyle(
                          color: _FoodColors.subtext,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          _WarningBox(
            icon: Icons.fact_check_outlined,
            title: 'Verify before cooking',
            lines: [recipe.verificationNote],
          ),
        ],
      ),
    );
  }
}

class _RecipeList extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> values;
  final String emptyText;

  const _RecipeList({
    required this.icon,
    required this.title,
    required this.color,
    required this.values,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                color: _FoodColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        if (values.isEmpty)
          Text(emptyText, style: const TextStyle(color: _FoodColors.muted))
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final value in values)
                Chip(
                  label: Text(value),
                  backgroundColor: color.withAlpha(17),
                  side: BorderSide(color: color.withAlpha(70)),
                ),
            ],
          ),
      ],
    );
  }
}

class _BakeLabTab extends StatelessWidget {
  final FoodVisionImage? image;
  final BakeLog? latestLog;
  final List<BakeLog> recentLogs;
  final bool busy;
  final BakeItemKind kind;
  final ValueChanged<BakeItemKind?>? onKindChanged;
  final TextEditingController nameController;
  final TextEditingController elapsedController;
  final TextEditingController plannedController;
  final TextEditingController ovenController;
  final TextEditingController probeController;
  final TextEditingController targetController;
  final TextEditingController notesController;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onRemovePhoto;
  final VoidCallback? onAnalyze;

  const _BakeLabTab({
    required this.image,
    required this.latestLog,
    required this.recentLogs,
    required this.busy,
    required this.kind,
    required this.onKindChanged,
    required this.nameController,
    required this.elapsedController,
    required this.plannedController,
    required this.ovenController,
    required this.probeController,
    required this.targetController,
    required this.notesController,
    required this.onCamera,
    required this.onGallery,
    required this.onRemovePhoto,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      children: [
        const _PageHeading(
          icon: Icons.bakery_dining_rounded,
          eyebrow: 'Vision + deterministic simulation',
          title: 'Bake Lab',
          body:
              'Estimate a process-completion interval from visible cues, elapsed time, and optional probe evidence. Never treat it as proof of food safety.',
        ),
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionHeading(
                icon: Icons.tune_rounded,
                title: 'Bake evidence',
                subtitle:
                    'More measured evidence narrows the estimate. Temperatures use °F.',
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 680;
                  final fieldWidth = wide
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<BakeItemKind>(
                          initialValue: kind,
                          onChanged: onKindChanged,
                          decoration: const InputDecoration(
                            labelText: 'Bake profile',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: [
                            for (final value in BakeItemKind.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(_kindLabel(value)),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextField(
                          controller: nameController,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'Item name',
                            prefixIcon: Icon(Icons.label_outline_rounded),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _NumberField(
                          controller: elapsedController,
                          enabled: !busy,
                          label: 'Elapsed minutes',
                          icon: Icons.timer_outlined,
                          required: true,
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _NumberField(
                          controller: plannedController,
                          enabled: !busy,
                          label: 'Planned minutes',
                          icon: Icons.schedule_rounded,
                          required: true,
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _NumberField(
                          controller: ovenController,
                          enabled: !busy,
                          label: 'Oven setting °F',
                          icon: Icons.local_fire_department_outlined,
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _NumberField(
                          controller: probeController,
                          enabled: !busy,
                          label: 'Measured probe °F',
                          icon: Icons.thermostat_rounded,
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _NumberField(
                          controller: targetController,
                          enabled: !busy,
                          label: 'Recipe target °F',
                          icon: Icons.flag_outlined,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                enabled: !busy,
                maxLines: 3,
                maxLength: 1200,
                decoration: const InputDecoration(
                  labelText: 'Optional context',
                  hintText: 'Frozen pizza, dark pan, convection, top rack…',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 6),
              _PhotoSurface(
                image: image,
                enabled: !busy,
                onCamera: onCamera,
                onGallery: onGallery,
                onRemove: onRemovePhoto,
                emptyTitle: 'Photograph the baked item',
                emptyBody:
                    'Use neutral lighting and keep the visible surface and edges in frame. Avoid touching a hot oven or pan.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAnalyze,
                icon: Icon(
                  busy ? Icons.hourglass_top_rounded : Icons.science_outlined,
                ),
                label: Text(
                  busy
                      ? 'Simulation in progress…'
                      : 'Analyze & simulate completion',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
        if (latestLog == null)
          const _EmptyAnalysisCard(
            icon: Icons.query_stats_outlined,
            title: 'No bake simulation yet',
            body:
                'A completion interval and its independent timing, visual, and probe signals will appear here.',
          )
        else
          _BakeResultCard(log: latestLog!),
        if (recentLogs.isNotEmpty) _RecentBakeLogs(logs: recentLogs),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String label;
  final IconData icon;
  final bool required;

  const _NumberField({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.icon,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _BakeResultCard extends StatelessWidget {
  final BakeLog log;

  const _BakeResultCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final result = log.simulation;
    final visual = log.visual;
    return _Surface(
      accent: _FoodColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(
            icon: Icons.query_stats_rounded,
            title: '${log.input.itemName} completion estimate',
            subtitle:
                '${_formatDateTime(log.capturedAt)} • ${_phaseLabel(result.phase)}',
            trailing: _StatusChip(
              label: visual.confidence.label,
              color: switch (visual.confidence) {
                FoodConfidence.high => _FoodColors.mint,
                FoodConfidence.medium => _FoodColors.warning,
                FoodConfidence.low => _FoodColors.danger,
              },
            ),
          ),
          _CompletionBand(result: result),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 680
                  ? (constraints.maxWidth - 20) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: _SignalMetric(
                      label: 'Timing model',
                      value: result.timeSignal,
                      icon: Icons.timer_outlined,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _SignalMetric(
                      label: 'Visible surface',
                      value: result.visualSignal,
                      icon: Icons.visibility_outlined,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _SignalMetric(
                      label: 'Probe model',
                      value: result.thermalSignal,
                      icon: Icons.thermostat_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _WarningBox(
            icon: Icons.health_and_safety_outlined,
            title: 'Not a food-safety verdict',
            lines: [result.safetyMessage],
            danger: true,
          ),
          if (visual.observations.isNotEmpty) ...[
            const SizedBox(height: 14),
            _BulletSection(
              icon: Icons.visibility_outlined,
              title: 'Visible observations',
              values: visual.observations,
              color: _FoodColors.sky,
            ),
          ],
          if (visual.limitations.isNotEmpty) ...[
            const SizedBox(height: 12),
            _BulletSection(
              icon: Icons.help_outline_rounded,
              title: 'Limitations',
              values: visual.limitations,
              color: _FoodColors.warning,
            ),
          ],
          const SizedBox(height: 12),
          _BulletSection(
            icon: Icons.functions_rounded,
            title: 'Simulation signals',
            values: result.signals,
            color: _FoodColors.mint,
          ),
        ],
      ),
    );
  }
}

class _CompletionBand extends StatelessWidget {
  final BakeSimulationResult result;

  const _CompletionBand({required this.result});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Estimated completion ${result.estimatedPercent.toStringAsFixed(0)} percent, interval ${result.lowerBound.toStringAsFixed(0)} to ${result.upperBound.toStringAsFixed(0)} percent',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _FoodColors.field,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _FoodColors.warning.withAlpha(80)),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${result.estimatedPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: _FoodColors.text,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'estimated process completion\n${result.lowerBound.toStringAsFixed(0)}–${result.upperBound.toStringAsFixed(0)}% uncertainty band',
                      style: const TextStyle(
                        color: _FoodColors.subtext,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final lower = width * result.lowerBound / 100;
                final upper = width * result.upperBound / 100;
                final estimate = width * result.estimatedPercent / 100;
                return SizedBox(
                  height: 22,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        top: 7,
                        bottom: 7,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _FoodColors.muted.withAlpha(35),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Positioned(
                        left: lower,
                        top: 5,
                        width: (upper - lower).clamp(3, width),
                        height: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _FoodColors.warning.withAlpha(130),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (estimate - 2).clamp(0, width - 4),
                        top: 1,
                        width: 4,
                        height: 20,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _FoodColors.text,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 5),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0%', style: TextStyle(color: _FoodColors.muted)),
                Text('100%', style: TextStyle(color: _FoodColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalMetric extends StatelessWidget {
  final String label;
  final double? value;
  final IconData icon;

  const _SignalMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _FoodColors.field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _FoodColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _FoodColors.mintSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _FoodColors.subtext,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value == null
                      ? 'Not supplied'
                      : '${value!.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: _FoodColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> values;
  final Color color;

  const _BulletSection({
    required this.icon,
    required this.title,
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                color: _FoodColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(bottom: 5, left: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: _FoodColors.subtext,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentBakeLogs extends StatelessWidget {
  final List<BakeLog> logs;

  const _RecentBakeLogs({required this.logs});

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(
            icon: Icons.timeline_rounded,
            title: 'Recent bake estimates',
            subtitle:
                '${logs.length} encrypted simulation${logs.length == 1 ? '' : 's'}',
          ),
          for (final log in logs.take(6))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  log.image.bytes,
                  width: 52,
                  height: 52,
                  cacheWidth: 160,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(log.input.itemName),
              subtitle: Text(
                '${_formatDateTime(log.capturedAt)} • ${log.simulation.lowerBound.toStringAsFixed(0)}–${log.simulation.upperBound.toStringAsFixed(0)}%',
              ),
              trailing: Text(
                '${log.simulation.estimatedPercent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: _FoodColors.warning,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SafetyTab extends StatelessWidget {
  final Widget? child;

  const _SafetyTab({required this.child});

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      children: [
        const _PageHeading(
          icon: Icons.health_and_safety_rounded,
          eyebrow: 'Independent verification',
          title: 'Safety Scanner',
          body:
              'Inspect a food or water concern separately from inventory and bake-completion estimates.',
        ),
        const _Surface(
          accent: _FoodColors.warning,
          child: _WarningBox(
            icon: Icons.warning_amber_rounded,
            title: 'Vision has hard limits',
            lines: [
              'An image cannot rule out pathogens, toxins, allergens, unsafe internal temperature, or contamination outside the frame.',
              'When evidence is uncertain, discard suspect food or follow authoritative local food-safety guidance.',
            ],
            danger: true,
          ),
        ),
        if (child != null)
          _Surface(padding: EdgeInsets.zero, child: child!)
        else
          const _DefaultSafetyContent(),
      ],
    );
  }
}

class _DefaultSafetyContent extends StatelessWidget {
  const _DefaultSafetyContent();

  @override
  Widget build(BuildContext context) {
    return const _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(
            icon: Icons.extension_outlined,
            title: 'Safety scanner integration point',
            subtitle:
                'Provide foodSafetyChild to embed the app’s dedicated scanner here.',
          ),
          _SafetyPrinciple(
            icon: Icons.visibility_outlined,
            title: 'Observation is not clearance',
            body:
                'No visible mold does not prove that food is safe. Hidden spoilage and microbial risks can remain.',
          ),
          _SafetyPrinciple(
            icon: Icons.thermostat_rounded,
            title: 'Measure internal temperature',
            body:
                'Use an appropriate thermometer and recipe or manufacturer target instead of appearance alone.',
          ),
          _SafetyPrinciple(
            icon: Icons.label_outline_rounded,
            title: 'Verify labels and allergens',
            body:
                'Never infer allergen-free status, expiry, or recall status from package appearance.',
          ),
        ],
      ),
    );
  }
}

class _SafetyPrinciple extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _SafetyPrinciple({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _FoodColors.mintSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _FoodColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: _FoodColors.subtext,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  final bool danger;

  const _WarningBox({
    required this.icon,
    required this.title,
    required this.lines,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? _FoodColors.danger : _FoodColors.warning;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withAlpha(17),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withAlpha(85)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: _FoodColors.text,
                        height: 1.35,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _StatusChip({
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyAnalysisCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyAnalysisCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: _EmptyAnalysisCardContent(icon: icon, title: title, body: body),
    );
  }
}

class _EmptyAnalysisCardContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyAnalysisCardContent({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: _FoodColors.muted, size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _FoodColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _FoodColors.subtext, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final String text;

  const _InlineEmpty(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _FoodColors.field,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(color: _FoodColors.muted)),
    );
  }
}

Color _priorityColor(String priority) => switch (priority.toLowerCase()) {
  'high' => _FoodColors.danger,
  'low' => _FoodColors.sky,
  _ => _FoodColors.warning,
};

String _kindLabel(BakeItemKind kind) => switch (kind) {
  BakeItemKind.pizza => 'Pizza',
  BakeItemKind.bread => 'Bread',
  BakeItemKind.cake => 'Cake',
  BakeItemKind.cookies => 'Cookies',
  BakeItemKind.pastry => 'Pastry',
  BakeItemKind.casserole => 'Casserole',
  BakeItemKind.custom => 'Custom item',
};

String _phaseLabel(BakePhase phase) => switch (phase) {
  BakePhase.early => 'Early phase',
  BakePhase.setting => 'Structure setting',
  BakePhase.browning => 'Browning phase',
  BakePhase.nearlyDone => 'Estimated nearly done',
  BakePhase.estimatedComplete => 'Estimated complete—verify physically',
  BakePhase.unknown => 'Unknown phase',
};

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
      ? local.hour - 12
      : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month}/${local.day}/${local.year} $hour:$minute $period';
}
