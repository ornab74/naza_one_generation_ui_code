import 'package:flutter/material.dart';

import 'model_bootstrap/model_bootstrap_gate.dart';
import 'naza_app.dart' as naza;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ModelBootstrapGate(
      launchApp: naza.main,
    ),
  );
}
