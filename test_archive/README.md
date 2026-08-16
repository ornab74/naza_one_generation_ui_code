# Archived regression suites

These suites are intentionally outside Flutter's auto-discovered `test/` directory.
They cover mature/stable subsystems and are retained for targeted regression work without making every packaging run pay the full historical test cost.

Run an archived suite explicitly when changing its subsystem, for example:

```bash
flutter test test_archive/naza_quantum_router_test.dart
flutter test test_archive/post_quantum_export_test.dart
```

The default local command discovers `test/`. Release CI additionally runs the
release-critical suites listed below, so these protections cannot be omitted
from packaging by the directory layout:

- food repository, vision parsing, and shelf scanner safety;
- security kernel, persistent audit, and release trust;
- post-quantum export/recovery/state and trust policy.

The remaining archived suites are targeted regression tests and are not
implicitly release-gating until they are promoted deliberately.

Do not move a test back into `test/` unless it protects a current release-critical path and is deterministic/fast. In particular, widget tests that rely on unbounded `pumpAndSettle()` or long timers must not block packaging.
