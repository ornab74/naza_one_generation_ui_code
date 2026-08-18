import 'package:flutter/widgets.dart';
import 'package:naza_one/naza_rev_recall/app/app_controller.dart';
import 'package:naza_one/naza_rev_recall/audio/audio_service.dart';

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    required this.audio,
    required super.notifier,
    required super.child,
    super.key,
  });

  final EngineAudioService audio;

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this context.');
    return scope!.notifier!;
  }

  static EngineAudioService audioOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this context.');
    return scope!.audio;
  }
}
