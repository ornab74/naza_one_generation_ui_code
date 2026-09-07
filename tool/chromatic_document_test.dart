import 'dart:io';
import 'package:naza_one/chromatic_document.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> main() async {
  final source = List.generate(
    80000,
    (i) => i == 40000
        ? 'void rareMiddleSymbol() { return; }\n'
        : 'line ${i + 1}: ordinary book or script content.\n',
  ).join();
  final watch = Stopwatch()..start();
  final doc = ChromaticDocument.ingest(source);
  final asyncDoc = await ChromaticDocument.ingestAsync(source);
  check(asyncDoc.source == source, 'isolate transfer preserves source');
  check((await ChromaticDocument.retrieveAsync(asyncDoc, 'rareMiddleSymbol'))
      .contains('rareMiddleSymbol'), 'background follow-up retrieval');
  check(
    doc.chunks.map((c) => source.substring(c.start, c.end)).join() == source,
    '80,000 lines must round-trip exactly',
  );
  check(
    doc.retrieve('rareMiddleSymbol').contains('rareMiddleSymbol'),
    'middle retrieval',
  );
  check(
    doc.retrieve('line 40001').contains('rareMiddleSymbol'),
    'line addressing',
  );
  check(
    doc.retrieve('line 80000').contains('line 80000:'),
    'last line retrieval',
  );
  check(doc.retrieve('ordinary').length <= 2600, 'bounded prompt');
  check(
    doc.retrieve('ordinary', page: 1) != doc.retrieve('ordinary'),
    'coverage cursor',
  );
  final unicode = ChromaticDocument.ingest('🙂界' * 10000);
  check(
    unicode.chunks
            .map((c) => unicode.source.substring(c.start, c.end))
            .join() ==
        unicode.source,
    'Unicode round trip',
  );
  check(unicode.retrieve('overview').length <= 2600, 'Unicode budget');
  check(
    unicode.retrieve('overview').contains('chunk='),
    'Unicode evidence present',
  );
  check(
    ChromaticDocument.ingest('').retrieve('anything').isEmpty,
    'empty document',
  );
  var rejected = false;
  try {
    ChromaticDocument.ingest('x' * (ChromaticDocument.maxCharacters + 1));
  } on FormatException {
    rejected = true;
  }
  check(rejected, 'oversized input must reject explicitly, not truncate');
  stdout.writeln(
    'Passed: lossless 80,000-line ingestion, middle/end retrieval, line lookup, bounded Unicode, coverage paging (${watch.elapsedMilliseconds}ms).',
  );
}
