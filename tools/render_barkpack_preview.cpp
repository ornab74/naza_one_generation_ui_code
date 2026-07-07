#include "../native/naza_bark_ffi.h"

#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

struct PreviewCase {
  std::string name;
  std::string script;
  std::string voice;
  std::string style;
  int flags;
  int events;
};

int main(int argc, char** argv) {
  if (argc < 3) {
    std::cerr << "usage: render_barkpack_preview <pack_dir> <output_dir>\n";
    return 2;
  }

  const fs::path pack_dir = argv[1];
  const fs::path output_dir = argv[2];
  fs::create_directories(output_dir);

  std::vector<PreviewCase> cases = {
      {
          "01_narrator_clarity",
          "Narrator: The quick brown fox jumps over the lazy dog. This preview checks vowels, fricatives, and plosive timing.",
          "warm narrator, clear close mic",
          "balanced, natural, speech clarity test",
          2,
          128,
      },
      {
          "02_dialogue_turns",
          "Speaker A: Are you hearing clearer words now?\nSpeaker B: Yes, the voice has sharper consonants and better rhythm.",
          "two natural speakers, close mic",
          "dialogue, calm, human timing",
          2,
          160,
      },
      {
          "03_studio_expression",
          "Narrator: Softly, then brighter! Can the system keep the same voice while changing emotion?",
          "expressive narrator, bright but warm",
          "studio, expressive, light breath",
          4,
          192,
      },
  };

  int failures = 0;
  for (const PreviewCase& item : cases) {
    const fs::path wav = output_dir / (item.name + ".wav");
    char error[2048] = {0};
    const int code = naza_bark_render_wav_v2(
        pack_dir.string().c_str(),
        item.script.c_str(),
        item.voice.c_str(),
        item.style.c_str(),
        wav.string().c_str(),
        item.flags == 4 ? 32000 : 22050,
        30,
        item.flags,
        item.events,
        error,
        static_cast<int32_t>(sizeof(error)));
    if (code <= 0 || !fs::exists(wav) || fs::file_size(wav) <= 44) {
      ++failures;
      std::cerr << "preview failed: " << item.name << " error=" << error
                << "\n";
      continue;
    }
    const fs::path trace = wav.string() + ".trace.json";
    std::cout << "preview ok: " << wav << " bytes=" << fs::file_size(wav)
              << " code=" << code;
    if (fs::exists(trace)) {
      std::cout << " trace=" << trace << " trace_bytes=" << fs::file_size(trace);
    }
    std::cout << "\n";
  }

  char probe[4096] = {0};
  naza_bark_probe(pack_dir.string().c_str(), probe, sizeof(probe));
  std::cout << "probe: " << probe << "\n";
  return failures == 0 ? 0 : 1;
}
