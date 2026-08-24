import 'package:flutter_test/flutter_test.dart';
import 'package:naza_one/security/boundary_sanitizer.dart';

void main() {
  test('removes invisible controls while preserving readable layout', () {
    final clean = NazaBoundarySanitizer.modelInput(
      'hello\u0000\u202E world\r\nnext\tline',
      maxCharacters: 100,
    );

    expect(clean, 'hello world\nnext\tline');
  });

  test('remote egress redacts common credential forms', () {
    final digitalOceanTokenFixture = <String>[
      'dop',
      'v1',
      List<String>.filled(64, 'a').join(),
    ].join('_');
    final secrets = <String>[
      'sk-proj-abcdefghijklmnopqrstuvwxyz123456',
      'sk-ant-api03-abcdefghijklmnopqrstuvwxyz123456',
      'xai-abcdefghijklmnopqrstuvwxyz123456',
      'AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZ123456789',
      digitalOceanTokenFixture,
      'ghp_abcdefghijklmnopqrstuvwxyz1234567890',
      'github_pat_abcdefghijklmnopqrstuvwxyz1234567890',
      'glpat-abcdefghijklmnopqrstuvwxyz123456',
      'hf_abcdefghijklmnopqrstuvwxyz123456',
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abcdefghijklmnopqrstuvwxyz',
    ];
    final clean = NazaBoundarySanitizer.remoteText(
      'Authorization: Bearer abcdefghijklmnopqrstuvwxyz\n'
      'api_key=sk-abcdefghijklmnopqrstuvwxyz123456\n${secrets.join('\n')}',
      maxCharacters: 2000,
    );

    expect(clean, isNot(contains('abcdefghijklmnopqrstuvwxyz')));
    expect(clean, contains('[REDACTED]'));
    for (final secret in secrets) {
      expect(clean, isNot(contains(secret)));
    }
  });

  test('configured secrets are removed regardless of token prefix', () {
    const configured = 'unfamiliar-provider-secret-123456789';
    final clean = NazaBoundarySanitizer.redactExactSecrets(
      'before $configured after',
      const <String>[configured],
    );

    expect(clean, 'before [REDACTED_CONFIGURED_SECRET] after');
  });

  test('bounded truncation never leaves a dangling high surrogate', () {
    final clean = NazaBoundarySanitizer.databaseText(
      'ab\u{1F680}',
      maxCharacters: 3,
    );

    expect(clean, 'ab');
  });
}
