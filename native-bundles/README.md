# LlamaDart native bundles

The scanner-only probabilistic harm filter uses the `b10075` LlamaDart ABI.
Normal builds let LlamaDart resolve the matching pinned release bundle for the
current platform; a global local path is deliberately not configured because
this application also targets Android, iOS, macOS, and Windows.

Linux x86-64/Crostini systems that cannot load the upstream build may compile
the exact pinned source commit with `tool/prepare_linux_llamadart_native.sh`.
The helper stages its output under `third_party/bin/linux-x64/`, where
LlamaDart can discover it when
`LLAMADART_ALLOW_LEGACY_LOCAL_BUNDLES=1` is set for the Flutter command.
Generated shared libraries are excluded from source control.

The helper's binary hashes identify one known cached bundle; they are not
portable hashes for all builds of the pinned commit. Compiler versions, system
libraries, build paths, and CPU features can change native output bytes. A cache
that does not match is rebuilt from the pinned source in a cleared build
directory. Only that fresh build may bypass the cached-byte comparison; it
still must pass the library-name and dependency checks. Existing build trees
are never promoted directly. Host-specific bundles outside the known hash set
will therefore be rebuilt on subsequent invocations.

Run `bash tool/tests/prepare_linux_llamadart_native_security_test.sh` with the
known local bundle installed to check both cache rejection and fresh-build
compatibility. Dependency failures now include the failing library and loader
diagnostic.
