import 'package:flutter/material.dart';
import 'package:naza_one/naza_rev_recall/app/app_controller.dart';
import 'package:naza_one/naza_rev_recall/app/app_scope.dart';
import 'package:naza_one/naza_rev_recall/app/app_shell.dart';
import 'package:naza_one/naza_rev_recall/audio/audio_service.dart';
import 'package:naza_one/naza_rev_recall/widgets/neon_widgets.dart';

Future<void> runRevRecallStandalone() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RevRecallBootstrap());
}

class RevRecallBootstrap extends StatefulWidget {
  const RevRecallBootstrap({super.key});

  @override
  State<RevRecallBootstrap> createState() => _RevRecallBootstrapState();
}

class _RevRecallBootstrapState extends State<RevRecallBootstrap> {
  late final AppController controller;
  late final EngineAudioService audio;

  @override
  void initState() {
    super.initState();
    controller = AppController();
    audio = EngineAudioService();
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: controller,
      audio: audio,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.isReady) {
            return const _SplashScreen();
          }
          return const AppShell();
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: NeonBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GradientTitle(text: 'REV//RECALL', fontSize: 36),
              SizedBox(height: 20),
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('WARMING UP THE GARAGE'),
            ],
          ),
        ),
      ),
    );
  }
}
