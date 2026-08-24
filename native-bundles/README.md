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
