# Archived regression suites

These suites are intentionally outside Flutter's auto-discovered `test/` directory.
They cover mature/stable subsystems and are retained for targeted regression work without making every packaging run pay the full historical test cost.

Run an archived suite explicitly when changing its subsystem, for example:

```bash
flutter test test_archive/naza_quantum_router_test.dart
flutter test test_archive/post_quantum_export_test.dart
```

The default release gate lives in `test/` and is deliberately small: first-run invariants, encrypted vault behavior, model bootstrap/integrity, backend policy, distribution/mirror trust, app smoke coverage, vision picker behavior, and runtime telemetry.

Do not move a test back into `test/` unless it protects a current release-critical path and is deterministic/fast. In particular, widget tests that rely on unbounded `pumpAndSettle()` or long timers must not block packaging.
