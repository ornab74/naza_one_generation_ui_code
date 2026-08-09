export 'app.dart';

import 'app.dart' as app;
import 'onboarding/boot_coordinator.dart';
import 'security/secure_database.dart';

Future<void> main() async {
  // Existing legacy encrypted-data installs still enter the original vault
  // gate once so its authenticated migration/recovery machinery can import and
  // verify old records before cleanup. Fresh/current vaults use the new
  // vault-first onboarding coordinator.
  final inspection = await app.NazaVault.instance.inspect();
  if (inspection.access == NazaVaultAccess.setupRequired &&
      inspection.legacyDataPresent) {
    await app.main();
    return;
  }
  await NazaBootCoordinator.launch();
}
