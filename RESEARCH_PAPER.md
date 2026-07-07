# BarkPack: Secure, Compact, and Traceable Bark-Inspired Conversation Audio for Local Flutter Applications

Naza One Project  
Draft research whitepaper, 2026-07-07

## Abstract

Local conversational applications increasingly need speech output that is private,
portable, and responsive on consumer hardware. Full neural text-to-audio systems
can produce expressive speech, but their model size, dependency stack, download
surface, and runtime latency make them difficult to ship inside cross-platform
desktop and mobile applications. This paper describes BarkPack, a secure
voice-pack and native rendering system developed for Naza One. BarkPack converts
source audio-model checkpoints into a small, signed-by-hash release bundle,
verifies every downloaded artifact by SHA-256 at runtime, and maps verified
metadata and tensor families into a dependency-free native renderer exposed to
Flutter through FFI.

The current system is intentionally described as Bark-inspired rather than a full
replacement for Bark. It does not yet execute the complete transformer semantic,
coarse, fine, and neural-codec stack. Instead, it uses verified BarkPack tensor
families, compact semantic and speaker sidecars, deterministic acoustic profiles,
an NLTK-style long-form chunker, and a C++ source/filter rendering scheduler to
generate local WAV previews with traceable prosody events. The design emphasizes
secure delivery, bounded memory use on 8 GB systems, low UI blocking, reproducible
GitHub Actions builds, and diagnostics that make audio failures inspectable rather
than mysterious.

## Keywords

Local AI, Bark, text-to-audio, Flutter FFI, secure model download, SHA-256
verification, speech synthesis, quantized tensors, source/filter synthesis,
GitHub Actions, reproducible builds.

## 1. Introduction

Modern AI applications are shifting from remote-only inference toward hybrid and
local-first systems. This shift is especially visible in chat clients and
assistant-style interfaces where users expect privacy, offline resilience, and
fast interaction. Speech output is a natural extension of these interfaces, but
practical local speech generation remains hard: high-quality neural systems often
require large model files, GPU-specific dependencies, multi-stage Python
pipelines, and non-trivial memory budgets.

Naza One explores a smaller deployment target. The application is written in
Flutter and includes local Gemma LiteRT-LM chat inference, road and food/water
scanner interfaces, and a Bark/Convo voice-lab tab. The Bark/Convo subsystem is
designed around a question:

Can a cross-platform Flutter application ship a secure, compact, inspectable
voice pack that gives useful conversational audio behavior on a single consumer
machine, including 8 GB RAM CPU/GPU laptops?

BarkPack answers this question with a staged engineering architecture:

1. Convert source checkpoint files into a compact release format.
2. Publish release assets and hashes with GitHub Actions.
3. Download only through pinned HTTPS endpoints.
4. Verify all files by SHA-256 before accepting them.
5. Expose status, trust, and self-test diagnostics in the UI.
6. Render speech-like WAV output through a native C++ scheduler with no Python
   runtime dependency.

This paper documents the architecture, current implementation, security model,
evaluation strategy, limitations, and future research path.

## 2. Truth-in-Modeling Statement

BarkPack is currently a compact Bark-inspired runtime, not full neural Bark
parity. The implementation preserves the vocabulary of a Bark-style pipeline:
semantic, coarse, fine, codec, and speaker stages. However, the native renderer
does not yet run the complete autoregressive transformer graph or a learned
neural codec decoder. The current renderer is a deterministic C++ acoustic
scheduler that uses verified pack metadata and tensor fingerprints to shape
prosody, pronunciation, formants, noise, and speaker characteristics.

This distinction matters. The system is already useful for local installation,
verification, UI integration, diagnostics, and speech-like preview generation.
It should not be reported as a drop-in replacement for full Bark inference until
the semantic/coarse/fine/codec graph executes learned tensor operations end to
end.

## 3. Related Work

Bark is Suno's open-source text-to-audio model. Its public repository describes
it as a transformer-based generative audio model capable of speech and other
audio events, with support for multilingual speech and speaker presets. Bark
itself follows the broader neural audio-language-model direction influenced by
AudioLM, VALL-E, and neural audio codecs.

AudioLM frames audio generation as language modeling over discrete audio tokens,
combining representations that capture long-term structure with codec tokens for
high-quality synthesis. VALL-E similarly treats text-to-speech as conditional
language modeling over discrete neural-codec codes. Neural codecs such as
SoundStream and EnCodec showed that learned discrete or quantized audio
representations can support efficient reconstruction and downstream generative
modeling.

BarkPack takes inspiration from that family of systems but targets a different
deployment point. Rather than maximizing neural fidelity in a research notebook,
it prioritizes secure artifact handling, predictable runtime behavior,
cross-platform Flutter integration, and a path toward incremental neural graph
execution.

## 4. Design Goals

The Bark/Convo subsystem was designed around seven goals:

1. Secure model and pack handling. A downloaded or user-supplied model must be
   accepted only if its cryptographic digest matches the pinned value.
2. Cross-platform portability. The app should support Linux, Windows, macOS,
   Android, iOS, and future store builds with consistent release metadata.
3. Low UI blocking. Downloads, verification, profile probing, and rendering
   should avoid freezing the Flutter UI isolate.
4. 8 GB system viability. The default profile should fit commodity laptops
   without assuming large VRAM or server-class memory.
5. Inspectability. Failures such as humming, missing words, or bad pack metadata
   should produce traces and visible status rather than silent degradation.
6. Reproducible release flow. GitHub Actions should build, stage, hash, and
   publish voice-pack assets using deterministic release metadata.
7. Forward compatibility. The format should support a gradual upgrade from
   compact acoustic rendering toward real tensor-backed semantic, coarse, fine,
   and codec execution.

## 5. System Overview

The system has five main layers.

| Layer | Artifact or component | Responsibility |
| --- | --- | --- |
| Source acquisition | Hugging Face repo or direct HTTPS URL | Fetch original model/checkpoint inputs for conversion. |
| Conversion | `tools/convert_bark_to_barkpack.py` | Classify tensors, quantize, shard, and write BarkPack metadata. |
| Release staging | `tools/build_barkpack_release_index.py` and GitHub Actions | Create release index, SHA files, previews, and artifacts. |
| Runtime install | Flutter downloader in `lib/main.dart` | Download, sanitize, verify, and cache model/pack files. |
| Native render | `native/naza_bark_ffi.cpp` | Probe BarkPack metadata and render WAV previews through FFI. |

The chat model and the voice pack are distributed separately. The Gemma
LiteRT-LM chat model is downloaded from a pinned Hugging Face URL and validated
against a pinned SHA-256 digest. BarkPack is downloaded from a pinned GitHub
release-index URL and each pack asset is independently size-checked and
SHA-256-checked. This separation avoids forcing the voice system to redownload
or copy the 2.5 GB chat model and lets the Bark/Convo voice pack iterate more
rapidly.

## 6. Secure Distribution Model

The downloader is intentionally conservative. A model or BarkPack file moves
through these states:

1. Candidate URL or local path is selected.
2. Filename and extension are checked against an allowlist.
3. The file is streamed to a temporary `.part` path.
4. The resulting bytes are hashed with SHA-256.
5. Size and digest are compared to pinned metadata.
6. A mismatch causes rejection and deletion.
7. A match is moved into the verified app-support cache.

The Gemma chat model accepts only `.litertlm` files matching:

```text
ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42
```

Local paths supplied through `NAZA_MODEL_PATH` are not trusted merely because
they are local. They are verified once and then used directly if they match. This
avoids an expensive loop of copying and re-verifying the same multi-gigabyte
model while still rejecting stale, partial, or substituted files.

BarkPack release files follow the same rule. The release index can itself be
pinned by SHA-256 at build time, and every referenced asset carries its own
hash. The runtime treats `install_index_v2.json` as a local convenience cache,
not as a source of trust. If it needs to decide whether a pack is safe, it falls
back to the verified manifest and shard hashes.

## 7. BarkPack Format

BarkPack currently contains:

1. `naza-barkpack-manifest.json`
2. One or more `naza-barkpack-tensors_*.bin` shards
3. `naza-barkpack-index.json`
4. `naza-barkpack-index.sha256`
5. Optional preview WAVs and trace JSON sidecars

The manifest records tensor metadata, quantization, family counts, stage
metadata, profile sidecars, and capabilities. The required render lanes are:

1. `semantic`
2. `coarse`
3. `fine`
4. `codec`
5. `speaker`

The converter attempts to classify real checkpoint tensors into these families.
Some source checkpoints expose generic layer names that do not clearly reveal
semantic or speaker tensors. In that case, the converter writes tiny
deterministic sidecar tensors so the runtime can still track required stages and
speaker/pronunciation metadata without inflating the pack.

Current metadata sidecars include:

| Profile | Purpose |
| --- | --- |
| `speakerProfile` | Pitch bias, tract length, breathiness, brightness, consonant gain, articulation, and pace. |
| `semanticProfile` | Tokenization, coarticulation, stress model, rhythm seed, stress bias, and pause bias. |
| `pronunciationProfile` | English-lite reductions, suffix stress, digraph grouping, duration bias, and clarity controls. |

These sidecars are intentionally small. They are not claimed to be learned
speaker embeddings equivalent to a complete Bark speaker prompt. Instead, they
serve as compact conditioning values that improve the native renderer and give
future tensor-backed stages a stable metadata contract.

## 8. Conversion Pipeline

The conversion pipeline accepts PyTorch, safetensors, or compatible checkpoint
inputs and emits a `naza-barkpack-v1` directory. The default quantization target
is `int8`, and the shard size is configurable so GitHub release assets remain
manageable.

The high-level conversion process is:

```text
for each source tensor:
    classify tensor into semantic/coarse/fine/codec/speaker/other
    quantize or serialize payload
    append tensor payload to shard
    record offset, shape, dtype, scale, and family in manifest

if semantic or speaker families are missing:
    create deterministic compact sidecar tensors
    record sidecar provenance in manifest

write manifest, shards, release index, and SHA metadata
```

The converter also records capability flags. Examples include whether
semantic/speaker sidecars were synthesized, whether pronunciation rules are
present, whether native traces are expected, and which profile quality tier the
pack advertises.

## 9. Native Bark-Inspired Rendering Scheduler

The native renderer is implemented in C++ and exposed to Flutter through FFI.
It currently exports:

1. `naza_bark_probe`
2. `naza_bark_render_wav`
3. `naza_bark_render_wav_v2`

The probe path verifies that a pack is structurally usable and builds a compact
in-memory acoustic profile. The render path transforms text into a sequence of
events and writes WAV output. The `v2` symbol accepts performance flags, target
sample rate, duration budgets, and event budgets so the UI can switch between
Eco, Balanced, and Studio modes without recompiling the app.

The current scheduler uses four conceptual stages:

1. Semantic lattice. Split script text into utterances, tokens, syllable-like
   units, punctuation pauses, acronym expansions, and stress hints.
2. Coarse prosody. Assign timing, pitch baseline, energy, pace, and speaker
   bias across events.
3. Fine acoustic shaping. Generate voiced, unvoiced, fricative, plosive, nasal,
   breath, and formant components.
4. Codec-style WAV pass. Mix, clamp, buffer, and write deterministic WAV output
   plus a trace JSON file.

The renderer favors predictable cost. It uses a sine lookup table, phase
oscillators, bounded event counts, chunk-buffered file output, and a cached pack
profile. Eco mode skips heavier harmonic paths, Balanced mode keeps the normal
harmonic path, and Studio mode enables fuller shaping when the user can trade
speed for quality.

## 10. Long-Form Conversation Handling

One failure mode of text-to-audio systems is long prompt drift. BarkPack handles
long Convo output by separating language generation from audio rendering. The
chat model first produces a script-like response. A sentence-aware chunker then
splits the script into bounded parts while preserving continuation context.
Each part is rendered with shared speaker/profile settings and then
concatenated into the final preview.

This design gives several practical advantages:

1. Long responses do not require one giant native render call.
2. Repeated script chunks can be cached.
3. The renderer can cap event count per part for 8 GB systems.
4. Future neural stages can be inserted per chunk without changing the UI.
5. Trace JSON can identify which sentence or token caused a bad audio segment.

## 11. Flutter Runtime Integration

The Flutter UI exposes BarkPack as a first-class settings and Convo experience
rather than a hidden dependency. The Bark/Convo tab includes:

1. A secure downloader card.
2. Family and tensor count status.
3. Missing-family diagnostics.
4. Pack path visibility.
5. Performance profile selection.
6. Native self-test rendering.
7. Trace and WAV output paths.

The Settings tab also reports chat model status: registered, installed, loaded,
backend, backend preference, phase, source, and SHA-256. Model backend selection
supports GPU-first, GPU-only, and CPU-only modes. Backend changes are persisted
but locked while loading or generating so the runtime cannot switch underneath
an active request.

The UI strategy is to make model state visible. If a model is missing, the app
should not freeze or silently fail. It should show a clean first-boot card,
download/verify progress, and actionable error text.

## 12. Performance Engineering

The performance target is not simply fast WAV writing; it is keeping the whole
application responsive while chat, download, verification, and voice rendering
compete for limited resources.

Current performance measures include:

1. Avoid repeated copying of verified local Gemma models.
2. Cache BarkPack acoustic profiles in native memory.
3. Cache script and render results by prompt, voice, style, sample rate, and
   performance profile.
4. Use performance-specific event budgets.
5. Avoid per-sample trigonometric calls in the DSP loop.
6. Buffer WAV output to reduce tiny writes.
7. Keep startup BarkPack checks local-only unless the user explicitly installs.
8. Provide CPU/GPU backend selection for chat model inference.

The default Eco 8 GB mode chooses a lower sample rate and a cheaper native DSP
path. Balanced mode aims for normal daily use. Studio mode is reserved for
higher-quality previews when the machine has time and memory headroom.

## 13. Diagnostics and Traceability

The renderer emits `<wav>.trace.json` sidecars. A trace records information such
as:

1. Event timing.
2. Unit text.
3. Speaker/profile identifiers.
4. Pitch and energy.
5. Voicing flags.
6. Fricative, plosive, and nasal flags.
7. Formant ratios.
8. Pack profile coefficients.

This trace layer is a major design choice. It turns subjective reports such as
"the voice hums instead of speaking words" into inspectable data. Developers can
see whether the text chunker emitted usable units, whether consonants were
recognized, whether a speaker profile suppressed articulation, or whether the
audio path degraded into over-voiced harmonic output.

The GitHub Actions workflow also renders reference previews:

1. `01_narrator_clarity.wav`
2. `02_dialogue_turns.wav`
3. `03_studio_expression.wav`
4. Matching `*.wav.trace.json` files
5. `SHA256SUMS.txt`

These previews are intended to catch bad pack builds before users copy new
release-index hashes into app builds.

## 14. Security Analysis

The security model addresses four common failure classes.

First, network substitution is limited by HTTPS plus pinned SHA-256. A valid TLS
connection alone is not enough; the bytes must match expected metadata.

Second, local-path confusion is limited by extension and digest checks. A user
can point `NAZA_MODEL_PATH` to a file, but the app accepts it only if it is the
exact expected `.litertlm` model.

Third, partial-download reuse is limited by `.part` staging and deletion on
mismatch. A crashed or interrupted download should not become a trusted model.

Fourth, release-index tampering is limited by optional index pinning plus
per-asset hashes. The app does not treat a locally generated convenience index
as trusted authority.

This design does not replace code signing, operating-system sandboxing, or
supply-chain review of source checkpoints. It narrows the runtime artifact
acceptance path so users do not unknowingly run or load arbitrary model files.

## 15. Evaluation Plan

The current system has engineering validation but not yet a complete perceptual
study. A full evaluation should include five tracks.

### 15.1 Correctness and Security

1. Hash mismatch rejects downloaded Gemma files.
2. Hash mismatch rejects BarkPack index and shard files.
3. Partial `.part` files are deleted or ignored.
4. Local `NAZA_MODEL_PATH` is used directly only after digest match.
5. Missing BarkPack families are surfaced in UI status.

### 15.2 Performance

1. Time to verify a local Gemma model.
2. Time to install BarkPack from release assets.
3. Time to probe a verified BarkPack.
4. Time to render fixed scripts in Eco, Balanced, and Studio modes.
5. Peak resident memory during chat generation and audio rendering.
6. Flutter UI frame timing during model and BarkPack operations.

### 15.3 Intelligibility

1. Word error rate using an automatic speech recognizer on fixed scripts.
2. Human transcription accuracy on short prompts.
3. Consonant audibility scoring for fricatives, plosives, and nasals.
4. Comparison between generated trace units and heard words.

### 15.4 Naturalness

1. Mean opinion score for voice naturalness.
2. Pairwise preference between Eco, Balanced, and Studio profiles.
3. Listener ratings for rhythm, pauses, emphasis, and speaker consistency.

### 15.5 Regression Testing

1. Store reference WAVs and trace JSON for every release.
2. Compare trace event counts and timing against expected ranges.
3. Detect output files that collapse into near-constant harmonic hum.
4. Detect missing speaker/semantic metadata before publishing a release.

## 16. Current Engineering Findings

The project has already surfaced several practical findings.

1. UI responsiveness matters as much as raw inference speed. A model can be
   technically working while the app feels broken if rendering waits for a
   resize or blocks timers on the main isolate.
2. Hashing multi-gigabyte models should be done deliberately and only when
   needed. Re-copying and re-verifying local models creates user-visible stalls.
3. Small voice packs can install quickly, but packs that are too small often
   lack enough semantic or speaker conditioning to speak words clearly.
4. Compact sidecars are useful as a bridge, but they do not replace learned
   speech representations.
5. A native trace file is one of the fastest ways to debug audio quality because
   it exposes the intermediate units that the ear alone cannot isolate.
6. GitHub Actions can serve as both a release builder and an audio smoke-test
   environment by rendering preview WAVs before publication.

## 17. Limitations

BarkPack is still an engineering prototype with clear limitations:

1. It does not yet execute full Bark transformer inference.
2. It does not yet decode a learned neural codec from predicted codec tokens.
3. The current pronunciation model is English-lite and rule-based.
4. Sidecar speaker metadata improves conditioning but is not a learned voice
   clone or full Bark history prompt.
5. Audio quality remains below modern neural TTS systems.
6. Intelligibility must be measured formally with ASR and human listener tests.
7. GPU acceleration currently applies to the chat model path, not a full native
   Bark tensor execution engine.
8. iOS and mobile distribution require additional platform-specific signing,
   storage, and background-download validation.

## 18. Future Work

The next research direction is to replace deterministic approximations with
bounded neural execution while preserving the security and UI architecture.

High-priority work:

1. Add a real tensor-backed semantic stage.
2. Add coarse/fine token scheduling with bounded KV-cache memory.
3. Add a compact codec decoder or bridge to an existing mobile-friendly neural
   codec runtime.
4. Implement SIMD kernels for CPU inference.
5. Add GPU backend selection for native audio graph stages where available.
6. Store multiple speaker profiles with calibrated articulation and prosody.
7. Add multilingual pronunciation sidecars.
8. Build a regression set of prompts, WAVs, traces, and ASR transcripts.
9. Add signed release attestations in addition to SHA-256 pinning.
10. Create a formal benchmark on an 8 GB laptop with cold-start, warm-start,
    chat, render, and UI-frame measurements.

Longer-term work:

1. Explore hybrid neural/DSP rendering where neural stages predict a compact
   event lattice and DSP handles fast deterministic waveform generation.
2. Train or distill a small pronunciation/prosody model specifically for
   BarkPack sidecars.
3. Use pack-aware adaptive rendering: low-cost speech during interaction and
   higher-quality re-rendering when idle.
4. Add a repair pass that detects hum-like output and rebalances voicing,
   consonant gain, and formants before saving final WAVs.
5. Treat trace JSON as supervised data for future pack tuning.

## 19. Conclusion

BarkPack is a pragmatic step toward local, secure, and responsive conversational
audio in Flutter applications. Its main contribution is not claiming immediate
neural parity with Bark. Its contribution is the surrounding system that makes
local audio generation shippable: pinned downloads, SHA-256 validation,
sanitized release assets, inspectable pack status, native FFI rendering,
performance profiles for 8 GB systems, self-test previews, and traceable audio
events.

The current implementation establishes a safe scaffold for future neural graph
execution. As tensor-backed semantic, coarse, fine, and codec stages replace the
deterministic scheduler, the same BarkPack distribution, verification, caching,
and UI diagnostic model can remain in place. That makes the system useful now
and a credible foundation for more advanced local voice generation.

## Project Artifacts

Relevant repository files:

1. `lib/main.dart`
2. `native/naza_bark_ffi.cpp`
3. `native/linux/libnaza_bark_ffi.so`
4. `tools/convert_bark_to_barkpack.py`
5. `tools/build_barkpack_release_index.py`
6. `tools/render_barkpack_preview.cpp`
7. `.github/workflows/barkpack-release.yml`
8. `README.md`
9. `idea.tree`

## References

1. Suno AI. *Bark: Text-Prompted Generative Audio Model*. GitHub repository.
   https://github.com/suno-ai/bark
2. Borsos et al. *AudioLM: a Language Modeling Approach to Audio Generation*.
   arXiv:2209.03143. https://arxiv.org/abs/2209.03143
3. Wang et al. *Neural Codec Language Models are Zero-Shot Text to Speech
   Synthesizers*. arXiv:2301.02111. https://arxiv.org/abs/2301.02111
4. Zeghidour et al. *SoundStream: An End-to-End Neural Audio Codec*.
   arXiv:2107.03312. https://arxiv.org/abs/2107.03312
5. Défossez et al. *High Fidelity Neural Audio Compression*. arXiv:2210.13438.
   https://arxiv.org/abs/2210.13438
6. Meta AI. *EnCodec: State-of-the-art deep learning based audio codec*.
   GitHub repository. https://github.com/facebookresearch/encodec
