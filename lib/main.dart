import 'package:flutter/material.dart';

import 'model_bootstrap/low_resource_model_seeder.dart';
import 'model_bootstrap/model_bootstrap_gate.dart';
import 'naza_app.dart' as naza;

final LowResourceModelSeeder _modelSeeder = LowResourceModelSeeder(
  enabled: true,
  maxConnections: 8,
  goMemoryLimit: '256MiB',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ModelBootstrapGate(
      launchApp: naza.main,
      modelSeeder: _modelSeeder,
    ),
  );
}
