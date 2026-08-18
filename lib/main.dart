// Naza Route Engine — single-file Flutter prototype
//
// Online-only architecture:
//   DoorDash accessibility event -> encrypted Android capture vault ->
//   Flutter/native online analysis -> live location/weather/radar ->
//   Naza Relay -> GPT-5.6-Luna -> decision -> TTS -> Google Maps handoff.
//
// Android package name requested for the app shell:
//   com.qroadsan.routengine
//
// IMPORTANT:
// - This file does not contain or request a raw OpenAI API key.
// - Configure a HTTPS Naza Relay URL in Settings. The relay is expected to call
//   model "gpt-5.6-luna" and return the JSON contract documented below.
// - Autonomous third-party-app button presses are intentionally represented by
//   a SIMULATED AUTO action in this Dart-only prototype. Native Android plumbing
//   can provide accessibility events, but should not bypass security controls.
//
// Expected pubspec dependencies:
//   flutter:
//     sdk: flutter
//   http: ^1.6.0
//   shared_preferences: ^2.5.5
//   flutter_tts: ^4.2.5
//   url_launcher: ^6.3.2
//   geolocator: ^14.0.2

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_selector/file_selector.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const int _maxScreenshotBytes = 8 * 1024 * 1024;
const int _maxJsonResponseBytes = 1024 * 1024;
const int _maxRadarTileBytes = 2 * 1024 * 1024;

String _cleanText(Object? value, {int maxLength = 500, String fallback = ''}) {
  final raw = value?.toString() ?? fallback;
  final cleaned = raw
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
      .trim();
  return cleaned.length <= maxLength ? cleaned : cleaned.substring(0, maxLength);
}

double _finiteNumber(Object? value, double fallback,
    {double? min, double? max}) {
  final number = value is num ? value.toDouble() : fallback;
  if (!number.isFinite) return fallback;
  return number
      .clamp(min ?? -double.maxFinite, max ?? double.maxFinite)
      .toDouble();
}

String _imageMimeType(Uint8List bytes) {
  if (bytes.length > _maxScreenshotBytes) {
    throw const FormatException('Image is larger than the 8 MB safety limit.');
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 && bytes[1] == 0x50 &&
      bytes[2] == 0x4e && bytes[3] == 0x47 &&
      bytes[4] == 0x0d && bytes[5] == 0x0a &&
      bytes[6] == 0x1a && bytes[7] == 0x0a) return 'image/png';
  if (bytes.length >= 3 &&
      bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return 'image/webp';
  }
  if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4d) {
    return 'image/bmp';
  }
  throw const FormatException(
      'Only valid PNG, JPEG, WebP, or BMP images are accepted.');
}

Future<Uint8List> _readValidatedImage(XFile file) async {
  final length = await file.length();
  if (length <= 0 || length > _maxScreenshotBytes) {
    throw const FormatException('Image must be between 1 byte and 8 MB.');
  }
  final bytes = await file.readAsBytes();
  _imageMimeType(bytes);
  return bytes;
}

Map<String, dynamic> _boundedJsonObject(http.Response response, String service) {
  if (response.bodyBytes.length > _maxJsonResponseBytes) {
    throw StateError('$service returned an oversized response.');
  }
  final contentType = response.headers['content-type']?.toLowerCase() ?? '';
  if (contentType.isNotEmpty && !contentType.contains('json')) {
    throw StateError('$service returned an unexpected content type.');
  }
  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  if (decoded is! Map) throw StateError('$service returned invalid JSON.');
  return Map<String, dynamic>.from(decoded);
}

Future<http.Response> _sendLimited(
  http.Request request, {
  required int maxBytes,
  required Duration timeout,
}) async {
  request.followRedirects = false;
  request.maxRedirects = 0;
  return (() async {
    final streamed = await request.send();
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in streamed.stream) {
      if (bytes.length + chunk.length > maxBytes) {
        throw StateError('Network response exceeded its safety limit.');
      }
      bytes.add(chunk);
    }
    return http.Response.bytes(
      bytes.takeBytes(),
      streamed.statusCode,
      headers: streamed.headers,
      reasonPhrase: streamed.reasonPhrase,
      request: request,
    );
  })().timeout(timeout);
}

Future<http.Response> _getLimited(Uri uri,
        {int maxBytes = _maxJsonResponseBytes,
        Duration timeout = const Duration(seconds: 15)}) =>
    _sendLimited(http.Request('GET', uri), maxBytes: maxBytes, timeout: timeout);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RouteEngineApp());
}

// -----------------------------------------------------------------------------
// THEME
// -----------------------------------------------------------------------------

class AppTheme {
  static const Color bg0 = Color(0xFF05060B);
  static const Color bg1 = Color(0xFF0A0D16);
  static const Color panel = Color(0xFF111521);
  static const Color panel2 = Color(0xFF171C2A);
  static const Color text = Color(0xFFF4F7FF);
  static const Color muted = Color(0xFF9AA5BD);
  static const Color cyan = Color(0xFF45E6FF);
  static const Color green = Color(0xFF66FFB2);
  static const Color amber = Color(0xFFFFCF5C);
  static const Color red = Color(0xFFFF5A72);
  static const Color violet = Color(0xFFB86BFF);

  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: cyan,
      brightness: Brightness.dark,
      surface: panel,
    );
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: bg0,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      cardTheme: const CardThemeData(
        elevation: 0,
        color: panel,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .07)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: cyan),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg1.withValues(alpha: .96),
        indicatorColor: cyan.withValues(alpha: .16),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? text : muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// DOMAIN MODELS
// -----------------------------------------------------------------------------

enum OfferVerdict {
  strongTake,
  take,
  borderline,
  skip,
  hardSkip,
  unavailable,
}

extension OfferVerdictUi on OfferVerdict {
  String get label => switch (this) {
        OfferVerdict.strongTake => 'STRONG TAKE',
        OfferVerdict.take => 'TAKE',
        OfferVerdict.borderline => 'BORDERLINE',
        OfferVerdict.skip => 'SKIP',
        OfferVerdict.hardSkip => 'HARD SKIP',
        OfferVerdict.unavailable => 'AWAITING LUNA',
      };

  Color get color => switch (this) {
        OfferVerdict.strongTake || OfferVerdict.take => AppTheme.green,
        OfferVerdict.borderline => AppTheme.amber,
        OfferVerdict.skip || OfferVerdict.hardSkip => AppTheme.red,
        OfferVerdict.unavailable => AppTheme.cyan,
      };

  IconData get icon => switch (this) {
        OfferVerdict.strongTake || OfferVerdict.take => Icons.bolt_rounded,
        OfferVerdict.borderline => Icons.balance_rounded,
        OfferVerdict.skip || OfferVerdict.hardSkip => Icons.block_rounded,
        OfferVerdict.unavailable => Icons.hourglass_top_rounded,
      };

  bool get isTake =>
      this == OfferVerdict.strongTake || this == OfferVerdict.take;
}

enum WeatherGate { go, caution, noGo, unavailable }

extension WeatherGateUi on WeatherGate {
  String get label => switch (this) {
        WeatherGate.go => 'WEATHER GO',
        WeatherGate.caution => 'WEATHER CAUTION',
        WeatherGate.noGo => 'WEATHER NO-GO',
        WeatherGate.unavailable => 'WEATHER UNKNOWN',
      };

  Color get color => switch (this) {
        WeatherGate.go => AppTheme.green,
        WeatherGate.caution => AppTheme.amber,
        WeatherGate.noGo => AppTheme.red,
        WeatherGate.unavailable => AppTheme.muted,
      };
}

enum AutoActionMode { off, voiceConfirm, simulatedAuto }

extension AutoActionModeUi on AutoActionMode {
  String get label => switch (this) {
        AutoActionMode.off => 'Off',
        AutoActionMode.voiceConfirm => 'Voice confirm',
        AutoActionMode.simulatedAuto => 'Simulated auto',
      };
}

class DeliveryOffer {
  const DeliveryOffer({
    required this.id,
    required this.pay,
    required this.displayedMiles,
    required this.merchant,
    required this.orderCount,
    required this.dropoffCount,
    this.deliverBy,
    this.estimatedMinutes,
    this.deadheadMiles = 0,
    this.destinationLabel = 'Destination not extracted',
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.rawText = const [],
  });

  final String id;
  final double pay;
  final double displayedMiles;
  final String merchant;
  final int orderCount;
  final int dropoffCount;
  final DateTime? deliverBy;
  final double? estimatedMinutes;
  final double deadheadMiles;
  final String destinationLabel;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final List<String> rawText;

  double get modeledMiles => math.max(.1, displayedMiles + deadheadMiles);
  double get dollarsPerMile => pay / modeledMiles;

  DeliveryOffer copyWith({
    double? pay,
    double? displayedMiles,
    String? merchant,
    int? orderCount,
    int? dropoffCount,
    DateTime? deliverBy,
    double? estimatedMinutes,
    double? deadheadMiles,
    String? destinationLabel,
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropoffLatitude,
    double? dropoffLongitude,
    List<String>? rawText,
  }) {
    return DeliveryOffer(
      id: id,
      pay: pay ?? this.pay,
      displayedMiles: displayedMiles ?? this.displayedMiles,
      merchant: merchant ?? this.merchant,
      orderCount: orderCount ?? this.orderCount,
      dropoffCount: dropoffCount ?? this.dropoffCount,
      deliverBy: deliverBy ?? this.deliverBy,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      deadheadMiles: deadheadMiles ?? this.deadheadMiles,
      destinationLabel: destinationLabel ?? this.destinationLabel,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      dropoffLatitude: dropoffLatitude ?? this.dropoffLatitude,
      dropoffLongitude: dropoffLongitude ?? this.dropoffLongitude,
      rawText: rawText ?? this.rawText,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pay': pay,
        'displayed_miles': displayedMiles,
        'merchant': merchant,
        'order_count': orderCount,
        'dropoff_count': dropoffCount,
        'deliver_by': deliverBy?.toIso8601String(),
        'estimated_minutes': estimatedMinutes,
        'deadhead_miles': deadheadMiles,
        'destination_label': destinationLabel,
        'pickup': pickupLatitude == null
            ? null
            : {'lat': pickupLatitude, 'lon': pickupLongitude},
        'dropoff': dropoffLatitude == null
            ? null
            : {'lat': dropoffLatitude, 'lon': dropoffLongitude},
        'raw_text': rawText,
      };

  static DeliveryOffer empty() {
    return const DeliveryOffer(
      id: 'awaiting-live-offer',
      pay: 0,
      displayedMiles: 0,
      merchant: 'Waiting for a live DoorDash offer',
      orderCount: 1,
      dropoffCount: 1,
      destinationLabel: 'No live offer captured yet',
    );
  }
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.latitude,
    required this.longitude,
    required this.temperatureC,
    required this.apparentTemperatureC,
    required this.precipitationMm,
    required this.rainMm,
    required this.showersMm,
    required this.weatherCode,
    required this.cloudCover,
    required this.windSpeedKph,
    required this.windGustKph,
    required this.visibilityM,
    required this.updatedAt,
  });

  final double latitude;
  final double longitude;
  final double temperatureC;
  final double apparentTemperatureC;
  final double precipitationMm;
  final double rainMm;
  final double showersMm;
  final int weatherCode;
  final double cloudCover;
  final double windSpeedKph;
  final double windGustKph;
  final double visibilityM;
  final DateTime updatedAt;

  double get visibilityKm => visibilityM / 1000;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'temperature_c': temperatureC,
        'apparent_temperature_c': apparentTemperatureC,
        'precipitation_mm': precipitationMm,
        'rain_mm': rainMm,
        'showers_mm': showersMm,
        'weather_code': weatherCode,
        'cloud_cover_percent': cloudCover,
        'wind_speed_kph': windSpeedKph,
        'wind_gust_kph': windGustKph,
        'visibility_km': visibilityKm,
        'updated_at': updatedAt.toIso8601String(),
      };
}

class DailyForecast {
  const DailyForecast({required this.date, required this.highC, required this.lowC, required this.precipitationMm, required this.precipitationProbability, required this.maxWindKph, required this.weatherCode});
  final DateTime date;
  final double highC;
  final double lowC;
  final double precipitationMm;
  final double precipitationProbability;
  final double maxWindKph;
  final int weatherCode;
}

class RadarFrame {
  const RadarFrame({
    required this.timestamp,
    required this.tileUrl,
    required this.bytes,
  });

  final DateTime timestamp;
  final String tileUrl;
  final Uint8List bytes;
}

class RadarAnalysis {
  const RadarAnalysis({
    required this.summary,
    required this.severity,
    required this.stormProbability,
    required this.routeImpact,
    required this.model,
  });

  final String summary;
  final double severity;
  final double stormProbability;
  final String routeImpact;
  final String model;

  factory RadarAnalysis.fromJson(Map<String, dynamic> json) {
    double d(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return RadarAnalysis(
      summary: json['summary']?.toString() ?? 'No radar narrative.',
      severity: d('severity').clamp(0, 1),
      stormProbability: d('storm_probability').clamp(0, 1),
      routeImpact: json['route_impact']?.toString() ?? 'Unknown',
      model: json['model']?.toString() ?? 'gpt-5.6-luna',
    );
  }

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'severity': severity,
        'storm_probability': stormProbability,
        'route_impact': routeImpact,
        'model': model,
      };
}

class ManualScreenshotRecord {
  const ManualScreenshotRecord({required this.bytes, required this.createdAt, required this.decision});
  final Uint8List bytes;
  final DateTime createdAt;
  final RouteDecision decision;
}

class RouteDecision {
  const RouteDecision({
    required this.verdict,
    required this.confidence,
    required this.score,
    required this.headline,
    required this.predictedFuture,
    required this.primaryRisk,
    required this.reasons,
    required this.expectedMinutes,
    required this.expectedNetHourly,
    required this.weatherGate,
    required this.weatherReason,
    required this.weatherScore,
    required this.spokenSummary,
    required this.model,
    required this.pickupEstimate,
    required this.dropoffEstimate,
    required this.propertyType,
    required this.locationConfidence,
    required this.totalMilesEstimate,
    required this.highwayPercent,
    required this.routeDifficulty,
    required this.routeSummary,
  });

  final OfferVerdict verdict;
  final double confidence;
  final double score;
  final String headline;
  final String predictedFuture;
  final String primaryRisk;
  final List<String> reasons;
  final double expectedMinutes;
  final double expectedNetHourly;
  final WeatherGate weatherGate;
  final String weatherReason;
  final double weatherScore;
  final String spokenSummary;
  final String model;
  final String pickupEstimate;
  final String dropoffEstimate;
  final String propertyType;
  final double locationConfidence;
  final double totalMilesEstimate;
  final double highwayPercent;
  final String routeDifficulty;
  final String routeSummary;

  factory RouteDecision.awaiting() => const RouteDecision(
        verdict: OfferVerdict.unavailable,
        confidence: 0,
        score: 0,
        headline: 'CONNECT TO LUNA',
        predictedFuture:
            'Configure the relay in Settings, then observe the offer.',
        primaryRisk: 'Online analysis unavailable',
        reasons: [],
        expectedMinutes: 0,
        expectedNetHourly: 0,
        weatherGate: WeatherGate.unavailable,
        weatherReason: 'No live weather analysis yet.',
        weatherScore: 0,
        spokenSummary: 'Luna analysis is not available yet.',
        model: 'gpt-5.6-luna',
        pickupEstimate: 'Not visible',
        dropoffEstimate: 'Not visible',
        propertyType: 'Unknown',
        locationConfidence: 0,
        totalMilesEstimate: 0,
        highwayPercent: 0,
        routeDifficulty: 'Unknown',
        routeSummary: 'No route estimate yet.',
      );

  factory RouteDecision.fromJson(Map<String, dynamic> json) {
    final verdictRaw = (json['verdict'] ?? 'BORDERLINE')
        .toString()
        .toUpperCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    final weatherRaw = (json['weather_gate'] ?? 'WEATHER_UNKNOWN')
        .toString()
        .toUpperCase();
    final verdict = switch (verdictRaw) {
      'STRONG_TAKE' => OfferVerdict.strongTake,
      'TAKE' => OfferVerdict.take,
      'SKIP' => OfferVerdict.skip,
      'HARD_SKIP' => OfferVerdict.hardSkip,
      _ => OfferVerdict.borderline,
    };
    final weatherGate = switch (weatherRaw) {
      'GO' || 'WEATHER_GO' => WeatherGate.go,
      'CAUTION' || 'WEATHER_CAUTION' => WeatherGate.caution,
      'NO_GO' || 'NO-GO' || 'WEATHER_NO_GO' => WeatherGate.noGo,
      _ => WeatherGate.unavailable,
    };
    final reasonsRaw = json['reasons'];
    return RouteDecision(
      verdict: verdict,
      confidence: _finiteNumber(json['confidence'], .5, min: 0, max: 1),
      score: _finiteNumber(json['score'], .5, min: 0, max: 1),
      headline: _cleanText(json['headline'], maxLength: 120, fallback: verdict.label),
      predictedFuture: _cleanText(json['predicted_future'], maxLength: 1200,
          fallback: 'No future narrative.'),
      primaryRisk: _cleanText(json['primary_risk'], maxLength: 240,
          fallback: 'Unknown'),
      reasons: reasonsRaw is List
          ? reasonsRaw
              .map((e) => _cleanText(e, maxLength: 240))
              .where((e) => e.isNotEmpty)
              .take(6)
              .toList()
          : const [],
      expectedMinutes: _finiteNumber(json['expected_minutes'], 0,
          min: 0, max: 1440),
      expectedNetHourly: _finiteNumber(json['expected_net_hourly'], 0,
          min: -1000, max: 10000),
      weatherGate: weatherGate,
      weatherReason: _cleanText(json['weather_reason'], maxLength: 500,
          fallback: 'No weather explanation.'),
      weatherScore: _finiteNumber(json['weather_score'], .5, min: 0, max: 1),
      spokenSummary: _cleanText(json['spoken_summary'], maxLength: 300,
          fallback: '${verdict.label}. ${json['headline'] ?? ''}'),
      model: _cleanText(json['model'], maxLength: 100, fallback: 'gpt-5.6-luna'),
      pickupEstimate: _cleanText(json['pickup_estimate'], maxLength: 240,
          fallback: 'Not visible'),
      dropoffEstimate: _cleanText(json['dropoff_estimate'], maxLength: 240,
          fallback: 'Not visible'),
      propertyType: _cleanText(json['property_type'], maxLength: 40,
          fallback: 'Unknown'),
      locationConfidence: _finiteNumber(json['location_confidence'], 0,
          min: 0, max: 1),
      totalMilesEstimate: _finiteNumber(json['total_miles_estimate'], 0,
          min: 0, max: 1000),
      highwayPercent: _finiteNumber(json['highway_percent'], 0,
          min: 0, max: 100),
      routeDifficulty: _cleanText(json['route_difficulty'], maxLength: 40,
          fallback: 'Unknown'),
      routeSummary: _cleanText(json['route_summary'], maxLength: 800,
          fallback: 'No route estimate yet.'),
    );
  }

  Map<String, dynamic> toJson() => {
        'verdict': verdict.label,
        'confidence': confidence,
        'score': score,
        'headline': headline,
        'predicted_future': predictedFuture,
        'primary_risk': primaryRisk,
        'reasons': reasons,
        'expected_minutes': expectedMinutes,
        'expected_net_hourly': expectedNetHourly,
        'weather_gate': weatherGate.label,
        'weather_reason': weatherReason,
        'weather_score': weatherScore,
        'spoken_summary': spokenSummary,
        'model': model,
        'pickup_estimate': pickupEstimate,
        'dropoff_estimate': dropoffEstimate,
        'property_type': propertyType,
        'location_confidence': locationConfidence,
        'total_miles_estimate': totalMilesEstimate,
        'highway_percent': highwayPercent,
        'route_difficulty': routeDifficulty,
        'route_summary': routeSummary,
      };
}

class DecisionRecord {
  const DecisionRecord({
    required this.offer,
    required this.decision,
    required this.createdAt,
    required this.action,
  });

  final DeliveryOffer offer;
  final RouteDecision decision;
  final DateTime createdAt;
  final String action;

  Map<String, dynamic> toJson() => {
        'offer': offer.toJson(),
        'decision': decision.toJson(),
        'created_at': createdAt.toIso8601String(),
        'action': action,
      };
}

class AppSettings {
  const AppSettings({
    this.relayUrl = '',
    this.relayToken = '',
    this.apiKey = '',
    this.zipCode = '',
    this.useFahrenheit = false,
    this.vehicleType = 'motorcycle',
    this.aiProvider = 'openai',
    this.aiModel = 'gpt-5.6-luna',
    this.minimumPayout = 8,
    this.minimumDollarsPerMile = 1.75,
    this.targetHourly = 22,
    this.maxWindGustKph = 55,
    this.maxPrecipitationMm = 2.5,
    this.minVisibilityKm = 4,
    this.maxRadarSeverity = .65,
    this.speakDecisions = true,
    this.autoNavigate = true,
    this.monitorEnabled = true,
    this.radarEnabled = true,
    this.overlayEnabled = true,
    this.voiceRate = .48,
    this.autoActionMode = AutoActionMode.simulatedAuto,
    this.autoTakeThreshold = .82,
    this.autoSkipThreshold = .30,
  });

  final String relayUrl;
  final String relayToken;
  final String apiKey;
  final String zipCode;
  final bool useFahrenheit;
  final String vehicleType;
  final String aiProvider;
  final String aiModel;
  final double minimumPayout;
  final double minimumDollarsPerMile;
  final double targetHourly;
  final double maxWindGustKph;
  final double maxPrecipitationMm;
  final double minVisibilityKm;
  final double maxRadarSeverity;
  final bool speakDecisions;
  final bool autoNavigate;
  final bool monitorEnabled;
  final bool radarEnabled;
  final bool overlayEnabled;
  final double voiceRate;
  final AutoActionMode autoActionMode;
  final double autoTakeThreshold;
  final double autoSkipThreshold;

  AppSettings copyWith({
    String? relayUrl,
    String? relayToken,
    String? apiKey,
    String? zipCode,
    bool? useFahrenheit,
    String? vehicleType,
    String? aiProvider,
    String? aiModel,
    double? minimumPayout,
    double? minimumDollarsPerMile,
    double? targetHourly,
    double? maxWindGustKph,
    double? maxPrecipitationMm,
    double? minVisibilityKm,
    double? maxRadarSeverity,
    bool? speakDecisions,
    bool? autoNavigate,
    bool? monitorEnabled,
    bool? radarEnabled,
    bool? overlayEnabled,
    double? voiceRate,
    AutoActionMode? autoActionMode,
    double? autoTakeThreshold,
    double? autoSkipThreshold,
  }) {
    return AppSettings(
      relayUrl: relayUrl ?? this.relayUrl,
      relayToken: relayToken ?? this.relayToken,
      apiKey: apiKey ?? this.apiKey,
      zipCode: zipCode ?? this.zipCode,
      useFahrenheit: useFahrenheit ?? this.useFahrenheit,
      vehicleType: vehicleType ?? this.vehicleType,
      aiProvider: aiProvider ?? this.aiProvider,
      aiModel: aiModel ?? this.aiModel,
      minimumPayout: minimumPayout ?? this.minimumPayout,
      minimumDollarsPerMile:
          minimumDollarsPerMile ?? this.minimumDollarsPerMile,
      targetHourly: targetHourly ?? this.targetHourly,
      maxWindGustKph: maxWindGustKph ?? this.maxWindGustKph,
      maxPrecipitationMm: maxPrecipitationMm ?? this.maxPrecipitationMm,
      minVisibilityKm: minVisibilityKm ?? this.minVisibilityKm,
      maxRadarSeverity: maxRadarSeverity ?? this.maxRadarSeverity,
      speakDecisions: speakDecisions ?? this.speakDecisions,
      autoNavigate: autoNavigate ?? this.autoNavigate,
      monitorEnabled: monitorEnabled ?? this.monitorEnabled,
      radarEnabled: radarEnabled ?? this.radarEnabled,
      overlayEnabled: overlayEnabled ?? this.overlayEnabled,
      voiceRate: voiceRate ?? this.voiceRate,
      autoActionMode: autoActionMode ?? this.autoActionMode,
      autoTakeThreshold: autoTakeThreshold ?? this.autoTakeThreshold,
      autoSkipThreshold: autoSkipThreshold ?? this.autoSkipThreshold,
    );
  }

  Map<String, dynamic> toJson() => {
        'relayUrl': relayUrl,
        'relayToken': relayToken,
        'aiProvider': aiProvider,
        'aiModel': aiModel,
        'zipCode': zipCode,
        'useFahrenheit': useFahrenheit,
        'vehicleType': vehicleType,
        'minimumPayout': minimumPayout,
        'minimumDollarsPerMile': minimumDollarsPerMile,
        'targetHourly': targetHourly,
        'maxWindGustKph': maxWindGustKph,
        'maxPrecipitationMm': maxPrecipitationMm,
        'minVisibilityKm': minVisibilityKm,
        'maxRadarSeverity': maxRadarSeverity,
        'speakDecisions': speakDecisions,
        'autoNavigate': autoNavigate,
        'monitorEnabled': monitorEnabled,
        'radarEnabled': radarEnabled,
        'overlayEnabled': overlayEnabled,
        'voiceRate': voiceRate,
        'autoActionMode': autoActionMode.name,
        'autoTakeThreshold': autoTakeThreshold,
        'autoSkipThreshold': autoSkipThreshold,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    double d(String key, double fallback) =>
        (j[key] as num?)?.toDouble() ?? fallback;
    return AppSettings(
      relayUrl: j['relayUrl']?.toString() ?? '',
      relayToken: j['relayToken']?.toString() ?? '',
      apiKey: '',
      zipCode: j['zipCode']?.toString() ?? '',
      useFahrenheit: j['useFahrenheit'] as bool? ?? false,
      vehicleType: j['vehicleType']?.toString() == 'car' ? 'car' : 'motorcycle',
      aiProvider: j['aiProvider']?.toString() ?? 'openai',
      aiModel: j['aiModel']?.toString() ?? 'gpt-5.6-luna',
      minimumPayout: d('minimumPayout', 8),
      minimumDollarsPerMile: d('minimumDollarsPerMile', 1.75),
      targetHourly: d('targetHourly', 22),
      maxWindGustKph: d('maxWindGustKph', 55),
      maxPrecipitationMm: d('maxPrecipitationMm', 2.5),
      minVisibilityKm: d('minVisibilityKm', 4),
      maxRadarSeverity: d('maxRadarSeverity', .65),
      speakDecisions: j['speakDecisions'] as bool? ?? true,
      autoNavigate: j['autoNavigate'] as bool? ?? true,
      monitorEnabled: j['monitorEnabled'] as bool? ?? true,
      radarEnabled: j['radarEnabled'] as bool? ?? true,
      overlayEnabled: j['overlayEnabled'] as bool? ?? true,
      voiceRate: d('voiceRate', .48),
      autoActionMode: AutoActionMode.values.firstWhere(
        (v) => v.name == j['autoActionMode'],
        orElse: () => AutoActionMode.simulatedAuto,
      ),
      autoTakeThreshold: d('autoTakeThreshold', .82),
      autoSkipThreshold: d('autoSkipThreshold', .30),
    );
  }
}

// -----------------------------------------------------------------------------
// PERSISTENCE
// -----------------------------------------------------------------------------

class SettingsStore {
  static const _settingsKey = 'route_engine.settings.v2';
  static const _historyKey = 'route_engine.history.v2';
  static const _apiKeyName = 'route_engine.provider_api_key';
  static const _secure = FlutterSecureStorage();

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) {
      return AppSettings(apiKey: await _secure.read(key: _apiKeyName) ?? '');
    }
    try {
      final settings = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return settings.copyWith(apiKey: await _secure.read(key: _apiKeyName) ?? '');
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final safe = Map<String, dynamic>.from(settings.toJson())
      ..remove('relayToken');
    safe.remove('apiKey');
    await prefs.setString(_settingsKey, jsonEncode(safe));
    if (settings.apiKey.trim().isEmpty) {
      await _secure.delete(key: _apiKeyName);
    } else {
      await _secure.write(key: _apiKeyName, value: settings.apiKey.trim());
    }
  }

  Future<List<Map<String, dynamic>>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List
          ? decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
          : [];
    } catch (_) {
      return [];
    }
  }

  Future<void> appendRecord(DecisionRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    history.insert(0, record.toJson());
    if (history.length > 100) history.removeRange(100, history.length);
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}

// -----------------------------------------------------------------------------
// LIVE LOCATION + WEATHER
// -----------------------------------------------------------------------------

class LocationService {
  Future<Position> currentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is required for route weather.');
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location services are disabled.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
  }
}

class OpenMeteoService {
  const OpenMeteoService();

  Future<(double, double, String)> geocodeZip(String zip) async {
    final query = zip.trim();
    if (query.isEmpty || query.length > 20 ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9 -]*$').hasMatch(query)) {
      throw const FormatException('Enter a valid ZIP or postal code.');
    }
    final response = await _getLimited(Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query, 'count': '1', 'language': 'en', 'format': 'json',
    }), timeout: const Duration(seconds: 10));
    if (response.statusCode != 200) throw StateError('ZIP geocoding failed.');
    final decoded = _boundedJsonObject(response, 'ZIP geocoding');
    final results = (decoded['results'] as List?) ?? const [];
    if (results.isEmpty) throw StateError('ZIP code not found.');
    if (results.first is! Map) throw StateError('ZIP geocoding returned invalid data.');
    final first = Map<String, dynamic>.from(results.first as Map);
    final latitude = _finiteNumber(first['latitude'], double.nan);
    final longitude = _finiteNumber(first['longitude'], double.nan);
    if (!latitude.isFinite || !longitude.isFinite ||
        latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw StateError('ZIP geocoding returned invalid coordinates.');
    }
    return (latitude, longitude,
        _cleanText(first['name'], maxLength: 100, fallback: query));
  }

  Future<List<DailyForecast>> forecast({required double latitude, required double longitude}) async {
    final response = await _getLimited(Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$latitude', 'longitude': '$longitude', 'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max', 'forecast_days': '7', 'timezone': 'auto', 'wind_speed_unit': 'kmh',
    }));
    if (response.statusCode != 200) throw StateError('Forecast request failed.');
    final decoded = _boundedJsonObject(response, 'Forecast');
    final daily = (decoded['daily'] as Map?)?.cast<String, dynamic>();
    if (daily == null) throw StateError('Forecast returned invalid data.');
    final fields = <List?>[
      daily['time'] as List?, daily['temperature_2m_max'] as List?,
      daily['temperature_2m_min'] as List?, daily['precipitation_sum'] as List?,
      daily['precipitation_probability_max'] as List?, daily['wind_speed_10m_max'] as List?,
      daily['weather_code'] as List?,
    ];
    if (fields.any((field) => field == null)) {
      throw StateError('Forecast returned incomplete data.');
    }
    final count = fields
        .map((field) => field!.length)
        .reduce((a, b) => a < b ? a : b)
        .clamp(0, 7)
        .toInt();
    final forecasts = <DailyForecast>[];
    for (var i = 0; i < count; i++) {
      final date = DateTime.tryParse(fields[0]![i].toString());
      if (date == null) continue;
      forecasts.add(DailyForecast(
        date: date,
        highC: _finiteNumber(fields[1]![i], 0, min: -100, max: 70),
        lowC: _finiteNumber(fields[2]![i], 0, min: -100, max: 70),
        precipitationMm: _finiteNumber(fields[3]![i], 0, min: 0, max: 1000),
        precipitationProbability: _finiteNumber(fields[4]![i], 0, min: 0, max: 100),
        maxWindKph: _finiteNumber(fields[5]![i], 0, min: 0, max: 500),
        weatherCode: _finiteNumber(fields[6]![i], -1, min: -1, max: 999).toInt(),
      ));
    }
    if (forecasts.isEmpty) throw StateError('Forecast contained no valid days.');
    return forecasts;
  }

  Future<WeatherSnapshot> current({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(5),
      'longitude': longitude.toStringAsFixed(5),
      'current': [
        'temperature_2m',
        'apparent_temperature',
        'precipitation',
        'rain',
        'showers',
        'weather_code',
        'cloud_cover',
        'wind_speed_10m',
        'wind_gusts_10m',
      ].join(','),
      'hourly': 'visibility',
      'forecast_days': '1',
      'timezone': 'auto',
      'wind_speed_unit': 'kmh',
    });
    final response = await _getLimited(uri);
    if (response.statusCode != 200) {
      throw StateError('Open-Meteo returned ${response.statusCode}.');
    }
    final json = _boundedJsonObject(response, 'Open-Meteo');
    final current = (json['current'] as Map?)?.cast<String, dynamic>() ?? {};
    final hourly = (json['hourly'] as Map?)?.cast<String, dynamic>() ?? {};
    final visibility = (hourly['visibility'] as List?) ?? const [];
    final currentTime = current['time']?.toString();
    final times = (hourly['time'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    var visibilityM = visibility.isEmpty
        ? 10000.0
        : _finiteNumber(visibility.first, 10000, min: 0, max: 1000000);
    if (currentTime != null && times.isNotEmpty && visibility.isNotEmpty) {
      final needle = DateTime.tryParse(currentTime);
      if (needle != null) {
        var best = 0;
        var bestDelta = const Duration(days: 9999);
        for (var i = 0; i < times.length && i < visibility.length; i++) {
          final t = DateTime.tryParse(times[i]);
          if (t == null) continue;
          final delta = t.difference(needle).abs();
          if (delta < bestDelta) {
            bestDelta = delta;
            best = i;
          }
        }
        visibilityM = _finiteNumber(visibility[best], 10000,
            min: 0, max: 1000000);
      }
    }

    double d(String k, {double min = -1000, double max = 1000}) =>
        _finiteNumber(current[k], 0, min: min, max: max);
    return WeatherSnapshot(
      latitude: latitude,
      longitude: longitude,
      temperatureC: d('temperature_2m', min: -100, max: 70),
      apparentTemperatureC: d('apparent_temperature', min: -120, max: 80),
      precipitationMm: d('precipitation', min: 0, max: 1000),
      rainMm: d('rain', min: 0, max: 1000),
      showersMm: d('showers', min: 0, max: 1000),
      weatherCode: _finiteNumber(current['weather_code'], -1, min: -1, max: 999).toInt(),
      cloudCover: d('cloud_cover', min: 0, max: 100),
      windSpeedKph: d('wind_speed_10m', min: 0, max: 500),
      windGustKph: d('wind_gusts_10m', min: 0, max: 500),
      visibilityM: _finiteNumber(visibilityM, 10000, min: 0, max: 1000000),
      updatedAt:
          DateTime.tryParse(currentTime ?? '') ?? DateTime.now().toUtc(),
    );
  }
}

// -----------------------------------------------------------------------------
// RAINVIEWER RADAR
// -----------------------------------------------------------------------------

class RainViewerService {
  const RainViewerService();

  Future<RadarFrame> latestFrame({
    required double latitude,
    required double longitude,
    int zoom = 7,
    int tileSize = 256,
  }) async {
    final meta = await _getLimited(
        Uri.parse('https://api.rainviewer.com/public/weather-maps.json'));
    if (meta.statusCode != 200) {
      throw StateError('RainViewer metadata returned ${meta.statusCode}.');
    }
    final decoded = _boundedJsonObject(meta, 'RainViewer metadata');
    final radar = (decoded['radar'] as Map?)?.cast<String, dynamic>() ?? {};
    final past = (radar['past'] as List?) ?? const [];
    if (past.isEmpty) throw StateError('RainViewer returned no radar frames.');
    final frame = (past.last as Map).cast<String, dynamic>();
    final path = frame['path']?.toString();
    final time = (frame['time'] as num?)?.toInt();
    if (path == null || time == null || path.length > 100 ||
        !RegExp(r'^/v2/radar/[A-Za-z0-9_-]+$').hasMatch(path)) {
      throw StateError('RainViewer frame metadata is incomplete.');
    }

    final tile = _latLonToTile(latitude, longitude, zoom);
    final url = Uri.https(
      'tilecache.rainviewer.com',
      '$path/$tileSize/$zoom/${tile.$1}/${tile.$2}/2/1_1.png',
    ).toString();
    final image = await _getLimited(Uri.parse(url), maxBytes: _maxRadarTileBytes);
    if (image.statusCode != 200) {
      throw StateError('Radar tile returned ${image.statusCode}.');
    }
    final imageType = image.headers['content-type']?.toLowerCase() ?? '';
    if (image.bodyBytes.length < 100 ||
        image.bodyBytes.length > _maxRadarTileBytes ||
        (imageType.isNotEmpty && !imageType.startsWith('image/'))) {
      throw StateError('RainViewer returned an empty radar tile.');
    }
    return RadarFrame(
      timestamp: DateTime.fromMillisecondsSinceEpoch(time * 1000, isUtc: true),
      tileUrl: url,
      bytes: image.bodyBytes,
    );
  }

  (int, int) _latLonToTile(double lat, double lon, int zoom) {
    final n = math.pow(2.0, zoom).toDouble();
    final x = ((lon + 180.0) / 360.0 * n).floor();
    final latRad = lat * math.pi / 180.0;
    final y = ((1.0 -
                math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
            2.0 *
            n)
        .floor();
    return (
      x.clamp(0, n.toInt() - 1).toInt(),
      y.clamp(0, n.toInt() - 1).toInt(),
    );
  }
}

// -----------------------------------------------------------------------------
// GPT-5.6-LUNA RELAY
// -----------------------------------------------------------------------------

class LunaRelayService {
  const LunaRelayService();

  Future<RouteDecision> analyze({
    required AppSettings settings,
    required DeliveryOffer offer,
    required WeatherSnapshot weather,
    RadarFrame? radarFrame,
    RadarAnalysis? priorRadarAnalysis,
    Position? currentPosition,
    Uint8List? screenshot,
  }) async {
    if (settings.apiKey.trim().isEmpty) {
      throw StateError('Configure a provider API key in Settings.');
    }
    final provider = settings.aiProvider;
    if (!const {'openai', 'grok', 'meta_muse'}.contains(provider)) {
      throw StateError('Unsupported AI provider.');
    }
    final model = settings.aiModel.trim();
    if (model.isEmpty || model.length > 100 ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$').hasMatch(model)) {
      throw const FormatException('The selected model name is invalid.');
    }
    final screenshotMime = screenshot == null ? null : _imageMimeType(screenshot);
    final isOpenAi = provider == 'openai';
    final uri = Uri.parse(isOpenAi
        ? 'https://api.openai.com/v1/responses'
        : provider == 'grok'
            ? 'https://api.x.ai/v1/chat/completions'
            : 'https://api.muse.meta.com/v1/chat/completions');

    final body = <String, dynamic>{
      'provider': provider,
      'model': model,
      'mode': 'delivery_motorcycle_foresight',
      'driver_zip_code': settings.zipCode,
      'vehicle_type': settings.vehicleType,
      'offer': offer.toJson(),
      'current_position': currentPosition == null
          ? null
          : {
              'lat': currentPosition.latitude,
              'lon': currentPosition.longitude,
              'speed_mps': currentPosition.speed,
              'heading': currentPosition.heading,
            },
      'weather': weather.toJson(),
      'radar': radarFrame == null
          ? null
          : {
              'captured_at': radarFrame.timestamp.toIso8601String(),
              'image_mime_type': 'image/png',
              'image_base64': base64Encode(radarFrame.bytes),
            },
      'rules': {
        'minimum_payout': settings.minimumPayout,
        'minimum_dollars_per_mile': settings.minimumDollarsPerMile,
        'target_hourly': settings.targetHourly,
        'motorcycle_weather_limits': {
          'max_wind_gust_kph': settings.maxWindGustKph,
          'max_precipitation_mm': settings.maxPrecipitationMm,
          'min_visibility_km': settings.minVisibilityKm,
          'max_radar_severity': settings.maxRadarSeverity,
        },
      },
      'required_output': {
        'verdict':
            'STRONG_TAKE | TAKE | BORDERLINE | SKIP | HARD_SKIP',
        'confidence': '0..1',
        'score': '0..1',
        'headline': 'short string',
        'predicted_future': 'one concise paragraph',
        'primary_risk': 'short string',
        'reasons': ['up to 6 concise strings'],
        'expected_minutes': 'number',
        'expected_net_hourly': 'number',
        'weather_gate': 'GO | CAUTION | NO_GO',
        'weather_reason': 'short string',
        'weather_score': '0..1',
        'spoken_summary': 'short motorcycle-friendly TTS sentence',
        'pickup_estimate': 'visible pickup address or area; never invent missing detail',
        'dropoff_estimate': 'visible drop-off address or area; never invent missing detail',
        'property_type': 'HOUSE | APARTMENT | CONDO | HOTEL | BUSINESS | UNKNOWN',
        'location_confidence': '0..1 visual evidence confidence',
        'total_miles_estimate': 'estimated actual door-to-door miles including pickup repositioning and likely deadhead, not just displayed offer miles',
        'highway_percent': '0..100 estimated route highway percentage',
        'route_difficulty': 'EASY | MODERATE | HARD | UNKNOWN based on urban density, turns, terrain, traffic, and access complexity',
        'route_summary': 'concise explanation of start area, end area, route difficulty, highway mix, and uncertainty',
        'radar_analysis': {
          'summary': 'string',
          'severity': '0..1',
          'storm_probability': '0..1',
          'route_impact': 'string',
          'model': 'gpt-5.6-luna',
        },
        'model': 'gpt-5.6-luna',
      },
    };

    final context = jsonEncode(body);
    final imageUrl = screenshot == null
        ? null
        : 'data:$screenshotMime;base64,${base64Encode(screenshot)}';
    final requestBody = isOpenAi
        ? {
            'model': model,
            'store': false,
            'input': [
              {'role': 'system', 'content': [{'type': 'input_text', 'text': 'You are a conservative vehicle-delivery route analyst. Use the vehicle_type, driver ZIP, offer text, screenshot, weather, and user rules as separate evidence sources. First extract only facts visibly supported by the screenshot; distinguish displayed miles from estimated total route miles. Use the driver ZIP only as a starting-area prior, never as proof of an exact address. Estimate pickup area, drop-off area, total miles, highway share, access complexity, and route difficulty with explicit uncertainty. For motorcycles apply stricter wind, rain, visibility, cold, and exposure penalties; for cars use vehicle-appropriate constraints. Calculate payout per displayed mile and estimated net hourly value. Do not SKIP a clearly profitable order without a concrete economic, route, or safety reason; use BORDERLINE when uncertainty is the only problem. Weather NO_GO is an independent safety veto. Return only valid JSON matching required_output. Never invent addresses or claim route certainty.'}]},
              {'role': 'user', 'content': [
                {'type': 'input_text', 'text': context},
                if (imageUrl != null) {'type': 'input_image', 'image_url': imageUrl, 'detail': 'high'},
              ]},
            ],
          }
        : {
            'model': model,
            'temperature': 0,
            'response_format': {'type': 'json_object'},
            'messages': [
              {'role': 'system', 'content': 'You are a conservative vehicle-delivery route analyst. Use the vehicle_type, driver ZIP, offer text, screenshot, weather, and user rules as separate evidence sources. First extract only facts visibly supported by the screenshot; distinguish displayed miles from estimated total route miles. Use the driver ZIP only as a starting-area prior, never as proof of an exact address. Estimate pickup area, drop-off area, total miles, highway share, access complexity, and route difficulty with explicit uncertainty. For motorcycles apply stricter wind, rain, visibility, cold, and exposure penalties; for cars use vehicle-appropriate constraints. Calculate payout per displayed mile and estimated net hourly value. Do not SKIP a clearly profitable order without a concrete economic, route, or safety reason; use BORDERLINE when uncertainty is the only problem. Weather NO_GO is an independent safety veto. Return only valid JSON matching required_output. Never invent addresses or claim route certainty.'},
              {'role': 'user', 'content': imageUrl == null ? context : [
                {'type': 'text', 'text': context},
                {'type': 'image_url', 'image_url': {'url': imageUrl}},
              ]},
            ],
          };
    final headers = <String, String>{
      'content-type': 'application/json',
      'accept': 'application/json',
      'authorization': 'Bearer ${settings.apiKey.trim()}',
    };
    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = jsonEncode(requestBody);
    final response = await _sendLimited(
      request,
      maxBytes: _maxJsonResponseBytes,
      timeout: const Duration(seconds: 60),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('$provider API returned HTTP ${response.statusCode}.');
    }
    final json = _boundedJsonObject(response, '$provider API');
    String? output = json['output_text']?.toString();
    if (output == null && json['output'] is List) {
      for (final item in (json['output'] as List)) {
        if (item is! Map) continue;
        final content = item['content'];
        if (content is List) {
          for (final part in content) {
            if (part is Map && part['text'] != null) {
              output = part['text'].toString();
              break;
            }
          }
        }
        if (output != null) break;
      }
    }
    if (output == null && json['choices'] is List && (json['choices'] as List).isNotEmpty) {
      final message = ((json['choices'] as List).first as Map)['message'];
      final content = message is Map ? message['content'] : null;
      output = content is List
          ? content.whereType<Map>().map((part) => part['text']?.toString() ?? '').join()
          : content?.toString();
    }
    if (output == null || output.isEmpty) throw StateError('Provider returned no decision JSON.');
    output = output.trim();
    if (utf8.encode(output).length > 128 * 1024) {
      throw StateError('Provider decision JSON was oversized.');
    }
    if (output.startsWith('```')) {
      output = output.replaceFirst(RegExp(r'^```(?:json)?\s*'), '').replaceFirst(RegExp(r'\s*```$'), '').trim();
    }
    final decisionJson = jsonDecode(output);
    if (decisionJson is! Map) throw StateError('Provider decision was not an object.');
    return RouteDecision.fromJson(Map<String, dynamic>.from(decisionJson));
  }
}

// -----------------------------------------------------------------------------
// TTS + NAVIGATION
// -----------------------------------------------------------------------------

class VoiceService {
  VoiceService() : _tts = FlutterTts();

  final FlutterTts _tts;
  Process? _linuxProcess;

  Future<void> speak(String text, {required double rate}) async {
    if (defaultTargetPlatform == TargetPlatform.linux) {
      await stop();
      final wordsPerMinute = (rate.clamp(.2, .75) * 300).round();
      try {
        _linuxProcess = await Process.start(
          'espeak-ng',
          ['-v', 'en-us', '-s', '$wordsPerMinute', text],
        );
      } on ProcessException {
        try {
          _linuxProcess = await Process.start('spd-say', [text]);
        } on ProcessException {
          // Install espeak-ng or speech-dispatcher to enable Linux TTS.
        }
      }
      return;
    }
    try {
      await _tts.stop();
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(rate.clamp(.2, .75));
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(false);
      await _tts.speak(text);
    } on MissingPluginException {
      // TTS is optional; analysis must still succeed without a desktop plugin.
    }
  }

  Future<void> stop() async {
    if (defaultTargetPlatform == TargetPlatform.linux) {
      _linuxProcess?.kill(ProcessSignal.sigterm);
      _linuxProcess = null;
      return;
    }
    try {
      await _tts.stop();
    } on MissingPluginException {
      // Unsupported platform.
    }
  }
}

class NavigationService {
  const NavigationService();

  Future<void> navigate(DeliveryOffer offer) async {
    Uri uri;
    if (offer.pickupLatitude != null && offer.pickupLongitude != null) {
      uri = Uri.parse(
        'google.navigation:q=${offer.pickupLatitude},${offer.pickupLongitude}&mode=d',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final query = Uri.encodeComponent(offer.merchant);
    uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=driving',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open Google Maps.');
    }
  }
}

// -----------------------------------------------------------------------------
// ANDROID ACCESSIBILITY BRIDGE
// -----------------------------------------------------------------------------

class DoorDashMonitorBridge {
  const DoorDashMonitorBridge();

  static const _events = EventChannel('route_engine/doordash_events');
  static const _methods = MethodChannel('route_engine/doordash_control');

  Stream<Map<String, dynamic>> events() {
    // This channel is implemented only by the Android accessibility bridge.
    // Never activate it on Linux: EventChannel attempts to invoke `listen`
    // immediately and otherwise throws MissingPluginException during startup.
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Stream<Map<String, dynamic>>.empty();
    }
    return _events.receiveBroadcastStream().where((event) => event is Map).map(
          (event) => Map<String, dynamic>.from(event as Map),
        ).handleError((_) {});
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _methods.invokeMethod('openAccessibilitySettings');
    } on MissingPluginException {
      // Laptop / unsupported target: the UI remains usable for manual testing.
    }
  }

  Future<void> setMonitoringEnabled(bool enabled) async {
    try {
      await _methods.invokeMethod(
        'setMonitoringEnabled',
        {'enabled': enabled},
      );
    } on MissingPluginException {
      // No native monitor on desktop.
    }
  }

  Future<List<SecureCaptureSummary>> listCaptures({int limit = 80}) async {
    try {
      final raw = await _methods.invokeMethod<List<dynamic>>(
        'listCaptures',
        {'limit': limit},
      );
      return (raw ?? const <dynamic>[])
          .whereType<Map>()
          .map((e) => SecureCaptureSummary.fromMap(
                Map<String, dynamic>.from(e),
              ))
          .toList();
    } on MissingPluginException {
      return const <SecureCaptureSummary>[];
    }
  }

  Future<SecureCaptureDetail?> loadCapture(int id) async {
    try {
      final raw = await _methods.invokeMethod<Map<dynamic, dynamic>>(
        'loadCapture',
        {'id': id},
      );
      if (raw == null) return null;
      return SecureCaptureDetail.fromMap(Map<String, dynamic>.from(raw));
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> clearCaptures() async {
    try {
      await _methods.invokeMethod('clearCaptures');
    } on MissingPluginException {
      // Desktop has no native encrypted vault.
    }
  }

  Future<Map<String, dynamic>> getNativeSettings() async {
    try {
      final raw =
          await _methods.invokeMethod<Map<dynamic, dynamic>>('getNativeSettings');
      return raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(raw);
    } on MissingPluginException {
      return <String, dynamic>{};
    }
  }

  Future<void> saveNativeSettings(AppSettings settings) async {
    try {
      await _methods.invokeMethod('saveNativeSettings', settings.toJson());
    } on MissingPluginException {
      // Desktop/local UI preview.
    }
  }

  Future<Map<String, dynamic>> runtimeStatus() async {
    try {
      final raw =
          await _methods.invokeMethod<Map<dynamic, dynamic>>('runtimeStatus');
      return raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(raw);
    } on MissingPluginException {
      return <String, dynamic>{'platformBridge': false};
    }
  }

  Future<void> previewOverlay({
    required String verdict,
    required String weather,
    required int argb,
  }) async {
    try {
      await _methods.invokeMethod('previewOverlay', {
        'verdict': verdict,
        'weather': weather,
        'argb': argb,
      });
    } on MissingPluginException {
      // Android-only.
    }
  }

  DeliveryOffer? parseEvent(Map<String, dynamic> event) {
    final text = (event['text'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    if (text.isEmpty) return null;
    final joined = text.join(' | ');
    final pay = _firstDouble(RegExp(r'\$(\d+(?:\.\d{1,2})?)'), joined);
    final miles =
        _firstDouble(RegExp(r'(\d+(?:\.\d+)?)\s*(?:mi|miles)', caseSensitive: false), joined);
    if (pay == null || miles == null) return null;

    String merchant = 'DoorDash offer';
    for (final line in text) {
      final lower = line.toLowerCase();
      if (line.length > 3 &&
          !line.contains(r'$') &&
          !lower.contains('mile') &&
          !lower.contains('deliver') &&
          !lower.contains('accept') &&
          !lower.contains('decline')) {
        merchant = line;
        break;
      }
    }
    final stack = joined.toLowerCase().contains('2 orders') ? 2 : 1;
    return DeliveryOffer(
      id: 'live-${DateTime.now().millisecondsSinceEpoch}',
      pay: pay,
      displayedMiles: miles,
      merchant: merchant,
      orderCount: stack,
      dropoffCount: stack,
      rawText: text,
    );
  }

  double? _firstDouble(RegExp exp, String input) {
    final match = exp.firstMatch(input);
    return double.tryParse(match?.group(1) ?? '');
  }
}


class SecureCaptureSummary {
  const SecureCaptureSummary({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.hasScreenshot,
    required this.payload,
    required this.decision,
  });

  final int id;
  final DateTime createdAt;
  final String kind;
  final bool hasScreenshot;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? decision;

  factory SecureCaptureSummary.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> object(String key) {
      final value = map[key];
      if (value is Map) return Map<String, dynamic>.from(value);
      if (value is String && value.isNotEmpty) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      return <String, dynamic>{};
    }

    final decision = object('decision');
    return SecureCaptureSummary(
      id: (map['id'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      kind: map['kind']?.toString() ?? 'UNKNOWN',
      hasScreenshot: map['hasScreenshot'] == true,
      payload: object('payload'),
      decision: decision.isEmpty ? null : decision,
    );
  }

  String get title {
    final merchant = payload['merchant']?.toString().trim();
    if (merchant != null && merchant.isNotEmpty) return merchant;
    final text = payload['text'];
    if (text is List && text.isNotEmpty) {
      final first = text.first.toString().trim();
      if (first.isNotEmpty) return first;
    }
    return kind.replaceAll('_', ' ');
  }

  String get verdict => decision?['verdict']?.toString() ?? 'CAPTURED';
  String get weather => decision?['weather_gate']?.toString() ?? 'WX PENDING';
}

class SecureCaptureDetail extends SecureCaptureSummary {
  const SecureCaptureDetail({
    required super.id,
    required super.createdAt,
    required super.kind,
    required super.hasScreenshot,
    required super.payload,
    required super.decision,
    required this.screenshot,
  });

  final Uint8List? screenshot;

  factory SecureCaptureDetail.fromMap(Map<String, dynamic> map) {
    final base = SecureCaptureSummary.fromMap(map);
    final raw = map['screenshot'];
    return SecureCaptureDetail(
      id: base.id,
      createdAt: base.createdAt,
      kind: base.kind,
      hasScreenshot: base.hasScreenshot,
      payload: base.payload,
      decision: base.decision,
      screenshot: raw is Uint8List
          ? raw
          : raw is List
              ? Uint8List.fromList(raw.cast<int>())
              : null,
    );
  }
}

// -----------------------------------------------------------------------------
// APP CONTROLLER
// -----------------------------------------------------------------------------

class RouteEngineController extends ChangeNotifier {
  RouteEngineController({
    SettingsStore? settingsStore,
    LocationService? locationService,
    OpenMeteoService? weatherService,
    RainViewerService? radarService,
    LunaRelayService? lunaService,
    VoiceService? voiceService,
    NavigationService? navigationService,
    DoorDashMonitorBridge? monitorBridge,
  })  : _store = settingsStore ?? SettingsStore(),
        _location = locationService ?? LocationService(),
        _weatherService = weatherService ?? const OpenMeteoService(),
        _radarService = radarService ?? const RainViewerService(),
        _luna = lunaService ?? const LunaRelayService(),
        _voice = voiceService ?? VoiceService(),
        _navigation = navigationService ?? const NavigationService(),
        _monitor = monitorBridge ?? const DoorDashMonitorBridge();

  final SettingsStore _store;
  final LocationService _location;
  final OpenMeteoService _weatherService;
  final RainViewerService _radarService;
  final LunaRelayService _luna;
  final VoiceService _voice;
  final NavigationService _navigation;
  final DoorDashMonitorBridge _monitor;

  AppSettings settings = const AppSettings();
  DeliveryOffer offer = DeliveryOffer.empty();
  RouteDecision decision = RouteDecision.awaiting();
  WeatherSnapshot? weather;
  List<DailyForecast> forecast = const [];
  String? weatherLocation;
  RadarFrame? radarFrame;
  Position? position;
  String status = 'Ready';
  String simulatedAction = 'NONE';
  Object? lastError;
  bool busy = false;
  bool showAnalysisLoader = false;
  bool initialized = false;
  Uint8List? testScreenshot;
  String? testScreenshotName;
  List<Map<String, dynamic>> history = [];
  List<SecureCaptureSummary> captures = const [];
  final List<ManualScreenshotRecord> manualScreenshotHistory = [];
  Map<String, dynamic> nativeStatus = const {};
  StreamSubscription<Map<String, dynamic>>? _monitorSub;

  List<double> get recentAiScores => history.take(5).map((record) {
        final decision = record['decision'];
        return decision is Map ? (decision['score'] as num?)?.toDouble() ?? .5 : .5;
      }).toList();

  double get chromaticWaveScore {
    final recent = recentAiScores;
    if (recent.isEmpty) return decision.score;
    final average = recent.reduce((a, b) => a + b) / recent.length;
    return (decision.score * .7 + average * .3).clamp(0.0, 1.0).toDouble();
  }

  double get chromaticUncertainty {
    final recent = recentAiScores;
    if (recent.length < 2) return 1 - decision.confidence;
    final mean = recent.reduce((a, b) => a + b) / recent.length;
    final variance = recent.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / recent.length;
    return (1 - decision.confidence + math.sqrt(variance)).clamp(0.0, 1.0).toDouble();
  }

  bool get shouldSuggestBreak {
    final recent = recentAiScores;
    return recent.length >= 3 && recent.reduce((a, b) => a + b) / recent.length < .38;
  }

  Future<void> initialize() async {
    try {
      settings = await _store.loadSettings();
      final native = await _monitor.getNativeSettings();
      if (native.isNotEmpty) {
        settings = settings.copyWith(
          relayUrl: native['relayUrl']?.toString() ?? settings.relayUrl,
          relayToken: native['relayToken']?.toString() ?? settings.relayToken,
          monitorEnabled:
              native['monitorEnabled'] as bool? ?? settings.monitorEnabled,
          radarEnabled: native['radarEnabled'] as bool? ?? settings.radarEnabled,
          overlayEnabled:
              native['overlayEnabled'] as bool? ?? settings.overlayEnabled,
          speakDecisions:
              native['speakDecisions'] as bool? ?? settings.speakDecisions,
          autoNavigate: native['autoNavigate'] as bool? ?? settings.autoNavigate,
        );
      }
      history = await _store.loadHistory();
      captures = await _monitor.listCaptures();
      nativeStatus = await _monitor.runtimeStatus();
      initialized = true;
      if (settings.monitorEnabled && defaultTargetPlatform == TargetPlatform.android) {
        await startMonitor();
      }
    } catch (error) {
      // Initialization must never prevent the first frame or leave an
      // unhandled async exception on desktop.
      lastError = error;
      status = 'Local startup completed with limited features';
    } finally {
      notifyListeners();
    }
  }

  Future<void> startMonitor() async {
    await _monitorSub?.cancel();
    _monitorSub = _monitor.events().listen(
      (event) async {
        captures = await _monitor.listCaptures();
        final parsed = _monitor.parseEvent(event);
        if (parsed != null) {
          offer = parsed;
        }
        final decisionRaw = event['decision'];
        if (decisionRaw is Map) {
          decision = RouteDecision.fromJson(
            Map<String, dynamic>.from(decisionRaw),
          );
          status = 'Background Luna decision: ${decision.verdict.label}';
        } else {
          status = event['status']?.toString() ??
              (parsed == null
                  ? 'DoorDash state changed'
                  : 'New DoorDash offer securely captured');
        }
        notifyListeners();
      },
      onError: (Object e) {
        lastError = e;
        notifyListeners();
      },
    );
    await _monitor.setMonitoringEnabled(true);
  }

  Future<void> stopMonitor() async {
    await _monitorSub?.cancel();
    _monitorSub = null;
    await _monitor.setMonitoringEnabled(false);
    notifyListeners();
  }

  void clearCurrentOffer() {
    offer = DeliveryOffer.empty();
    decision = RouteDecision.awaiting();
    simulatedAction = 'NONE';
    status = 'Waiting for a live offer';
    notifyListeners();
  }

  void setTestScreenshot(Uint8List bytes, String name) {
    _imageMimeType(bytes);
    testScreenshot = bytes;
    testScreenshotName = name;
    status = 'Test screenshot loaded';
    notifyListeners();
  }

  void clearTestScreenshot() {
    testScreenshot = null;
    testScreenshotName = null;
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings value) async {
    settings = value;
    await _store.saveSettings(value);
    await _monitor.saveNativeSettings(value);
    if (value.monitorEnabled &&
        _monitorSub == null &&
        defaultTargetPlatform == TargetPlatform.android) {
      await startMonitor();
    } else if (!value.monitorEnabled && _monitorSub != null) {
      await stopMonitor();
    }
    notifyListeners();
  }

  Future<void> analyzeCurrentOffer() async {
    if (busy) return;
    busy = true;
    showAnalysisLoader = true;
    lastError = null;
    status = 'Acquiring live position';
    notifyListeners();

    try {
      if (settings.zipCode.trim().isNotEmpty) {
        final place = await _weatherService.geocodeZip(settings.zipCode.trim());
        weatherLocation = place.$3;
        position = Position(latitude: place.$1, longitude: place.$2, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0, isMocked: true);
      } else {
        if (defaultTargetPlatform == TargetPlatform.linux) {
          throw StateError(
            'Linux location service is unavailable. Enter a ZIP/postal code in Settings for weather.',
          );
        }
        position = await _location.currentPosition();
        weatherLocation = 'Current location';
      }
      status = 'Reading Open-Meteo';
      notifyListeners();

      weather = await _weatherService.current(
        latitude: position!.latitude,
        longitude: position!.longitude,
      );
      forecast = await _weatherService.forecast(
        latitude: position!.latitude,
        longitude: position!.longitude,
      );

      if (settings.radarEnabled) {
        status = 'Scanning live radar';
        notifyListeners();
        radarFrame = await _radarService.latestFrame(
          latitude: position!.latitude,
          longitude: position!.longitude,
        );
      } else {
        radarFrame = null;
      }

      status = 'GPT-5.6-Luna is collapsing the route';
      notifyListeners();

      decision = await _luna.analyze(
        settings: settings,
        offer: offer,
        weather: weather!,
        radarFrame: radarFrame,
        currentPosition: position,
        screenshot: testScreenshot,
      );
      if (testScreenshot != null) {
        manualScreenshotHistory.insert(0, ManualScreenshotRecord(
          bytes: testScreenshot!,
          createdAt: DateTime.now(),
          decision: decision,
        ));
        if (manualScreenshotHistory.length > 20) {
          manualScreenshotHistory.removeLast();
        }
      }

      simulatedAction = _resolveAction(decision);
      status = 'Future collapsed: ${decision.verdict.label}';
      showAnalysisLoader = false;
      notifyListeners();

      if (settings.speakDecisions) {
        await _voice.speak(
          _voiceMessage(decision),
          rate: settings.voiceRate,
        );
      }

      final record = DecisionRecord(
        offer: offer,
        decision: decision,
        createdAt: DateTime.now(),
        action: simulatedAction,
      );
      await _store.appendRecord(record);
      history = await _store.loadHistory();

      if (settings.autoNavigate && settings.monitorEnabled &&
          decision.verdict.isTake &&
          decision.weatherGate == WeatherGate.go &&
          decision.confidence >= .75 &&
          decision.score >= settings.autoTakeThreshold &&
          offer.pay > 0 && offer.displayedMiles > 0 &&
          !offer.merchant.contains('Waiting')) {
        await _navigation.navigate(offer);
      }
    } catch (e) {
      lastError = e;
      status = 'Analysis failed';
    } finally {
      busy = false;
      showAnalysisLoader = false;
      notifyListeners();
    }
  }

  String _resolveAction(RouteDecision value) {
    switch (settings.autoActionMode) {
      case AutoActionMode.off:
        return 'NONE';
      case AutoActionMode.voiceConfirm:
        return value.verdict.isTake ? 'VOICE_CONFIRM_TAKE' : 'VOICE_CONFIRM_SKIP';
      case AutoActionMode.simulatedAuto:
        if (value.weatherGate == WeatherGate.noGo) return 'SIMULATED_DECLINE';
        if (value.score >= settings.autoTakeThreshold &&
            value.verdict.isTake) {
          return 'SIMULATED_ACCEPT';
        }
        if (value.score <= settings.autoSkipThreshold ||
            value.verdict == OfferVerdict.hardSkip) {
          return 'SIMULATED_DECLINE';
        }
        return 'SIMULATED_HOLD';
    }
  }

  String _voiceMessage(RouteDecision value) {
    final weatherPhrase = switch (value.weatherGate) {
      WeatherGate.go => 'Weather go.',
      WeatherGate.caution => 'Weather caution.',
      WeatherGate.noGo => 'Weather no go.',
      WeatherGate.unavailable => 'Weather unknown.',
    };
    return '${value.spokenSummary} $weatherPhrase';
  }

  Future<void> speakAgain() async {
    await _voice.speak(_voiceMessage(decision), rate: settings.voiceRate);
  }

  Future<void> navigateNow() => _navigation.navigate(offer);

  void recordUserAction(String action) {
    if (offer.merchant.contains('Waiting')) return;
    simulatedAction = action;
    status = action == 'USER_TAKE' ? 'Offer marked TAKE' : 'Offer marked SKIP';
    notifyListeners();
  }

  Future<void> openAccessibilitySettings() =>
      _monitor.openAccessibilitySettings();

  Future<void> refreshCaptures() async {
    captures = await _monitor.listCaptures();
    nativeStatus = await _monitor.runtimeStatus();
    notifyListeners();
  }

  Future<SecureCaptureDetail?> loadCapture(int id) =>
      _monitor.loadCapture(id);

  Future<void> clearSecureCaptures() async {
    await _monitor.clearCaptures();
    captures = const [];
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _store.clearHistory();
    history = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _monitorSub?.cancel();
    _voice.stop();
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// APP SHELL
// -----------------------------------------------------------------------------

class RouteEngineApp extends StatefulWidget {
  const RouteEngineApp({super.key});

  @override
  State<RouteEngineApp> createState() => _RouteEngineAppState();
}

class _RouteEngineAppState extends State<RouteEngineApp> {
  late final RouteEngineController controller;

  @override
  void initState() {
    super.initState();
    controller = RouteEngineController();
    // Let Flutter present its first frame before touching plugins/shared
    // preferences. This keeps startup work off the critical first-frame path
    // on Linux, where a plugin handshake can otherwise look like a black UI.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(controller.initialize());
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Naza Route Engine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => RouteEngineHome(controller: controller),
      ),
    );
  }
}

class RouteEngineHome extends StatefulWidget {
  const RouteEngineHome({super.key, required this.controller});

  final RouteEngineController controller;

  @override
  State<RouteEngineHome> createState() => _RouteEngineHomeState();
}

class _RouteEngineHomeState extends State<RouteEngineHome> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final pages = [
      DashboardPage(controller: controller),
      OfferLabPage(controller: controller),
      WeatherPage(controller: controller),
      HistoryPage(controller: controller),
      SettingsPage(controller: controller),
    ];

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: QuantumBackground()),
          SafeArea(
            child: IndexedStack(index: index, children: pages),
          ),
          if (controller.showAnalysisLoader)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: .18),
                  child: const Center(child: QuantumLoader()),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radar_rounded),
            label: 'Foresight',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_rounded),
            label: 'Offer Lab',
          ),
          NavigationDestination(
            icon: Icon(Icons.thunderstorm_rounded),
            label: 'Weather',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// DASHBOARD
// -----------------------------------------------------------------------------

Future<void> _addDashboardScreenshot(
  BuildContext context,
  RouteEngineController controller,
) async {
  try {
    const images = XTypeGroup(label: 'Images', extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'bmp']);
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[images]);
    if (file == null) return;
    controller.setTestScreenshot(await _readValidatedImage(file), file.name);
    await controller.analyzeCurrentOffer();
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Screenshot analysis failed: $error')));
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});

  final RouteEngineController controller;

  @override
  Widget build(BuildContext context) {
    final o = controller.offer;
    final d = controller.decision;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NAZA ROUTE ENGINE',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 2.6,
                            color: AppTheme.cyan,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Delivery Foresight',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusOrb(
                    active: controller.settings.monitorEnabled,
                    online: controller.settings.apiKey.trim().isNotEmpty,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _StatusStrip(controller: controller),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _addDashboardScreenshot(context, controller), icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Add screenshot'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: controller.openAccessibilitySettings, icon: const Icon(Icons.accessibility_new_rounded), label: const Text('Enable capture service'))),
                ],
              ),
              const SizedBox(height: 14),
              CollapseCard(decision: d),
              const SizedBox(height: 14),
              WeatherGateCard(
                snapshot: controller.weather,
                decision: d,
                fahrenheit: controller.settings.useFahrenheit,
              ),
              const SizedBox(height: 14),
              OfferHeroCard(offer: o),
              const SizedBox(height: 14),
              SizedBox(
                height: 136,
                child: QuantumRibbon(
                  score: controller.chromaticWaveScore,
                  uncertainty: controller.chromaticUncertainty,
                  weatherRisk: 1 - d.weatherScore,
                ),
              ),
              if (controller.shouldSuggestBreak)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('BREAK WAVE: recent order confidence is trending down. Consider a short break and reassess.', style: TextStyle(color: AppTheme.amber, fontWeight: FontWeight.w800)),
                ),
              const SizedBox(height: 14),
              _ActionGrid(controller: controller),
              if (controller.lastError != null) ...[
                const SizedBox(height: 14),
                ErrorCard(error: controller.lastError!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.controller});

  final RouteEngineController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          Icon(
            controller.busy ? Icons.blur_on_rounded : Icons.sensors_rounded,
            color: controller.busy ? AppTheme.violet : AppTheme.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              controller.status,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            controller.simulatedAction,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.controller});

  final RouteEngineController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: FilledButton.icon(onPressed: () => controller.recordUserAction('USER_TAKE'), icon: const Icon(Icons.check_circle_outline), label: const Text('TAKE'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () => controller.recordUserAction('USER_SKIP'), icon: const Icon(Icons.block_outlined), label: const Text('SKIP'))),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: controller.busy ? null : controller.analyzeCurrentOffer,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Text(
              'OBSERVE FUTURES WITH LUNA',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: AppTheme.cyan,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.speakAgain,
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('Speak'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.navigateNow,
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('Navigate'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class OfferHeroCard extends StatelessWidget {
  const OfferHeroCard({super.key, required this.offer});

  final DeliveryOffer offer;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '\$${offer.pay.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 44,
                    height: .95,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
              ),
              MetricPill(
                icon: Icons.route_rounded,
                label: '${offer.displayedMiles.toStringAsFixed(1)} mi',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            offer.merchant,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${offer.orderCount} orders • ${offer.dropoffCount} drop-offs • '
            '\$${offer.dollarsPerMile.toStringAsFixed(2)}/mi',
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class CollapseCard extends StatelessWidget {
  const CollapseCard({super.key, required this.decision});

  final RouteDecision decision;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: decision.verdict.color.withValues(alpha: .14),
                  border: Border.all(
                    color: decision.verdict.color.withValues(alpha: .5),
                  ),
                ),
                child: Icon(
                  decision.verdict.icon,
                  color: decision.verdict.color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      decision.verdict.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: decision.verdict.color,
                        letterSpacing: 1.3,
                      ),
                    ),
                    Text(
                      decision.headline,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(decision.confidence * 100).round()}%',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            decision.predictedFuture,
            style: const TextStyle(
              color: AppTheme.muted,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (decision.pickupEstimate != 'Not visible' ||
              decision.dropoffEstimate != 'Not visible') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cyan.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cyan.withValues(alpha: .18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VISUAL LOCATION ESTIMATE', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text('Pickup: ${decision.pickupEstimate}'),
                  Text('Drop-off: ${decision.dropoffEstimate}'),
                  Text('${decision.propertyType} • ${(decision.locationConfidence * 100).round()}% visual confidence', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                  const SizedBox(height: 5),
                  const Text('Estimate only—verify before navigating.', style: TextStyle(color: AppTheme.amber, fontSize: 11)),
                ],
              ),
            ),
          ],
          if (decision.totalMilesEstimate > 0) ...[
            const SizedBox(height: 14),
            GlassPanel(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL ROUTE ESTIMATE', style: TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text('${decision.totalMilesEstimate.toStringAsFixed(1)} total mi • ${decision.highwayPercent.round()}% highway • ${decision.routeDifficulty}'),
                  const SizedBox(height: 4),
                  Text(decision.routeSummary, style: const TextStyle(color: AppTheme.muted, height: 1.35)),
                  const SizedBox(height: 4),
                  const Text('AI route estimate—verify with navigation before riding.', style: TextStyle(color: AppTheme.amber, fontSize: 11)),
                ],
              ),
            ),
          ],
          if (decision.reasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: decision.reasons
                  .map((r) => InfoChip(label: r))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MiniMetric(
                  label: 'Expected time',
                  value: decision.expectedMinutes <= 0
                      ? '—'
                      : '${decision.expectedMinutes.round()}m',
                ),
              ),
              Expanded(
                child: MiniMetric(
                  label: 'Projected hourly',
                  value: decision.expectedNetHourly <= 0
                      ? '—'
                      : '\$${decision.expectedNetHourly.toStringAsFixed(0)}/h',
                ),
              ),
              Expanded(
                child: MiniMetric(
                  label: 'Primary risk',
                  value: decision.primaryRisk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WeatherGateCard extends StatelessWidget {
  const WeatherGateCard({
    super.key,
    required this.snapshot,
    required this.decision,
    required this.fahrenheit,
  });

  final WeatherSnapshot? snapshot;
  final RouteDecision decision;
  final bool fahrenheit;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.two_wheeler_rounded, color: decision.weatherGate.color),
              const SizedBox(width: 10),
              Text(
                decision.weatherGate.label,
                style: TextStyle(
                  color: decision.weatherGate.color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const Spacer(),
              const Text(
                'MOTORCYCLE GATE',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            decision.weatherReason,
            style: const TextStyle(
              color: AppTheme.muted,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (snapshot != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                MetricPill(
                  icon: Icons.air_rounded,
                  label: '${snapshot!.windGustKph.toStringAsFixed(0)} gust',
                ),
                MetricPill(
                  icon: Icons.water_drop_rounded,
                  label:
                      '${snapshot!.precipitationMm.toStringAsFixed(1)} mm',
                ),
                MetricPill(
                  icon: Icons.visibility_rounded,
                  label: '${snapshot!.visibilityKm.toStringAsFixed(1)} km',
                ),
                MetricPill(
                  icon: Icons.thermostat_rounded,
                  label: fahrenheit
                      ? '${(snapshot!.temperatureC * 9 / 5 + 32).round()}°F'
                      : '${snapshot!.temperatureC.round()}°C',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// OFFER LAB
// -----------------------------------------------------------------------------

class OfferLabPage extends StatefulWidget {
  const OfferLabPage({super.key, required this.controller});

  final RouteEngineController controller;

  @override
  State<OfferLabPage> createState() => _OfferLabPageState();
}

class _OfferLabPageState extends State<OfferLabPage> {
  late final TextEditingController pay;
  late final TextEditingController miles;
  late final TextEditingController merchant;
  late final TextEditingController orders;

  @override
  void initState() {
    super.initState();
    final o = widget.controller.offer;
    pay = TextEditingController(text: o.pay.toStringAsFixed(2));
    miles = TextEditingController(text: o.displayedMiles.toStringAsFixed(1));
    merchant = TextEditingController(text: o.merchant);
    orders = TextEditingController(text: '${o.orderCount}');
  }

  @override
  void dispose() {
    pay.dispose();
    miles.dispose();
    merchant.dispose();
    orders.dispose();
    super.dispose();
  }

  void applyManual() {
    final current = widget.controller.offer;
    widget.controller.offer = DeliveryOffer(
      id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
      pay: double.tryParse(pay.text) ?? current.pay,
      displayedMiles: double.tryParse(miles.text) ?? current.displayedMiles,
      merchant: merchant.text.trim().isEmpty ? current.merchant : merchant.text.trim(),
      orderCount: int.tryParse(orders.text) ?? current.orderCount,
      dropoffCount: int.tryParse(orders.text) ?? current.dropoffCount,
    );
    widget.controller.decision = RouteDecision.awaiting();
    widget.controller.status = 'Manual offer armed';
    widget.controller.notifyListeners();
  }

  Future<void> addScreenshot() async {
    try {
      const images = XTypeGroup(
        label: 'Images',
        extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'bmp'],
      );
      final file = await openFile(acceptedTypeGroups: <XTypeGroup>[images]);
      if (!mounted || file == null) return;
      widget.controller.setTestScreenshot(
        await _readValidatedImage(file),
        file.name,
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open image chooser: $error')),
      );
    }
  }

  Future<void> analyzeScreenshot() async {
    await widget.controller.analyzeCurrentOffer();
    if (!mounted) return;
    final error = widget.controller.lastError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error == null
            ? 'Screenshot analyzed: ${widget.controller.decision.verdict.label}'
            : 'Analysis failed: $error'),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
      children: [
        const PageTitle(
          eyebrow: 'TEST LAB',
          title: 'Offer Laboratory',
          subtitle:
              'Craft a manual offer for UI testing, or let the Android monitor populate real DoorDash captures into the encrypted vault.',
        ),
        const SizedBox(height: 18),
        GlassPanel(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MANUAL TEST INPUT',
                style: TextStyle(
                  color: AppTheme.cyan,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'No demo order is bundled. Use the fields below for manual UI testing, '
                'or enable the Android accessibility monitor to populate real DoorDash '
                'offers and screenshots into the encrypted capture vault.',
                style: TextStyle(color: AppTheme.muted, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.screenshot_rounded, color: AppTheme.cyan),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('SCREENSHOT TEST INPUT', style: TextStyle(fontWeight: FontWeight.w900))),
                  OutlinedButton.icon(
                    onPressed: addScreenshot,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add screenshot'),
                  ),
                ],
              ),
              if (widget.controller.testScreenshot != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    widget.controller.testScreenshot!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    cacheWidth: 1200,
                    filterQuality: FilterQuality.low,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(widget.controller.testScreenshotName ?? 'Loaded image', style: const TextStyle(color: AppTheme.muted), overflow: TextOverflow.ellipsis)),
                    TextButton(onPressed: widget.controller.clearTestScreenshot, child: const Text('Remove')),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: widget.controller.busy
                      ? null
                      : analyzeScreenshot,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Analyze screenshot with AI'),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Import a DoorDash screenshot on Linux to preview it while testing the offer flow.', style: TextStyle(color: AppTheme.muted)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassPanel(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pay,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Offer pay',
                        prefixText: r'$ ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: miles,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Displayed miles',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: merchant,
                decoration: const InputDecoration(labelText: 'Merchant'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: orders,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Order count'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: applyManual,
                      child: const Text('ARM MANUAL OFFER'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        applyManual();
                        await widget.controller.analyzeCurrentOffer();
                      },
                      child: const Text('OBSERVE WITH LUNA'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CollapseCard(decision: widget.controller.decision),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// WEATHER PAGE
// -----------------------------------------------------------------------------

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key, required this.controller});

  final RouteEngineController controller;

  @override
  Widget build(BuildContext context) {
    final w = controller.weather;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
      children: [
        const PageTitle(
          eyebrow: 'LIVE WEATHER',
          title: 'Radar Sentinel',
          subtitle:
              'Open-Meteo conditions and a live RainViewer radar tile are sent with the offer to GPT-5.6-Luna for a motorcycle-specific weather gate.',
        ),
        if (controller.weatherLocation != null) ...[
          const SizedBox(height: 8),
          Text(
            'Forecast for ${controller.weatherLocation}',
            style: const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w800),
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(value: false, label: Text('°C')),
              ButtonSegment<bool>(value: true, label: Text('°F')),
            ],
            selected: <bool>{controller.settings.useFahrenheit},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                controller.updateSettings(
                  controller.settings.copyWith(useFahrenheit: selection.first),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 18),
        WeatherGateCard(snapshot: w, decision: controller.decision, fahrenheit: controller.settings.useFahrenheit),
        const SizedBox(height: 14),
        if (controller.radarFrame != null)
          RadarPreview(frame: controller.radarFrame!)
        else
          const GlassPanel(
            child: SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  'No radar frame yet.\nRun an offer analysis to scan live radar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted),
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
        if (w != null)
          GlassPanel(
            child: Column(
              children: [
                WeatherRow(
                  icon: Icons.thermostat_rounded,
                  name: 'Temperature',
                  value:
                      '${_temp(w.temperatureC, controller.settings.useFahrenheit)} / feels ${_temp(w.apparentTemperatureC, controller.settings.useFahrenheit)}',
                ),
                WeatherRow(
                  icon: Icons.air_rounded,
                  name: 'Wind',
                  value:
                      '${_speed(w.windSpeedKph, controller.settings.useFahrenheit)} • gust ${_speed(w.windGustKph, controller.settings.useFahrenheit)}',
                ),
                WeatherRow(
                  icon: Icons.water_drop_rounded,
                  name: 'Precipitation',
                  value: '${w.precipitationMm.toStringAsFixed(2)} mm',
                ),
                WeatherRow(
                  icon: Icons.visibility_rounded,
                  name: 'Visibility',
                  value: '${w.visibilityKm.toStringAsFixed(1)} km',
                ),
                WeatherRow(
                  icon: Icons.cloud_rounded,
                  name: 'Cloud cover',
                  value: '${w.cloudCover.toStringAsFixed(0)}%',
                ),
              ],
            ),
          ),
        if (controller.forecast.isNotEmpty) ...[
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('7-DAY FORECAST', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                ...controller.forecast.map((day) => WeatherRow(
                  icon: Icons.wb_sunny_outlined,
                  name: '${_weekday(day.date.weekday)} ${day.date.month}/${day.date.day}',
                  value: '${_temp(day.lowC, controller.settings.useFahrenheit)} / ${_temp(day.highC, controller.settings.useFahrenheit)} • ${day.precipitationMm.toStringAsFixed(1)} mm • ${day.precipitationProbability.round()}% rain • ${_speed(day.maxWindKph, controller.settings.useFahrenheit)}',
                )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _weekday(int day) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];
  String _temp(double c, bool fahrenheit) => fahrenheit
      ? '${(c * 9 / 5 + 32).toStringAsFixed(0)}°F'
      : '${c.toStringAsFixed(0)}°C';
  String _speed(double kph, bool fahrenheit) => fahrenheit
      ? '${(kph * 0.621371).toStringAsFixed(0)} MPH'
      : '${kph.toStringAsFixed(0)} km/h';
}

class RadarPreview extends StatelessWidget {
  const RadarPreview({super.key, required this.frame});

  final RadarFrame frame;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            SizedBox(
              height: 260,
              width: double.infinity,
              child: ColoredBox(
                color: const Color(0xFF182538),
                child: Image.memory(
                  frame.bytes,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stack) => Center(
                    child: Text(
                      'Radar image unavailable\n$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.amber),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: .76),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 14,
              right: 16,
              child: Row(
                children: [
                  const Icon(Icons.radar_rounded, color: AppTheme.cyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'RainViewer frame • ${frame.timestamp.toLocal()}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HISTORY
// -----------------------------------------------------------------------------

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.controller});

  final RouteEngineController controller;

  Future<void> _openCapture(
    BuildContext context,
    SecureCaptureSummary summary,
  ) async {
    final detail = await controller.loadCapture(summary.id);
    if (!context.mounted || detail == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bg1,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .45,
        maxChildSize: .96,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_rounded, color: AppTheme.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Encrypted capture #${detail.id}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    detail.kind,
                    style: const TextStyle(
                      color: AppTheme.cyan,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (detail.screenshot != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.memory(
                    detail.screenshot!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                )
              else
                const GlassPanel(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 26),
                    child: Center(
                      child: Text(
                        'This state change did not include a screenshot.',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      detail.createdAt.toLocal().toString(),
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      const JsonEncoder.withIndent('  ').convert(detail.payload),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (detail.decision != null) ...[
                const SizedBox(height: 14),
                GlassPanel(
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(detail.decision),
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Color _verdictColor(String verdict) {
    final v = verdict.toUpperCase();
    if (v.contains('TAKE') || v.contains('ACCEPT')) return AppTheme.green;
    if (v.contains('SKIP') || v.contains('DECLINE') || v.contains('NO_GO')) {
      return AppTheme.red;
    }
    if (v.contains('CAUTION') || v.contains('BORDERLINE')) return AppTheme.amber;
    return AppTheme.cyan;
  }

  @override
  Widget build(BuildContext context) {
    final items = controller.captures;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: PageTitle(
                eyebrow: 'AES-GCM VAULT',
                title: 'Real Capture Vault',
                subtitle:
                    'DoorDash offer and delivery-state screenshots are captured only '
                    'after a qualifying accessibility state change, encrypted with an '
                    'Android Keystore AES-GCM key, and stored in the app-private SQLite vault.',
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: controller.refreshCaptures,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Clear vault',
              onPressed: items.isEmpty
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Clear encrypted capture vault?'),
                              content: const Text(
                                'This deletes all locally stored DoorDash capture '
                                'records, screenshots, and Luna decisions.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete all'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (confirmed) await controller.clearSecureCaptures();
                    },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: Row(
            children: [
              const Icon(Icons.security_rounded, color: AppTheme.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  controller.nativeStatus['accessibilityEnabled'] == true
                      ? 'Android capture service enabled'
                      : 'Enable the Route Engine accessibility service to collect live DoorDash states.',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${items.length} records',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (controller.manualScreenshotHistory.isNotEmpty) ...[
          const Text('MANUAL SCREENSHOT ANALYSES', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          const SizedBox(height: 10),
          ...controller.manualScreenshotHistory.map((record) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassPanel(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(record.bytes, width: 72, height: 72, fit: BoxFit.cover, cacheWidth: 240),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${record.decision.verdict.label}\n${record.createdAt.toLocal()}\n${record.decision.headline}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                ],
              ),
            ),
          )),
          const SizedBox(height: 8),
        ],
        if (items.isEmpty)
          GlassPanel(
            child: Column(
              children: [
                const SizedBox(height: 18),
                const Icon(
                  Icons.screenshot_monitor_rounded,
                  size: 48,
                  color: AppTheme.cyan,
                ),
                const SizedBox(height: 14),
                const Text(
                  'No real DoorDash captures yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No demo screenshots are bundled. Open DoorDash after enabling '
                  'the accessibility service; Route Engine will record qualifying '
                  'offer/order state changes only.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: controller.openAccessibilitySettings,
                  icon: const Icon(Icons.accessibility_new_rounded),
                  label: const Text('Enable capture service'),
                ),
                const SizedBox(height: 18),
              ],
            ),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _openCapture(context, item),
                child: GlassPanel(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _verdictColor(item.verdict)
                              .withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _verdictColor(item.verdict)
                                .withValues(alpha: .45),
                          ),
                        ),
                        child: Icon(
                          item.hasScreenshot
                              ? Icons.screenshot_rounded
                              : Icons.text_snippet_rounded,
                          color: _verdictColor(item.verdict),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.kind} • ${item.verdict} • ${item.weather}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SETTINGS
// -----------------------------------------------------------------------------

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final RouteEngineController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController model;
  late final TextEditingController apiKey;
  late final TextEditingController zip;

  @override
  void initState() {
    super.initState();
    model = TextEditingController(text: widget.controller.settings.aiModel);
    apiKey = TextEditingController(text: widget.controller.settings.apiKey);
    zip = TextEditingController(text: widget.controller.settings.zipCode);
  }

  @override
  void dispose() {
    model.dispose();
    apiKey.dispose();
    zip.dispose();
    super.dispose();
  }

  Future<void> save(AppSettings settings) async {
    await widget.controller.updateSettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    var s = widget.controller.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
      children: [
        const PageTitle(
          eyebrow: 'CONTROL PLANE',
          title: 'Settings',
          subtitle:
            'Tune economic rules, provider access, motorcycle weather limits, TTS, navigation, and monitoring.',
        ),
        const SizedBox(height: 18),
        SettingsSection(
          title: 'Direct AI provider',
          icon: Icons.hub_rounded,
          children: [
            TextField(
              controller: zip,
              keyboardType: TextInputType.streetAddress,
              decoration: const InputDecoration(
                labelText: 'ZIP/postal code (optional weather location)',
                hintText: 'Use GPS when blank',
              ),
            ),
            SwitchListTile.adaptive(
              value: s.useFahrenheit,
              onChanged: (value) async {
                await save(s.copyWith(useFahrenheit: value));
              },
              title: const Text('Show Fahrenheit'),
              subtitle: const Text('AI calculations remain normalized in Celsius.'),
            ),
            DropdownButtonFormField<String>(
              value: s.vehicleType,
              decoration: const InputDecoration(labelText: 'Vehicle profile'),
              items: const [
                DropdownMenuItem(value: 'motorcycle', child: Text('Motorcycle (default)')),
                DropdownMenuItem(value: 'car', child: Text('Car')),
              ],
              onChanged: (value) async {
                if (value != null) await save(s.copyWith(vehicleType: value));
              },
            ),
            TextField(
              controller: apiKey,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Provider API key (secure storage)',
              ),
            ),
            DropdownButtonFormField<String>(
              value: const ['openai', 'meta_muse', 'grok'].contains(s.aiProvider)
                  ? s.aiProvider
                  : 'openai',
              decoration: const InputDecoration(labelText: 'Provider'),
              items: const [
                DropdownMenuItem(value: 'openai', child: Text('OpenAI Responses API')),
                DropdownMenuItem(value: 'meta_muse', child: Text('Meta Muse')),
                DropdownMenuItem(value: 'grok', child: Text('xAI Grok 4.5')),
              ],
              onChanged: (v) async {
                if (v != null) await save(s.copyWith(aiProvider: v));
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: model,
              decoration: const InputDecoration(
                labelText: 'Model ID',
                hintText: 'gpt-5.6-luna / provider model ID',
              ),
              onSubmitted: (v) async {
                await save(s.copyWith(aiModel: v.trim()));
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  await save(s.copyWith(
                    apiKey: apiKey.text.trim(),
                    zipCode: zip.text.trim(),
                  ));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Provider settings saved securely.')),
                  );
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save provider settings'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Provider keys are stored using platform secure storage and calls '
              'are made directly from this app.',
              style: TextStyle(
                color: AppTheme.muted,
                height: 1.4,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          title: 'Offer rules',
          icon: Icons.rule_rounded,
          children: [
            NumberSlider(
              label: 'Minimum payout',
              value: s.minimumPayout,
              min: 2,
              max: 30,
              suffix: r'$',
              onChanged: (v) {
                s = s.copyWith(minimumPayout: v);
                save(s);
              },
            ),
            NumberSlider(
              label: 'Minimum dollars / mile',
              value: s.minimumDollarsPerMile,
              min: .5,
              max: 5,
              suffix: r'$/mi',
              onChanged: (v) {
                s = s.copyWith(minimumDollarsPerMile: v);
                save(s);
              },
            ),
            NumberSlider(
              label: 'Target hourly',
              value: s.targetHourly,
              min: 10,
              max: 60,
              suffix: r'$/h',
              onChanged: (v) {
                s = s.copyWith(targetHourly: v);
                save(s);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          title: 'Motorcycle weather gate',
          icon: Icons.two_wheeler_rounded,
          children: [
            NumberSlider(
              label: 'Maximum wind gust',
              value: s.maxWindGustKph,
              min: 15,
              max: 100,
              suffix: s.useFahrenheit ? 'km/h base' : 'km/h',
              onChanged: (v) {
                s = s.copyWith(maxWindGustKph: v);
                save(s);
              },
            ),
            NumberSlider(
              label: 'Maximum precipitation',
              value: s.maxPrecipitationMm,
              min: 0,
              max: 15,
              suffix: 'mm',
              onChanged: (v) {
                s = s.copyWith(maxPrecipitationMm: v);
                save(s);
              },
            ),
            NumberSlider(
              label: 'Minimum visibility',
              value: s.minVisibilityKm,
              min: .5,
              max: 20,
              suffix: 'km',
              onChanged: (v) {
                s = s.copyWith(minVisibilityKm: v);
                save(s);
              },
            ),
            NumberSlider(
              label: 'Maximum radar severity',
              value: s.maxRadarSeverity,
              min: 0,
              max: 1,
              suffix: '',
              onChanged: (v) {
                s = s.copyWith(maxRadarSeverity: v);
                save(s);
              },
            ),
            SwitchListTile.adaptive(
              value: s.radarEnabled,
              onChanged: (v) {
                s = s.copyWith(radarEnabled: v);
                save(s);
              },
              title: const Text('Live radar scanner'),
              subtitle:
                  const Text('Send latest RainViewer radar frame to Luna.'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          title: 'Hands-free behavior',
          icon: Icons.record_voice_over_rounded,
          children: [
            SwitchListTile.adaptive(
              value: s.speakDecisions,
              onChanged: (v) {
                s = s.copyWith(speakDecisions: v);
                save(s);
              },
              title: const Text('Speak every decision'),
            ),
            SwitchListTile.adaptive(
              value: s.autoNavigate,
              onChanged: !s.monitorEnabled ? null : (v) {
                s = s.copyWith(autoNavigate: v);
                save(s);
              },
              title: const Text('Launch Google Maps after TAKE'),
              subtitle: const Text('Only active while DoorDash monitoring is enabled.'),
            ),
            SwitchListTile.adaptive(
              value: s.monitorEnabled,
              onChanged: (v) {
                s = s.copyWith(monitorEnabled: v);
                save(s);
              },
              title: const Text('DoorDash event monitoring'),
              subtitle: const Text(
                'Requires the Android accessibility bridge.',
              ),
            ),
            SwitchListTile.adaptive(
              value: s.overlayEnabled,
              onChanged: (v) {
                s = s.copyWith(overlayEnabled: v);
                save(s);
              },
              title: const Text('DoorDash heads-up overlay'),
              subtitle: const Text(
                'Shows only on DoorDash: chromatic verdict dot + short weather state.',
              ),
            ),
            NumberSlider(
              label: 'TTS rate',
              value: s.voiceRate,
              min: .25,
              max: .75,
              suffix: '',
              onChanged: (v) {
                s = s.copyWith(voiceRate: v);
                save(s);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AutoActionMode>(
              initialValue: s.autoActionMode,
              decoration: const InputDecoration(
                labelText: 'Acceptance / decline mode',
              ),
              items: AutoActionMode.values
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(v.label),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                s = s.copyWith(autoActionMode: v);
                save(s);
              },
            ),
            const SizedBox(height: 10),
            const Text(
              'Simulated auto exercises the entire decision/TTS/navigation '
              'state machine without secretly pressing buttons in DoorDash.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.controller.openAccessibilitySettings,
              icon: const Icon(Icons.accessibility_new_rounded),
              label: const Text('Open Android accessibility settings'),
            ),
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SHARED UI
// -----------------------------------------------------------------------------

class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: AppTheme.cyan,
            letterSpacing: 1.7,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.muted,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.panel.withValues(alpha: .91),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class MetricPill extends StatelessWidget {
  const MetricPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.cyan),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: .045),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class MiniMetric extends StatelessWidget {
  const MiniMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class WeatherRow extends StatelessWidget {
  const WeatherRow({
    super.key,
    required this.icon,
    required this.name,
    required this.value,
  });

  final IconData icon;
  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error.toString(),
              style: const TextStyle(
                color: AppTheme.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.cyan),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children.map(
            (child) => Material(
              type: MaterialType.transparency,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class NumberSlider extends StatelessWidget {
  const NumberSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${value.toStringAsFixed(value < 5 ? 2 : 0)} $suffix',
              style: const TextStyle(
                color: AppTheme.cyan,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class StatusOrb extends StatelessWidget {
  const StatusOrb({
    super.key,
    required this.active,
    required this.online,
  });

  final bool active;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = !online
        ? AppTheme.amber
        : active
            ? AppTheme.green
            : AppTheme.muted;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: .55),
            color.withValues(alpha: .08),
            Colors.transparent,
          ],
        ),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Icon(
        online ? Icons.online_prediction_rounded : Icons.cloud_off_rounded,
        color: color,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// QUANTUM VISUALIZATION
// -----------------------------------------------------------------------------

class QuantumBackground extends StatelessWidget {
  const QuantumBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _QuantumBackgroundPainter(),
    );
  }
}

class _QuantumBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x3329D7FF),
          Color(0x111A2B4B),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .82, size.height * .12),
          radius: size.width * .9,
        ),
      );
    canvas.drawRect(Offset.zero & size, paint);

    final p = Paint()
      ..color = Colors.white.withValues(alpha: .025)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class QuantumRibbon extends StatefulWidget {
  const QuantumRibbon({
    super.key,
    required this.score,
    required this.uncertainty,
    required this.weatherRisk,
  });

  final double score;
  final double uncertainty;
  final double weatherRisk;

  @override
  State<QuantumRibbon> createState() => _QuantumRibbonState();
}

class _QuantumRibbonState extends State<QuantumRibbon>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;

  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AnimatedBuilder(
          animation: animation,
          builder: (_, __) => CustomPaint(
            painter: _RibbonPainter(
              phase: animation.value,
              score: widget.score,
              uncertainty: widget.uncertainty,
              weatherRisk: widget.weatherRisk,
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter({
    required this.phase,
    required this.score,
    required this.uncertainty,
    required this.weatherRisk,
  });

  final double phase;
  final double score;
  final double uncertainty;
  final double weatherRisk;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.height / 2;
    final risk = ((1 - score) * .7 + weatherRisk * .3).clamp(0.0, 1.0);
    final greenStrength = ((score + (1 - weatherRisk)) / 2).clamp(0.0, 1.0).toDouble();
    final redStrength = ((risk + (1 - score)) / 2).clamp(0.0, 1.0).toDouble();
    final favorable = Color.lerp(const Color(0xFF163B2B), const Color(0xFF66FFB2), greenStrength)!;
    final danger = Color.lerp(const Color(0xFF3B1620), const Color(0xFFFF5A72), redStrength)!;
    final uncertain = Color.lerp(const Color(0xFF19304A), const Color(0xFFFFCF5C), uncertainty)!;

    // Three low-cost ribbons: decision strength, weather exposure, and
    // historical continuity/uncertainty. No blur shaders on Linux.
    final bands = <(double, Color, double)>[
      (0, favorable, 1),
      (1.9, Color.lerp(favorable, danger, weatherRisk)!, 1 - weatherRisk),
      (-1.9, uncertain, uncertainty),
    ];
    for (final (offset, color, amplitude) in bands) {
      final path = Path();
      for (double x = 0; x <= size.width; x += 6) {
        final t = x / size.width;
        final wave = math.sin((t * math.pi * 5) + phase * math.pi * 2 + offset);
        final wave2 = math.sin((t * math.pi * 9) - phase * math.pi * 2 + offset) * uncertainty;
        final y = center + offset * 8 + (wave * 10 + wave2 * 7) * amplitude;
        if (x == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = offset == 0 ? 3.5 : 2.0
        ..color = color.withValues(alpha: offset == 0 ? 1 : .72);
      canvas.drawPath(path, paint);
    }

    final text = TextPainter(
      text: const TextSpan(
        text: 'CHROMATIC FUTURE FIELD',
        style: TextStyle(
          color: Color(0xAAFFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, const Offset(14, 12));
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.score != score ||
      oldDelegate.uncertainty != uncertainty ||
      oldDelegate.weatherRisk != weatherRisk;
}

class QuantumLoader extends StatefulWidget {
  const QuantumLoader({super.key});

  @override
  State<QuantumLoader> createState() => _QuantumLoaderState();
}

class _QuantumLoaderState extends State<QuantumLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController a;

  @override
  void initState() {
    super.initState();
    a = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: a,
      builder: (_, __) => Transform.rotate(
        angle: a.value * math.pi * 2,
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Colors.transparent,
                AppTheme.cyan,
                AppTheme.violet,
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.cyan.withValues(alpha: .2),
                blurRadius: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
