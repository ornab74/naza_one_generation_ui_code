// LLM-CONTEXT:BEGIN
// FILE: test/unified_feature_drawer_test.dart
// ROLE: Owns unified feature drawer test behavior within the verification subsystem.
// DOMAIN: verification
// SECURITY-INVARIANT: Tests encode behavioral and security contracts; update assertions only with an intentional contract change.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/navigation/unified_feature_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('pin policy rejects unknown, duplicate, and oversized input', () {
    final raw = <Object?>[
      'unknown',
      'road-scanner',
      'road-scanner',
      42,
      'food-scanner',
      'health',
      'walking',
      'history',
      'settings',
      'bookforge',
    ];

    final result = NazaFeaturePinPolicy.sanitize(raw, <String>{
      'chat',
      'road-scanner',
      'food-scanner',
      'health',
      'walking',
      'history',
      'settings',
      'bookforge',
    });

    expect(result.first, NazaFeaturePinPolicy.requiredId);
    expect(result, hasLength(NazaFeaturePinPolicy.maxPins));
    expect(result.toSet(), hasLength(result.length));
    expect(result, isNot(contains('unknown')));
  });

  testWidgets('opens one wheel and invokes only registered callbacks', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var opened = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: NazaUnifiedFeatureDrawer(
            selectedId: 'chat',
            surface: const Color(0xFF07110E),
            panel: const Color(0xFF10201B),
            border: const Color(0xFF315247),
            text: Colors.white,
            subtext: Colors.white70,
            destinations: <NazaFeatureDestination>[
              NazaFeatureDestination(
                id: 'chat',
                label: 'Chatbot',
                description: 'Private chat',
                category: 'Core',
                icon: Icons.chat_rounded,
                accent: Colors.purpleAccent,
                onOpen: () => opened = 'chat',
              ),
              NazaFeatureDestination(
                id: 'road-scanner',
                label: 'Road',
                description: 'Road scanner',
                category: 'Scan',
                icon: Icons.route_rounded,
                accent: Colors.cyanAccent,
                onOpen: () => opened = 'road-scanner',
              ),
              NazaFeatureDestination(
                id: 'food-scanner',
                label: 'Food',
                description: 'Food scanner',
                category: 'Scan',
                icon: Icons.restaurant_rounded,
                accent: Colors.orangeAccent,
                onOpen: () => opened = 'food-scanner',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('unified-feature-drawer')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('open-feature-wheel')));
    await tester.pumpAndSettle();
    expect(find.text('Your feature wheel'), findsOneWidget);

    await tester.tap(find.text('Road').last);
    await tester.pumpAndSettle();
    expect(opened, 'road-scanner');
    expect(find.text('Your feature wheel'), findsNothing);
  });

  testWidgets('desktop rail opens and configures the same feature registry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var opened = '';
    final destinations = <NazaFeatureDestination>[
      NazaFeatureDestination(
        id: 'chat',
        label: 'Chatbot',
        description: 'Chat',
        category: 'Core',
        icon: Icons.chat,
        accent: Colors.purple,
        onOpen: () => opened = 'chat',
      ),
      NazaFeatureDestination(
        id: 'findit',
        label: 'FindIt',
        description: 'Find places',
        category: 'Intelligence',
        icon: Icons.explore,
        accent: Colors.cyan,
        onOpen: () => opened = 'findit',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              NazaUnifiedFeatureRail(
                destinations: destinations,
                selectedId: 'chat',
                surface: Colors.black,
                panel: Colors.black87,
                border: Colors.white24,
                text: Colors.white,
                subtext: Colors.white70,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unified-feature-rail')), findsOneWidget);
    await tester.tap(find.byTooltip('View and configure all features'));
    await tester.pumpAndSettle();
    expect(find.text('Feature orbit'), findsOneWidget);
    await tester.tap(find.text('FindIt'));
    await tester.pumpAndSettle();
    expect(opened, 'findit');
  });
}
