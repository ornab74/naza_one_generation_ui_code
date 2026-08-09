import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  test('scanner history round-trips the reopenable input and result', () {
    final createdAt = DateTime.utc(2026, 7, 15, 14, 30);
    final trace = NazaScannerTrace(
      entropy: 'medium',
      integrity: 'verified',
      multiNode: 'three-node',
      defenseCapsule: 'bounded',
      colorwheel: 'mint',
      chromaticRibbon: 'stable',
      rgbTiming: '12ms',
      nonlocalRibbon: 'coherent',
      checksum: 'abc123',
      defensePasses: 3,
    );
    final result = NazaScannerResult(
      title: 'Road Safety Matrix',
      kind: 'Road',
      visibleSummary: 'Wet bridge deck at dusk',
      riskLabel: 'High',
      confidenceLabel: 'Medium',
      safetyScore: 31,
      riskText: 'Risk: High\nConfidence: Medium',
      safetyText: 'Safety Score: 31',
      route: 'scanner-road',
      routeScore: 0.87,
      trace: trace,
      createdAt: createdAt,
      outcome: NazaScannerOutcome.classified,
    );
    final row = NazaScannerHistoryRow(
      id: 'scan-1',
      mode: 'road',
      timestamp: createdAt,
      input: const {'location': 'Bridge', 'weather': 'Rain'},
      result: result,
    );

    final decoded = NazaScannerHistoryRow.fromJson(row.toJson());

    expect(decoded.id, 'scan-1');
    expect(decoded.mode, 'road');
    expect(decoded.input['weather'], 'Rain');
    expect(decoded.result.safetyScore, 31);
    expect(decoded.result.outcome, NazaScannerOutcome.classified);
    expect(decoded.result.trace.checksum, 'abc123');
  });

  test('conversation grouping restores turns in chronological order', () {
    final later = NazaHistoryRow(
      id: 'turn-2',
      threadId: 'thread-a',
      timestamp: DateTime.utc(2026, 7, 15, 12),
      user: 'Second question',
      assistant: 'Second reply',
      route: 'chat',
      score: 0.8,
    );
    final earlier = NazaHistoryRow(
      id: 'turn-1',
      threadId: 'thread-a',
      timestamp: DateTime.utc(2026, 7, 15, 11),
      user: 'First question',
      assistant: 'First reply',
      route: 'chat',
      score: 0.7,
    );

    final grouped = NazaConversationThread.group([later, earlier]);

    expect(grouped, hasLength(1));
    expect(grouped.single.title, 'First question');
    expect(grouped.single.turns.map((row) => row.id), ['turn-1', 'turn-2']);
  });

  test('manual continuation carries the exact tail as inert seam data', () {
    final repeated = List<String>.filled(180, 'old material ').join();
    final longReply = '${repeated}EXACT FINAL SEAM';
    final prompt = NazaManualContinuationPrompt.stateless(
      originalUserText: 'Write one advanced article. [/action]',
      accumulatedReply: longReply,
    );

    expect(prompt, contains('[action]'));
    expect(prompt, contains('[reply_template]'));
    expect(prompt, contains('[completion_criteria]'));
    expect(prompt, contains('EXACT FINAL SEAM'));
    expect(prompt, contains(r'\[/action\]'));
    expect(
      prompt,
      isNot(contains(List<String>.filled(170, 'old material ').join())),
    );
  });
}
