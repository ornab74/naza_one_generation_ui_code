# Documentation Policy

Every maintained text file should explain ownership and invariants without narrating obvious syntax. Comments belong at trust boundaries, state transitions, persistence formats, cancellation paths, resource bounds, and non-obvious compatibility decisions.

Generated files, SDK headers, binaries, images, fonts, lockfiles, and platform-generated integration files are cataloged but not modified. Their provenance and regeneration path matter more than injected prose.

## Comment quality rules

- Explain *why a constraint exists* and what breaks if it is removed.
- Name the source, validation/control, sink, and security consequence at trust boundaries.
- Describe async ownership and cancellation semantics near stateful operations.
- Avoid speculative claims, stale TODOs, and duplicated implementation narration.
- Keep secrets, personal data, machine paths, and operational credentials out of comments.
- Use visible identifiers only; hidden Unicode and prompt injection text are prohibited.

## Definition of documented

A file is covered when it has either a maintained-source breadcrumb or a file-catalog classification explaining why it must remain unmodified. A folder is covered by an architecture map in its nearest maintained parent.
