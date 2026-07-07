#ifndef NAZA_BARK_FFI_H_
#define NAZA_BARK_FFI_H_

#include <stdint.h>

#if defined(_WIN32)
#define NAZA_BARK_EXPORT extern "C" __declspec(dllexport)
#else
#define NAZA_BARK_EXPORT extern "C" __attribute__((visibility("default")))
#endif

NAZA_BARK_EXPORT int32_t naza_bark_probe(
    const char* pack_dir,
    char* out_json,
    int32_t out_json_len);

NAZA_BARK_EXPORT int32_t naza_bark_render_wav(
    const char* pack_dir,
    const char* script,
    const char* voice,
    const char* style,
    const char* output_wav,
    int32_t sample_rate,
    int32_t max_seconds,
    char* error,
    int32_t error_len);

NAZA_BARK_EXPORT int32_t naza_bark_render_wav_v2(
    const char* pack_dir,
    const char* script,
    const char* voice,
    const char* style,
    const char* output_wav,
    int32_t sample_rate,
    int32_t max_seconds,
    int32_t performance_flags,
    int32_t max_events,
    char* error,
    int32_t error_len);

#endif  // NAZA_BARK_FFI_H_
