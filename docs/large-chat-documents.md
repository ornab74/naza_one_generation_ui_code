# Large chat documents

Pastes over 6,000 characters are indexed off the UI thread. The current
document is retained exactly in memory, up to 32 Mi UTF-16 code units. Chunks
prefer newline boundaries and never split surrogate pairs. Long lines are
split into bounded spans. No model inference is needed to create the index.

Ask about a distinctive symbol or phrase, `line 40001`, or `chunk 200` to
retrieve source from the middle. Retrieval weights rare query terms and
prioritizes explicit line/chunk addresses. Excerpts include original line
ranges, adjacent chunk links, and six deterministic chromatic navigation
lanes. Colors are metadata, not semantic embeddings or security signals.

Model requests receive a bounded subset, not the full document. Local automatic
reply continuations retrieve additional windows using the output cursor and
retain the existing seam validation and configured pass limit. Writer mode now
uses that continuation setting too. Retrieval does not establish exhaustive
coverage: summarizing or rewriting a whole book still requires successive
section requests. A model cannot accurately claim to have inspected unsupplied
chunks. Remote providers receive the bounded initial excerpts; their existing
response behavior is unchanged.

One document is retained for the current chat session; another large paste
replaces it. It is not a persistent document database. It is released when the
chat widget is disposed or a message is submitted in another thread. Existing
history storage remains separate and must not be treated as a lossless archive
of this index. Reloading requires pasting the document again.

Implementation: `lib/chromatic_document.dart` is a standalone, pure Dart module
called by the chat shell and local continuation path in `lib/main.dart`.
This is an exception to the older single-file layout so ingestion can be
verified without loading native inference libraries.

Verification: `dart tool/chromatic_document_test.dart` checks exact 80,000-line
round trips, middle/end retrieval, line addresses, Unicode and prompt bounds.
The standalone test also exercises background ingestion and follow-up retrieval.
Existing chat widget regressions cover streaming and continuation controls.
An attempted end-to-end large-paste widget test was blocked by unrelated native
audio plugin initialization in the asynchronous test environment; live desktop
paste/inference behavior still needs device testing.
