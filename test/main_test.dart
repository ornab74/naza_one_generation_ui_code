import 'package:flutter_test/flutter_test.dart';
import 'package:route_engine/main.dart';

void main() {
  test('empty live-offer state contains no bundled demo order', () {
    final offer = DeliveryOffer.empty();
    expect(offer.pay, 0);
    expect(offer.displayedMiles, 0);
    expect(offer.merchant, contains('Waiting'));
  });

  test('strict relay decision JSON maps to UI state', () {
    final decision = RouteDecision.fromJson({
      'verdict': 'TAKE',
      'confidence': .87,
      'score': .84,
      'headline': 'Good offer',
      'predicted_future': 'Likely clean run.',
      'primary_risk': 'traffic',
      'reasons': ['good economics'],
      'expected_minutes': 28,
      'expected_net_hourly': 26,
      'weather_gate': 'GO',
      'weather_reason': 'Dry with manageable wind.',
      'weather_score': .92,
      'spoken_summary': 'Take. Weather go.',
      'model': 'gpt-5.6-luna',
    });

    expect(decision.verdict, OfferVerdict.take);
    expect(decision.weatherGate, WeatherGate.go);
    expect(decision.model, 'gpt-5.6-luna');
  });

  test('settings preserve overlay control', () {
    final settings = const AppSettings().copyWith(overlayEnabled: false);
    expect(settings.overlayEnabled, isFalse);
    expect(settings.toJson()['overlayEnabled'], isFalse);
  });

  test('provider output is bounded and non-finite values fail closed', () {
    final decision = RouteDecision.fromJson({
      'verdict': 'TAKE',
      'confidence': double.nan,
      'score': double.infinity,
      'weather_gate': 'UNKNOWN',
      'headline': '${List.filled(200, 'x').join()}\u0000',
      'reasons': List.filled(20, 'reason'),
      'total_miles_estimate': -20,
      'highway_percent': 400,
    });

    expect(decision.confidence, .5);
    expect(decision.score, .5);
    expect(decision.weatherGate, WeatherGate.unavailable);
    expect(decision.headline.length, 120);
    expect(decision.headline, isNot(contains('\u0000')));
    expect(decision.reasons.length, 6);
    expect(decision.totalMilesEstimate, 0);
    expect(decision.highwayPercent, 100);
  });
}
