import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/main.dart';

void main() {
  test('parses a bounded laboratory sample', () {
    final sample = MslResearchSample.parseJsonLine(
      '{"type":"sample","sequence":7,"channels":'
      '[1,2,3,4,5,6,7,8,9,10,11,12],"polarization_deg":45,'
      '"duration_ms":300,"saturated":false,"underexposed":false,'
      '"temperature_c":24.5}',
    );
    expect(sample.channels, hasLength(12));
    expect(sample.toCsvRow(), startsWith('7,1,2,3'));
  });

  test('rejects malformed, saturated-width, and oversized records', () {
    expect(
      () => MslResearchSample.parseJsonLine(
        '{"type":"sample","sequence":0,"channels":[1],'
        '"polarization_deg":0,"duration_ms":100,'
        '"saturated":false,"underexposed":false,"temperature_c":25}',
      ),
      throwsFormatException,
    );
    expect(
      () => MslResearchSample.parseJsonLine('x' * 16385),
      throwsFormatException,
    );
  });
}
