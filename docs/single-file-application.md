# Single-file application

All 121 former application Dart files are consolidated into
[`lib/main.dart`](../lib/main.dart). This is the editable source of truth, not a
generated bundle. Flutter continues to use the default `lib/main.dart` entry
point. There is no regeneration step.

## Navigation and names

The index at the top lists the former paths. Search for
`SOURCE SECTION: lib/chat/scroll_follow_controller.dart`, for example, to reach
that implementation. Existing architecture documents that mention old Dart
paths should be read as references to these sections.

The former app shell retains its private identifier names. Other former
libraries use a file-name prefix, such as `_scrollFollowControllerFollowTail`,
to avoid collisions and accidental private-member overrides when Dart combines
them into one library. A single library no longer enforces privacy between
sections; preserve those prefixes when editing existing declarations.

The vault-first `main()` remains the entry point. The former `app.main()` is
named `nazaLegacyMain()` and still handles the legacy startup path. The legacy
food widget is named `NazaLegacyFoodVisionHub`; `FoodVisionHub` remains the current
workspace. External imports retain their prefixes and disambiguate `Hmac` and
`ModelFileType` without changing which implementation each call uses.

Tests and archived tests import `package:naza_one/main.dart`. Source-inspection
tests read individual sections through `test/support/application_source.dart`,
so matching text in an unrelated feature cannot satisfy their assertions.
The AION analysis/formatting script now targets the consolidated file.
Rev Recall's license remains at `lib/naza_rev_recall/LICENSE`.

## Verification

- Compared all 121 sections against the original Dart token streams: all match
  after the explicit namespace changes and optional formatting commas.
- Formatted the consolidated source and changed source-inspection tests.
- Dart analysis reports the same six compile errors found before consolidation;
  no additional diagnostics remain from the merge.
- Attempted `flutter test --no-pub test/scroll_follow_controller_test.dart`.
  Compilation stops at the existing application errors listed below, before
  the test executes. Runtime behavior has not been verified.

The pre-existing errors are two non-integer arguments to `RangeError.range` in
the chromatic route planner, the broker key-schedule implementation missing
parameters required by `AionExternalKeySchedule`, the corresponding outdated
test implementation, and two MSL tests missing `authorizationIntent`.
These were left unchanged to keep this migration focused on consolidation.
Because every test now imports the complete application library, application
compile errors can also block tests that previously imported an isolated file.

Standard checks remain `flutter analyze --no-pub` and `flutter test --no-pub`.
