import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_engine/main.dart';

void main() {
  test('RouteEngineApp can be constructed', () {
    const app = RouteEngineApp();
    expect(app, isA<Widget>());
  });
}
