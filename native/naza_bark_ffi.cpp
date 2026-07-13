#include "naza_bark_ffi.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <fstream>
#include <iomanip>
#include <map>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>

namespace {

constexpr double kPi = 3.14159265358979323846;
constexpr double kTwoPi = 6.28318530717958647692;
constexpr int kSinTableSize = 4096;
constexpr uint64_t kFnvOffset = 1469598103934665603ULL;
constexpr uint64_t kFnvPrime = 1099511628211ULL;
constexpr int32_t kRenderFlagEco = 1;
constexpr int32_t kRenderFlagBalanced = 2;
constexpr int32_t kRenderFlagStudio = 4;
constexpr size_t kMaxProfileCacheEntries = 2;

struct PackProfile {
  bool manifest_ok = false;
  int tensor_count = 0;
  bool semantic = false;
  bool coarse = false;
  bool fine = false;
  bool codec = false;
  bool speaker = false;
  uint64_t seed = kFnvOffset;
  double warmth = 0.50;
  double clarity = 0.50;
  double breath = 0.18;
  double density = 0.50;
  double pitch_bias = 0.0;
  double tract_length = 1.0;
  double breathiness = 0.18;
  double brightness = 1.0;
  double consonant_gain = 1.0;
  double articulation_bias = 0.60;
  double pace_bias = 0.0;
  double stress_bias = 0.0;
  double pause_bias = 0.0;
  double reduction_strength = 0.22;
  double duration_bias = 0.0;
  double clarity_boost = 0.10;
  bool cached = false;
};

struct Utterance {
  std::string speaker;
  std::string text;
};

struct BarkEvent {
  std::string speaker;
  std::string text;
  uint64_t semantic_seed = kFnvOffset;
  double seconds = 1.2;
  double energy = 0.45;
  double base_hz = 150.0;
  double pause_seconds = 0.08;
  double formant1 = 650.0;
  double formant2 = 1450.0;
  double formant3 = 2500.0;
  double consonant = 0.16;
  double articulation = 0.52;
  double voicing = 1.0;
  double fricative = 0.0;
  double plosive = 0.0;
  double nasal = 0.0;
};

uint64_t fnv1a(const void* data, size_t len, uint64_t seed = kFnvOffset) {
  const uint8_t* bytes = static_cast<const uint8_t*>(data);
  uint64_t h = seed;
  for (size_t i = 0; i < len; ++i) {
    h ^= static_cast<uint64_t>(bytes[i]);
    h *= kFnvPrime;
  }
  return h;
}

uint64_t fnv1a_string(const std::string& s, uint64_t seed = kFnvOffset) {
  return fnv1a(s.data(), s.size(), seed);
}

const std::vector<double>& sin_table() {
  static const std::vector<double> table = []() {
    std::vector<double> values(kSinTableSize + 1);
    for (int i = 0; i <= kSinTableSize; ++i) {
      values[i] = std::sin((static_cast<double>(i) / kSinTableSize) * kTwoPi);
    }
    return values;
  }();
  return table;
}

double fast_sin_phase(double phase) {
  while (phase < 0.0) phase += kTwoPi;
  while (phase >= kTwoPi) phase -= kTwoPi;
  const double scaled = phase * (static_cast<double>(kSinTableSize) / kTwoPi);
  const int index = static_cast<int>(scaled);
  const double frac = scaled - index;
  const std::vector<double>& table = sin_table();
  const int next = index + 1 <= kSinTableSize ? index + 1 : 0;
  return table[index] + (table[next] - table[index]) * frac;
}

void advance_phase(double* phase, double increment) {
  *phase += increment;
  while (*phase >= kTwoPi) *phase -= kTwoPi;
  while (*phase < 0.0) *phase += kTwoPi;
}

double smoothstep(double x) {
  x = std::max(0.0, std::min(1.0, x));
  return x * x * (3.0 - 2.0 * x);
}

double clamp_double(double value, double low, double high) {
  return std::max(low, std::min(high, value));
}

std::string safe_string(const char* value) {
  return value == nullptr ? std::string() : std::string(value);
}

std::string trim(const std::string& value) {
  size_t begin = 0;
  while (begin < value.size() &&
         static_cast<unsigned char>(value[begin]) <= ' ') {
    ++begin;
  }
  size_t end = value.size();
  while (end > begin && static_cast<unsigned char>(value[end - 1]) <= ' ') {
    --end;
  }
  return value.substr(begin, end - begin);
}

std::string lower_ascii(std::string value) {
  for (size_t i = 0; i < value.size(); ++i) {
    if (value[i] >= 'A' && value[i] <= 'Z') {
      value[i] = static_cast<char>(value[i] - 'A' + 'a');
    }
  }
  return value;
}

bool file_exists(const std::string& path) {
  std::ifstream in(path.c_str(), std::ios::binary);
  return in.good();
}

std::string join_path(const std::string& dir, const std::string& name) {
  if (dir.empty()) return name;
  const char last = dir[dir.size() - 1];
  if (last == '/' || last == '\\') return dir + name;
  return dir + "/" + name;
}

bool read_text_file(const std::string& path, std::string* out) {
  std::ifstream in(path.c_str(), std::ios::binary);
  if (!in.good()) return false;
  std::ostringstream ss;
  ss << in.rdbuf();
  *out = ss.str();
  return true;
}

int parse_int_after(const std::string& source, const std::string& marker) {
  const size_t at = source.find(marker);
  if (at == std::string::npos) return 0;
  size_t i = at + marker.size();
  while (i < source.size() && source[i] != ':') ++i;
  if (i < source.size()) ++i;
  while (i < source.size() &&
         (source[i] == ' ' || source[i] == '\n' || source[i] == '\r' ||
          source[i] == '\t')) {
    ++i;
  }
  int value = 0;
  while (i < source.size() && source[i] >= '0' && source[i] <= '9') {
    value = value * 10 + (source[i] - '0');
    ++i;
  }
  return value;
}

double parse_double_after(
    const std::string& source,
    const std::string& marker,
    double fallback) {
  const size_t at = source.find(marker);
  if (at == std::string::npos) return fallback;
  size_t i = at + marker.size();
  while (i < source.size() && source[i] != ':') ++i;
  if (i < source.size()) ++i;
  while (i < source.size() &&
         (source[i] == ' ' || source[i] == '\n' || source[i] == '\r' ||
          source[i] == '\t')) {
    ++i;
  }
  const size_t begin = i;
  if (i < source.size() && (source[i] == '-' || source[i] == '+')) ++i;
  bool saw_digit = false;
  while (i < source.size() && source[i] >= '0' && source[i] <= '9') {
    saw_digit = true;
    ++i;
  }
  if (i < source.size() && source[i] == '.') {
    ++i;
    while (i < source.size() && source[i] >= '0' && source[i] <= '9') {
      saw_digit = true;
      ++i;
    }
  }
  if (!saw_digit) return fallback;
  return std::strtod(source.substr(begin, i - begin).c_str(), nullptr);
}

void copy_c_string(const std::string& value, char* out, int32_t len) {
  if (out == nullptr || len <= 0) return;
  const size_t limit = static_cast<size_t>(len - 1);
  const size_t count = std::min(limit, value.size());
  if (count > 0) {
    std::memcpy(out, value.data(), count);
  }
  out[count] = '\0';
}

void set_error(char* error, int32_t error_len, const std::string& value) {
  copy_c_string(value, error, error_len);
}

void mix_file_fingerprint(const std::string& path, PackProfile* profile) {
  std::ifstream in(path.c_str(), std::ios::binary);
  if (!in.good()) return;

  in.seekg(0, std::ios::end);
  const std::streamoff size = in.tellg();
  if (size <= 0) return;

  const std::streamoff probes[] = {
      0,
      std::max<std::streamoff>(0, size / 3),
      std::max<std::streamoff>(0, (size * 2) / 3),
      std::max<std::streamoff>(0, size - 4096),
  };

  std::vector<char> buf(4096);
  uint64_t local = profile->seed ^ static_cast<uint64_t>(size);
  for (size_t p = 0; p < sizeof(probes) / sizeof(probes[0]); ++p) {
    in.clear();
    in.seekg(probes[p], std::ios::beg);
    in.read(buf.data(), static_cast<std::streamsize>(buf.size()));
    const std::streamsize got = in.gcount();
    if (got > 0) {
      local = fnv1a(buf.data(), static_cast<size_t>(got), local);
    }
  }
  profile->seed = local;
}

PackProfile load_pack_profile_uncached(const std::string& pack_dir) {
  PackProfile profile;
  std::string manifest;
  const std::string manifest_path = join_path(pack_dir, "manifest.json");
  if (!read_text_file(manifest_path, &manifest)) {
    profile.seed = fnv1a_string(pack_dir);
    return profile;
  }

  profile.manifest_ok = true;
  std::string install_index;
  read_text_file(join_path(pack_dir, "install_index_v2.json"), &install_index);
  const std::string metadata =
      install_index.empty() ? manifest : manifest + "\n" + install_index;
  profile.seed = fnv1a_string(metadata);
  profile.tensor_count = parse_int_after(metadata, "\"tensorCount\"");
  const std::string low = lower_ascii(metadata);
  profile.semantic = low.find("semantic") != std::string::npos ||
                     low.find("text") != std::string::npos;
  profile.coarse = low.find("coarse") != std::string::npos;
  profile.fine = low.find("fine") != std::string::npos;
  profile.codec = low.find("codec") != std::string::npos ||
                  low.find("encodec") != std::string::npos;
  profile.speaker = low.find("speaker") != std::string::npos ||
                    low.find("history") != std::string::npos ||
                    low.find("prompt") != std::string::npos;
  profile.pitch_bias = parse_double_after(metadata, "\"pitchBias\"", 0.0);
  profile.tract_length = clamp_double(
      parse_double_after(metadata, "\"tractLength\"", 1.0), 0.82, 1.18);
  profile.breathiness = clamp_double(
      parse_double_after(metadata, "\"breathiness\"", 0.18), 0.04, 0.42);
  profile.brightness = clamp_double(
      parse_double_after(metadata, "\"brightness\"", 1.0), 0.72, 1.32);
  profile.consonant_gain = clamp_double(
      parse_double_after(metadata, "\"consonantGain\"", 1.0), 0.70, 1.50);
  profile.articulation_bias = clamp_double(
      parse_double_after(metadata, "\"articulation\"", 0.60), 0.32, 0.92);
  profile.pace_bias = clamp_double(
      parse_double_after(metadata, "\"paceBias\"", 0.0), -0.18, 0.18);
  profile.stress_bias = clamp_double(
      parse_double_after(metadata, "\"stressBias\"", 0.0), -0.24, 0.24);
  profile.pause_bias = clamp_double(
      parse_double_after(metadata, "\"pauseBias\"", 0.0), -0.12, 0.12);
  profile.reduction_strength = clamp_double(
      parse_double_after(metadata, "\"reductionStrength\"", 0.22), 0.0, 0.48);
  profile.duration_bias = clamp_double(
      parse_double_after(metadata, "\"durationBias\"", 0.0), -0.18, 0.18);
  profile.clarity_boost = clamp_double(
      parse_double_after(metadata, "\"clarityBoost\"", 0.10), 0.0, 0.32);

  for (int i = 0; i < 512; ++i) {
    char name[32];
    std::snprintf(name, sizeof(name), "tensors_%03d.bin", i);
    if (manifest.find(name) == std::string::npos) continue;
    const std::string path = join_path(pack_dir, name);
    if (file_exists(path)) {
      mix_file_fingerprint(path, &profile);
    }
  }

  const double a = static_cast<double>((profile.seed >> 8) & 0xFF) / 255.0;
  const double b = static_cast<double>((profile.seed >> 24) & 0xFF) / 255.0;
  const double c = static_cast<double>((profile.seed >> 40) & 0xFF) / 255.0;
  const double d = static_cast<double>((profile.seed >> 52) & 0xFF) / 255.0;
  profile.warmth = 0.25 + a * 0.65 + (profile.speaker ? 0.06 : 0.0);
  profile.clarity =
      (0.35 + b * 0.55 + (profile.semantic ? 0.05 : 0.0)) *
      (0.92 + (profile.brightness - 1.0) * 0.24);
  profile.breath = (0.08 + c * 0.20 + profile.breathiness * 0.35);
  profile.density = 0.35 + d * 0.55 + (profile.codec ? 0.07 : 0.0);
  return profile;
}

std::mutex& profile_cache_mutex() {
  static std::mutex m;
  return m;
}

std::map<std::string, PackProfile>& profile_cache() {
  static std::map<std::string, PackProfile> cache;
  return cache;
}

PackProfile load_pack_profile(const std::string& pack_dir) {
  {
    std::lock_guard<std::mutex> lock(profile_cache_mutex());
    const auto found = profile_cache().find(pack_dir);
    if (found != profile_cache().end()) {
      PackProfile cached = found->second;
      cached.cached = true;
      return cached;
    }
  }

  PackProfile loaded = load_pack_profile_uncached(pack_dir);
  {
    std::lock_guard<std::mutex> lock(profile_cache_mutex());
    profile_cache()[pack_dir] = loaded;
    while (profile_cache().size() > kMaxProfileCacheEntries) {
      profile_cache().erase(profile_cache().begin());
    }
  }
  return loaded;
}

int count_words(const std::string& text) {
  int words = 0;
  bool in_word = false;
  for (size_t i = 0; i < text.size(); ++i) {
    const unsigned char ch = static_cast<unsigned char>(text[i]);
    const bool word = (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
                      (ch >= '0' && ch <= '9') || ch == '\'';
    if (word && !in_word) ++words;
    in_word = word;
  }
  return words;
}

int count_vowels(const std::string& text) {
  int vowels = 0;
  for (size_t i = 0; i < text.size(); ++i) {
    const char ch = static_cast<char>(std::tolower(text[i]));
    if (ch == 'a' || ch == 'e' || ch == 'i' || ch == 'o' || ch == 'u' ||
        ch == 'y') {
      ++vowels;
    }
  }
  return vowels;
}

bool is_speech_char(unsigned char ch) {
  return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
         (ch >= '0' && ch <= '9') || ch == '\'';
}

bool is_vowel_char(char ch) {
  ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
  return ch == 'a' || ch == 'e' || ch == 'i' || ch == 'o' || ch == 'u' ||
         ch == 'y';
}

std::vector<std::string> split_speech_tokens(const std::string& text) {
  std::vector<std::string> tokens;
  std::string current;
  for (size_t i = 0; i < text.size(); ++i) {
    const unsigned char ch = static_cast<unsigned char>(text[i]);
    if (is_speech_char(ch)) {
      current.push_back(static_cast<char>(ch));
    } else if (!current.empty()) {
      tokens.push_back(current);
      current.clear();
    }
  }
  if (!current.empty()) tokens.push_back(current);
  if (tokens.empty()) tokens.push_back(trim(text));
  return tokens;
}

bool is_acronym_token(const std::string& token) {
  int upper = 0;
  int letters = 0;
  for (size_t i = 0; i < token.size(); ++i) {
    const unsigned char ch = static_cast<unsigned char>(token[i]);
    if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')) {
      ++letters;
      if (ch >= 'A' && ch <= 'Z') ++upper;
    }
  }
  return letters >= 2 && letters <= 6 && upper == letters;
}

std::vector<std::string> split_acronym_units(const std::string& token) {
  std::vector<std::string> units;
  for (size_t i = 0; i < token.size(); ++i) {
    const unsigned char ch = static_cast<unsigned char>(token[i]);
    if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
        (ch >= '0' && ch <= '9')) {
      units.push_back(std::string(1, static_cast<char>(std::tolower(ch))));
    }
  }
  if (units.empty()) units.push_back(token);
  return units;
}

std::vector<std::string> split_syllable_units(const std::string& token) {
  std::vector<std::string> units;
  const std::string low = lower_ascii(token);
  std::string current;
  bool has_vowel = false;
  for (size_t i = 0; i < low.size(); ++i) {
    const char ch = low[i];
    current.push_back(ch);
    if (is_vowel_char(ch)) has_vowel = true;
    const bool digraph =
        i + 1 < low.size() &&
        ((low[i] == 's' && low[i + 1] == 'h') ||
         (low[i] == 'c' && low[i + 1] == 'h') ||
         (low[i] == 't' && low[i + 1] == 'h') ||
         (low[i] == 'p' && low[i + 1] == 'h') ||
         (low[i] == 'w' && low[i + 1] == 'h') ||
         (low[i] == 'n' && low[i + 1] == 'g') ||
         (low[i] == 'q' && low[i + 1] == 'u'));
    if (digraph) {
      ++i;
      current.push_back(low[i]);
      continue;
    }
    const bool next_is_vowel = i + 1 < low.size() && is_vowel_char(low[i + 1]);
    const bool current_long = current.size() >= 5;
    if (!current.empty() && has_vowel && (next_is_vowel || current_long)) {
      units.push_back(current);
      current.clear();
      has_vowel = false;
    }
  }
  if (!current.empty()) units.push_back(current);
  if (units.empty()) units.push_back(low.empty() ? token : low);
  return units;
}

bool is_function_word(const std::string& token) {
  const std::string low = lower_ascii(token);
  static const char* words[] = {
      "a",   "an",  "and", "are", "as", "at", "for", "from", "in",
      "is",  "of",  "on",  "or",  "the", "to", "was", "we", "you"};
  for (size_t i = 0; i < sizeof(words) / sizeof(words[0]); ++i) {
    if (low == words[i]) return true;
  }
  return false;
}

bool ends_with(const std::string& value, const std::string& suffix) {
  return value.size() >= suffix.size() &&
         value.compare(value.size() - suffix.size(), suffix.size(), suffix) == 0;
}

double suffix_stress_bonus(const std::string& token) {
  const std::string low = lower_ascii(token);
  if (ends_with(low, "tion") || ends_with(low, "sion") ||
      ends_with(low, "ment") || ends_with(low, "ness") ||
      ends_with(low, "ity") || ends_with(low, "ical")) {
    return 0.09;
  }
  if (ends_with(low, "ing") || ends_with(low, "ed") ||
      ends_with(low, "er") || ends_with(low, "ly") ||
      ends_with(low, "es") || ends_with(low, "s")) {
    return -0.035;
  }
  return 0.0;
}

char dominant_vowel(const std::string& token) {
  const std::string low = lower_ascii(token);
  if (low.find("ee") != std::string::npos ||
      low.find("ea") != std::string::npos ||
      low.find("ie") != std::string::npos) {
    return 'i';
  }
  if (low.find("oo") != std::string::npos ||
      low.find("ou") != std::string::npos ||
      low.find("ew") != std::string::npos) {
    return 'u';
  }
  if (low.find("oa") != std::string::npos ||
      low.find("ow") != std::string::npos) {
    return 'o';
  }
  for (size_t i = 0; i < low.size(); ++i) {
    const char ch = low[i];
    if (ch == 'a' || ch == 'e' || ch == 'i' || ch == 'o' || ch == 'u' ||
        ch == 'y') {
      return ch;
    }
  }
  return 'a';
}

void vowel_formants(
    char vowel,
    double* formant1,
    double* formant2,
    double* formant3) {
  switch (vowel) {
    case 'i':
    case 'y':
      *formant1 = 310.0;
      *formant2 = 2210.0;
      *formant3 = 2980.0;
      break;
    case 'e':
      *formant1 = 470.0;
      *formant2 = 1840.0;
      *formant3 = 2480.0;
      break;
    case 'o':
      *formant1 = 500.0;
      *formant2 = 910.0;
      *formant3 = 2450.0;
      break;
    case 'u':
      *formant1 = 350.0;
      *formant2 = 980.0;
      *formant3 = 2240.0;
      break;
    default:
      *formant1 = 730.0;
      *formant2 = 1220.0;
      *formant3 = 2600.0;
      break;
  }
}

bool contains_any(const std::string& text, const char* chars) {
  const std::string low = lower_ascii(text);
  for (size_t i = 0; i < low.size(); ++i) {
    for (const char* p = chars; *p != '\0'; ++p) {
      if (low[i] == *p) return true;
    }
  }
  return false;
}

bool contains_substr(const std::string& text, const std::string& needle) {
  return lower_ascii(text).find(needle) != std::string::npos;
}

std::vector<std::string> split_sentences(const std::string& text) {
  std::vector<std::string> sentences;
  size_t start = 0;
  for (size_t i = 0; i < text.size(); ++i) {
    const char ch = text[i];
    const bool boundary = ch == '.' || ch == '!' || ch == '?' || ch == ';';
    if (!boundary) continue;
    const std::string chunk = trim(text.substr(start, i + 1 - start));
    if (!chunk.empty()) sentences.push_back(chunk);
    start = i + 1;
  }
  const std::string tail = trim(text.substr(start));
  if (!tail.empty()) sentences.push_back(tail);
  return sentences;
}

bool is_metadata_label(const std::string& label) {
  const std::string low = lower_ascii(trim(label));
  return low == "convo title" || low == "voice" || low == "style" ||
         low == "segments" || low == "render notes" || low == "notes";
}

std::vector<Utterance> collect_utterances(const std::string& script) {
  std::vector<Utterance> utterances;
  std::istringstream lines(script);
  std::string line;
  while (std::getline(lines, line)) {
    line = trim(line);
    while (!line.empty() && (line[0] == '-' || line[0] == '*')) {
      line = trim(line.substr(1));
    }
    if (line.empty()) continue;
    const size_t colon = line.find(':');
    if (colon != std::string::npos && colon < 36) {
      const std::string label = trim(line.substr(0, colon));
      const std::string body = trim(line.substr(colon + 1));
      if (!body.empty() && !is_metadata_label(label)) {
        const std::vector<std::string> sentences = split_sentences(body);
        if (sentences.empty()) {
          utterances.push_back({label, body});
        } else {
          for (size_t i = 0; i < sentences.size(); ++i) {
            utterances.push_back({label, sentences[i]});
          }
        }
      }
      continue;
    }
    const std::vector<std::string> sentences = split_sentences(line);
    for (size_t i = 0; i < sentences.size(); ++i) {
      utterances.push_back({"Narrator", sentences[i]});
    }
  }

  if (utterances.empty()) {
    utterances.push_back({"Narrator", "Local Bark conversation preview."});
  }
  return utterances;
}

std::vector<BarkEvent> semantic_to_events(
    const std::vector<Utterance>& utterances,
    const PackProfile& pack,
    const std::string& voice,
    const std::string& style,
    int max_seconds,
    int32_t performance_flags,
    int max_events) {
  std::vector<BarkEvent> events;
  double accumulated = 0.0;
  const bool eco = (performance_flags & kRenderFlagEco) != 0;
  const bool studio = (performance_flags & kRenderFlagStudio) != 0;
  const int event_limit =
      max_events > 0 ? std::max(1, std::min(max_events, 384)) : 96;
  const double time_scale =
      (eco ? 0.74 : (studio ? 1.06 : 0.90)) *
      (1.0 - clamp_double(pack.pace_bias, -0.16, 0.16));
  events.reserve(static_cast<size_t>(event_limit));
  const uint64_t style_seed = fnv1a_string(voice + "|" + style, pack.seed);
  for (size_t i = 0; i < utterances.size(); ++i) {
    if (static_cast<int>(events.size()) >= event_limit) break;
    const Utterance& utterance = utterances[i];
    const std::vector<std::string> tokens = split_speech_tokens(utterance.text);
    const bool excited = utterance.text.find('!') != std::string::npos;
    const bool question = utterance.text.find('?') != std::string::npos;
    const double pack_shift =
        (pack.warmth - 0.5) * 42.0 + (pack.clarity - 0.5) * 22.0;

    for (size_t t = 0; t < tokens.size(); ++t) {
      if (static_cast<int>(events.size()) >= event_limit) break;
      const bool acronym = is_acronym_token(tokens[t]);
      const bool reduced = is_function_word(tokens[t]);
      const std::vector<std::string> units =
          acronym ? split_acronym_units(tokens[t]) : split_syllable_units(tokens[t]);
      const double token_pos =
          tokens.size() <= 1 ? 0.0 : static_cast<double>(t) / (tokens.size() - 1);
      const double intonation =
          question ? (token_pos * 20.0) : (excited ? (1.0 - token_pos) * 16.0 : 0.0);

      for (size_t u = 0; u < units.size(); ++u) {
        if (static_cast<int>(events.size()) >= event_limit) break;
        BarkEvent event;
        event.speaker = utterance.speaker;
        event.text = units[u];
        event.semantic_seed = fnv1a_string(
            event.speaker + "|" + tokens[t] + "|" + event.text,
            style_seed + static_cast<uint64_t>(i * 4099 + t * 131 + u * 17));

        const int vowels = count_vowels(event.text);
        const bool has_vowel = vowels > 0;
        const bool has_fricative =
            contains_any(event.text, "sfxzvh") ||
            contains_substr(event.text, "sh") ||
            contains_substr(event.text, "th") ||
            contains_substr(event.text, "ch") ||
            contains_substr(event.text, "ph");
        const bool has_plosive = contains_any(event.text, "ptkbdgqc");
        const bool has_nasal =
            contains_any(event.text, "mn") || contains_substr(event.text, "ng");
        const double vowel_ratio =
            static_cast<double>(vowels) /
            std::max(1.0, static_cast<double>(event.text.size()));
        const double unit_pos =
            units.size() <= 1 ? 0.0 : static_cast<double>(u) / (units.size() - 1);
        const double speaker_shift =
            static_cast<double>((event.semantic_seed >> 16) & 0x7F) - 64.0;
        const double stress =
            (u == 0 ? 0.06 : 0.0) + (t == 0 ? 0.03 : 0.0) +
            suffix_stress_bonus(tokens[t]) + (acronym ? 0.08 : 0.0) +
            pack.stress_bias - (reduced ? pack.reduction_strength * 0.24 : 0.0);
        const double reduction_scale =
            reduced ? (1.0 - pack.reduction_strength * 0.42) : 1.0;

        event.seconds = clamp_double(
            (0.088 + event.text.size() * 0.017 + (has_vowel ? 0.070 : 0.0) +
             (has_plosive ? 0.020 : 0.0) + (has_fricative ? 0.018 : 0.0)) *
                time_scale * (1.0 + pack.duration_bias + stress * 0.38) *
                reduction_scale,
            eco ? 0.068 : 0.080,
            studio ? 0.42 : 0.34);
        event.energy = clamp_double(
            0.22 + vowel_ratio * 1.10 + stress + (excited ? 0.12 : 0.0) +
                (question ? 0.04 : 0.0) -
                (reduced ? pack.reduction_strength * 0.16 : 0.0),
            0.18,
            0.96);
        event.base_hz =
            122.0 + pack.pitch_bias + speaker_shift * 0.42 + pack_shift +
            intonation + (unit_pos - 0.5) * 5.0;
        if (lower_ascii(event.speaker).find("speaker b") != std::string::npos) {
          event.base_hz += 38.0;
        }
        if (lower_ascii(event.speaker).find("sound") != std::string::npos) {
          event.base_hz = 92.0 + std::fabs(speaker_shift) * 0.3;
          event.energy *= 0.72;
        }

        vowel_formants(
            dominant_vowel(event.text),
            &event.formant1,
            &event.formant2,
            &event.formant3);
        event.formant1 =
            (event.formant1 + (pack.warmth - 0.5) * 28.0) / pack.tract_length;
        event.formant2 =
            (event.formant2 + (pack.clarity - 0.5) * 70.0) / pack.tract_length;
        event.formant3 =
            (event.formant3 + (pack.density - 0.5) * 110.0) / pack.tract_length;
        event.fricative = has_fricative ? 1.0 : 0.0;
        event.plosive = has_plosive ? 1.0 : 0.0;
        event.nasal = has_nasal ? 1.0 : 0.0;
        event.voicing = clamp_double(
            has_vowel ? 1.0 : (has_nasal ? 0.58 : (has_fricative ? 0.16 : 0.30)),
            0.05,
            1.0);
        event.consonant =
            (0.08 + event.fricative * 0.24 + event.plosive * 0.24 +
             event.nasal * 0.08) *
            pack.consonant_gain;
        event.articulation = clamp_double(
            0.46 + (pack.semantic ? 0.15 : 0.0) + (pack.speaker ? 0.08 : 0.0) +
                pack.articulation_bias * 0.26 + pack.clarity * 0.10 +
                pack.clarity_boost * (reduced ? 0.30 : 0.70),
            0.42,
            0.92);
        event.pause_seconds =
            t + 1 == tokens.size() && u + 1 == units.size()
                ? std::max(0.01, (question ? 0.16 : (excited ? 0.11 : 0.07)) +
                                    pack.pause_bias)
                : (eco ? 0.003 : 0.006);

        if (max_seconds > 0 && accumulated + event.seconds > max_seconds) {
          const double remaining = max_seconds - accumulated;
          if (remaining < 0.05) break;
          event.seconds = remaining;
        }
        accumulated += event.seconds + event.pause_seconds;
        events.push_back(event);
        if (max_seconds > 0 && accumulated >= max_seconds) break;
      }
      if (max_seconds > 0 && accumulated >= max_seconds) break;
    }
  }
  return events;
}

uint32_t xorshift32(uint32_t* state) {
  uint32_t x = *state;
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  *state = x == 0 ? 0xA341316C : x;
  return *state;
}

void write_u16(std::ofstream& out, uint16_t value) {
  const char bytes[2] = {
      static_cast<char>(value & 0xFF),
      static_cast<char>((value >> 8) & 0xFF),
  };
  out.write(bytes, 2);
}

void write_u32(std::ofstream& out, uint32_t value) {
  const char bytes[4] = {
      static_cast<char>(value & 0xFF),
      static_cast<char>((value >> 8) & 0xFF),
      static_cast<char>((value >> 16) & 0xFF),
      static_cast<char>((value >> 24) & 0xFF),
  };
  out.write(bytes, 4);
}

void write_wav_header(std::ofstream& out, uint32_t sample_rate, uint32_t samples) {
  const uint16_t channels = 1;
  const uint16_t bits = 16;
  const uint32_t data_bytes = samples * channels * (bits / 8);
  const uint32_t byte_rate = sample_rate * channels * (bits / 8);
  const uint16_t block_align = channels * (bits / 8);

  out.seekp(0, std::ios::beg);
  out.write("RIFF", 4);
  write_u32(out, 36 + data_bytes);
  out.write("WAVE", 4);
  out.write("fmt ", 4);
  write_u32(out, 16);
  write_u16(out, 1);
  write_u16(out, channels);
  write_u32(out, sample_rate);
  write_u32(out, byte_rate);
  write_u16(out, block_align);
  write_u16(out, bits);
  out.write("data", 4);
  write_u32(out, data_bytes);
}

double softclip(double x) {
  return x / (1.0 + std::fabs(x) * 0.55);
}

class Resonator {
 public:
  void configure_bandpass(double sample_rate, double frequency, double q) {
    const double nyquist = sample_rate * 0.5;
    frequency = clamp_double(frequency, 70.0, nyquist * 0.88);
    q = clamp_double(q, 1.2, 18.0);
    const double omega = kTwoPi * frequency / sample_rate;
    const double alpha = std::sin(omega) / (2.0 * q);
    const double cos_omega = std::cos(omega);
    const double a0 = 1.0 + alpha;
    b0_ = alpha / a0;
    b1_ = 0.0;
    b2_ = -alpha / a0;
    a1_ = (-2.0 * cos_omega) / a0;
    a2_ = (1.0 - alpha) / a0;
  }

  double process(double input) {
    const double output = b0_ * input + z1_;
    z1_ = b1_ * input - a1_ * output + z2_;
    z2_ = b2_ * input - a2_ * output;
    return output;
  }

 private:
  double b0_ = 1.0;
  double b1_ = 0.0;
  double b2_ = 0.0;
  double a1_ = 0.0;
  double a2_ = 0.0;
  double z1_ = 0.0;
  double z2_ = 0.0;
};

double glottal_pulse(double phase) {
  phase = std::fmod(phase, kTwoPi);
  if (phase < 0.0) phase += kTwoPi;
  const double cycle = phase / kTwoPi;
  const double open_quotient = 0.58;
  if (cycle < open_quotient) {
    const double x = cycle / open_quotient;
    return std::sin(kPi * x) * (0.78 + 0.22 * std::sin(kTwoPi * x));
  }
  const double x = (cycle - open_quotient) / (1.0 - open_quotient);
  return -0.42 * std::exp(-7.0 * x) * (1.0 - 0.18 * x);
}

class PcmChunkWriter {
 public:
  explicit PcmChunkWriter(std::ofstream* out) : out_(out) {
    buffer_.reserve(64 * 1024);
  }

  ~PcmChunkWriter() { flush(); }

  void write_i16(int16_t value) {
    const uint16_t sample = static_cast<uint16_t>(value);
    buffer_.push_back(static_cast<char>(sample & 0xFF));
    buffer_.push_back(static_cast<char>((sample >> 8) & 0xFF));
    ++samples_;
    if (buffer_.size() >= 64 * 1024) {
      flush();
    }
  }

  void write_silence(uint32_t samples) {
    static const char zeros[4096] = {0};
    flush();
    uint32_t remaining = samples;
    while (remaining > 0) {
      const uint32_t chunk_samples = std::min<uint32_t>(remaining, sizeof(zeros) / 2);
      out_->write(zeros, static_cast<std::streamsize>(chunk_samples * 2));
      samples_ += chunk_samples;
      remaining -= chunk_samples;
    }
  }

  void flush() {
    if (!buffer_.empty()) {
      out_->write(buffer_.data(), static_cast<std::streamsize>(buffer_.size()));
      buffer_.clear();
    }
  }

  uint32_t samples() const { return samples_; }

 private:
  std::ofstream* out_;
  std::vector<char> buffer_;
  uint32_t samples_ = 0;
};

std::string json_escape(const std::string& value);

std::string trace_path_for_wav(const std::string& output_wav) {
  return output_wav + ".trace.json";
}

void write_render_trace_json(
    const std::vector<BarkEvent>& events,
    const PackProfile& pack,
    const std::string& output_wav,
    int sample_rate,
    int32_t performance_flags,
    uint32_t samples) {
  std::ofstream out(trace_path_for_wav(output_wav).c_str(), std::ios::binary);
  if (!out.good()) return;
  out << std::fixed << std::setprecision(6);
  out << "{\n";
  out << "  \"format\": \"naza-bark-render-trace-v1\",\n";
  out << "  \"native\": \"naza_bark_ffi_v2_source_filter\",\n";
  out << "  \"audioPath\": \"" << json_escape(output_wav) << "\",\n";
  out << "  \"sampleRate\": " << sample_rate << ",\n";
  out << "  \"samples\": " << samples << ",\n";
  out << "  \"seconds\": " << (sample_rate > 0 ? samples / static_cast<double>(sample_rate) : 0.0) << ",\n";
  out << "  \"performanceFlags\": " << performance_flags << ",\n";
  out << "  \"eventCount\": " << events.size() << ",\n";
  out << "  \"pack\": {\n";
  out << "    \"manifestOk\": " << (pack.manifest_ok ? "true" : "false") << ",\n";
  out << "    \"tensorCount\": " << pack.tensor_count << ",\n";
  out << "    \"semantic\": " << (pack.semantic ? "true" : "false") << ",\n";
  out << "    \"coarse\": " << (pack.coarse ? "true" : "false") << ",\n";
  out << "    \"fine\": " << (pack.fine ? "true" : "false") << ",\n";
  out << "    \"codec\": " << (pack.codec ? "true" : "false") << ",\n";
  out << "    \"speaker\": " << (pack.speaker ? "true" : "false") << ",\n";
  out << "    \"pitchBias\": " << pack.pitch_bias << ",\n";
  out << "    \"tractLength\": " << pack.tract_length << ",\n";
  out << "    \"breathiness\": " << pack.breathiness << ",\n";
  out << "    \"brightness\": " << pack.brightness << ",\n";
  out << "    \"consonantGain\": " << pack.consonant_gain << ",\n";
  out << "    \"articulation\": " << pack.articulation_bias << ",\n";
  out << "    \"paceBias\": " << pack.pace_bias << ",\n";
  out << "    \"stressBias\": " << pack.stress_bias << ",\n";
  out << "    \"pauseBias\": " << pack.pause_bias << ",\n";
  out << "    \"reductionStrength\": " << pack.reduction_strength << ",\n";
  out << "    \"durationBias\": " << pack.duration_bias << ",\n";
  out << "    \"clarityBoost\": " << pack.clarity_boost << "\n";
  out << "  },\n";
  out << "  \"events\": [\n";
  double cursor = 0.0;
  for (size_t i = 0; i < events.size(); ++i) {
    const BarkEvent& event = events[i];
    out << "    {";
    out << "\"index\": " << i << ", ";
    out << "\"speaker\": \"" << json_escape(event.speaker) << "\", ";
    out << "\"unit\": \"" << json_escape(event.text) << "\", ";
    out << "\"start\": " << cursor << ", ";
    out << "\"seconds\": " << event.seconds << ", ";
    out << "\"pause\": " << event.pause_seconds << ", ";
    out << "\"baseHz\": " << event.base_hz << ", ";
    out << "\"energy\": " << event.energy << ", ";
    out << "\"voicing\": " << event.voicing << ", ";
    out << "\"fricative\": " << event.fricative << ", ";
    out << "\"plosive\": " << event.plosive << ", ";
    out << "\"nasal\": " << event.nasal << ", ";
    out << "\"consonant\": " << event.consonant << ", ";
    out << "\"articulation\": " << event.articulation << ", ";
    out << "\"formant1\": " << event.formant1 << ", ";
    out << "\"formant2\": " << event.formant2 << ", ";
    out << "\"formant3\": " << event.formant3;
    out << "}" << (i + 1 == events.size() ? "\n" : ",\n");
    cursor += event.seconds + event.pause_seconds;
  }
  out << "  ]\n";
  out << "}\n";
}

int render_events_to_wav(
    const std::vector<BarkEvent>& events,
    const PackProfile& pack,
    const std::string& output_wav,
    int sample_rate,
    int32_t performance_flags) {
  std::ofstream out(output_wav.c_str(), std::ios::binary);
  if (!out.good()) return 0;

  write_wav_header(out, static_cast<uint32_t>(sample_rate), 0);
  PcmChunkWriter pcm_writer(&out);
  double smooth = 0.0;
  const bool eco = (performance_flags & kRenderFlagEco) != 0;
  const bool studio = (performance_flags & kRenderFlagStudio) != 0;

  for (size_t e = 0; e < events.size(); ++e) {
    const BarkEvent& event = events[e];
    const int event_samples =
        std::max(1, static_cast<int>(event.seconds * sample_rate));
    uint32_t rng =
        static_cast<uint32_t>((event.semantic_seed >> 16) ^ event.semantic_seed);

    const double base = std::max(74.0, std::min(265.0, event.base_hz));
    const double density = std::max(0.30, std::min(1.10, pack.density));
    const double clarity = std::max(0.25, std::min(1.05, pack.clarity));
    const double warmth = std::max(0.20, std::min(1.10, pack.warmth));
    const double breath = std::max(
        0.04,
        std::min(0.48, pack.breath * (0.82 + pack.breathiness)));
    const double inv_sample_rate = 1.0 / sample_rate;
    const double seed_phase =
        (static_cast<double>(event.semantic_seed & 0xFFFF) / 65535.0) * kTwoPi;
    double phase1 = seed_phase;
    double vib_phase = seed_phase * 0.37 + 0.19;
    double phrase_phase = seed_phase * 0.11 + 1.71;
    double gate_phase = seed_phase * 0.23 + 2.43;
    const double vib_increment =
        kTwoPi * (4.3 + density * 1.2) * inv_sample_rate;
    const double phrase_increment = kTwoPi * 0.67 * inv_sample_rate;
    const double gate_increment =
        kTwoPi * (7.0 + density * 5.0) * inv_sample_rate;
    const double f1 = event.formant1 * (0.985 + warmth * 0.030);
    const double f2 = event.formant2 * (0.985 + clarity * 0.025);
    const double f3 = event.formant3 * (0.980 + density * 0.030);
    Resonator r1;
    Resonator r2;
    Resonator r3;
    Resonator nasal_r;
    r1.configure_bandpass(sample_rate, f1, eco ? 4.2 : 5.6);
    r2.configure_bandpass(sample_rate, f2, eco ? 5.0 : 7.2);
    r3.configure_bandpass(sample_rate, f3, studio ? 8.8 : 7.0);
    nasal_r.configure_bandpass(sample_rate, 280.0 + warmth * 70.0, 3.2);
    double previous_glottal = 0.0;
    double noise_low = 0.0;

    for (int i = 0; i < event_samples; ++i) {
      const double t = static_cast<double>(i) * inv_sample_rate;
      const double attack = std::min(1.0, i / (sample_rate * 0.035));
      const double release =
          std::min(1.0, (event_samples - i) / (sample_rate * 0.075));
      const double env = smoothstep(std::min(attack, release));
      const double vibrato = fast_sin_phase(vib_phase) * (2.0 + clarity * 2.6);
      const double phrase = fast_sin_phase(phrase_phase);
      const double hz = base + vibrato + phrase * (5.2 + event.articulation * 3.8);
      const double inc1 = kTwoPi * hz * inv_sample_rate;

      const double mouth_gate =
          eco ? 0.84 : (0.62 + 0.38 * smoothstep(0.5 + 0.5 * fast_sin_phase(gate_phase)));
      const double raw_glottal = glottal_pulse(phase1);
      const double glottal_edge = raw_glottal - previous_glottal;
      previous_glottal = raw_glottal;
      const double harmonic_glottal =
          glottal_edge * (1.28 + clarity * 0.34) + raw_glottal * 0.34;
      double voiced_sample =
          r1.process(harmonic_glottal) * (1.18 + warmth * 0.25) +
          r2.process(harmonic_glottal) * (0.82 + clarity * 0.24) +
          r3.process(harmonic_glottal) * (studio ? 0.48 : 0.36);

      const uint32_t noise_bits = xorshift32(&rng);
      const double white =
          (static_cast<double>(noise_bits & 0xFFFF) / 32767.5 - 1.0);
      noise_low = noise_low * 0.72 + white * 0.28;
      const double hiss = (white - noise_low) * breath;
      const double aspiration = noise_low * breath * 0.38;
      const double plosive_open =
          event.plosive > 0.0 ? smoothstep((t - 0.012) / 0.026) : 1.0;
      const double burst_time = std::max(0.0, t - 0.010);
      const double plosive_burst =
          event.plosive * std::exp(-burst_time * (eco ? 55.0 : 72.0));
      const double fricative_air =
          event.fricative * (0.42 + 0.30 * pack.brightness) *
          (0.72 + 0.28 * smoothstep(env));
      const double nasal_hum =
          event.nasal * nasal_r.process(harmonic_glottal + aspiration * 0.35) *
          0.50;
      const double consonant_burst =
          event.consonant * (std::exp(-t * (eco ? 34.0 : 48.0)) + 0.12 * (1.0 - env));
      double sample = voiced_sample * event.voicing * plosive_open;
      sample += nasal_hum * event.voicing;
      sample += aspiration * (eco ? 0.05 : (studio ? 0.10 : 0.075));
      sample += hiss * fricative_air * (1.30 + clarity * 0.28);
      sample += hiss * plosive_burst * (1.15 + event.articulation);
      sample += hiss * consonant_burst * (pack.speaker ? 1.28 : 0.98);

      const double consonant_gate =
          mouth_gate * (0.78 + event.articulation * 0.24);
      sample *= consonant_gate;
      sample *= env * (0.16 + event.energy * 0.36);

      smooth = smooth * (0.62 + (1.0 - event.articulation) * 0.10) +
               sample * (0.38 - (1.0 - event.articulation) * 0.10);
      const double codec = softclip(smooth * (studio ? 1.72 : 1.55));
      const int16_t pcm =
          static_cast<int16_t>(std::max(-32767.0, std::min(32767.0, codec * 32767.0)));
      pcm_writer.write_i16(pcm);

      advance_phase(&phase1, inc1);
      advance_phase(&vib_phase, vib_increment);
      advance_phase(&phrase_phase, phrase_increment);
      if (!eco) advance_phase(&gate_phase, gate_increment);
    }

    const int pause_samples =
        std::max(0, static_cast<int>(event.pause_seconds * sample_rate));
    pcm_writer.write_silence(static_cast<uint32_t>(pause_samples));
  }

  pcm_writer.flush();
  write_wav_header(out, static_cast<uint32_t>(sample_rate), pcm_writer.samples());
  if (pcm_writer.samples() > 0) {
    write_render_trace_json(
        events, pack, output_wav, sample_rate, performance_flags, pcm_writer.samples());
    return 1;
  }
  return 0;
}

std::string json_escape(const std::string& value) {
  std::string out;
  out.reserve(value.size() + 8);
  for (size_t i = 0; i < value.size(); ++i) {
    const char ch = value[i];
    if (ch == '\\' || ch == '"') {
      out.push_back('\\');
      out.push_back(ch);
    } else if (ch == '\n') {
      out += "\\n";
    } else if (ch == '\r') {
      out += "\\r";
    } else if (ch == '\t') {
      out += "\\t";
    } else {
      out.push_back(ch);
    }
  }
  return out;
}

int32_t render_wav_impl(
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
    int32_t error_len) {
  try {
    const std::string pack_dir_s = safe_string(pack_dir);
    const std::string script_s = safe_string(script);
    const std::string voice_s = safe_string(voice);
    const std::string style_s = safe_string(style);
    const std::string output_s = safe_string(output_wav);
    if (script_s.empty()) {
      set_error(error, error_len, "empty script");
      return 0;
    }
    if (output_s.empty()) {
      set_error(error, error_len, "empty output path");
      return 0;
    }

    int flags = performance_flags;
    if ((flags & (kRenderFlagEco | kRenderFlagBalanced | kRenderFlagStudio)) == 0) {
      flags = kRenderFlagBalanced;
    }

    const int sr_min = (flags & kRenderFlagEco) != 0 ? 12000 : 16000;
    const int sr_max = (flags & kRenderFlagStudio) != 0 ? 48000 : 32000;
    const int sr =
        sample_rate >= sr_min && sample_rate <= sr_max ? sample_rate : 22050;
    const int max_sec = max_seconds > 0 ? std::min(max_seconds, 900) : 180;
    const int event_limit = max_events > 0 ? max_events : 42;
    const PackProfile pack = load_pack_profile(pack_dir_s);
    const std::vector<Utterance> utterances = collect_utterances(script_s);
    const std::vector<BarkEvent> events = semantic_to_events(
        utterances, pack, voice_s, style_s, max_sec, flags, event_limit);
    if (events.empty()) {
      set_error(error, error_len, "no renderable events");
      return 0;
    }
    if (!render_events_to_wav(events, pack, output_s, sr, flags)) {
      set_error(error, error_len, "failed to write wav");
      return 0;
    }
    set_error(error, error_len, "");
    return pack.manifest_ok ? 2 : 1;
  } catch (const std::exception& ex) {
    set_error(error, error_len, ex.what());
    return 0;
  } catch (...) {
    set_error(error, error_len, "unknown native Bark render error");
    return 0;
  }
}

}  // namespace

NAZA_BARK_EXPORT int32_t naza_bark_probe(
    const char* pack_dir,
    char* out_json,
    int32_t out_json_len) {
  try {
    const PackProfile pack = load_pack_profile(safe_string(pack_dir));
    std::ostringstream json;
    json << "{"
         << "\"native\":\"naza_bark_ffi_v2_source_filter\","
         << "\"sourceFilterSpeech\":true,"
         << "\"fastOscillator\":false,"
         << "\"traceJson\":true,"
         << "\"pronunciationRules\":true,"
         << "\"profileCached\":" << (pack.cached ? "true" : "false") << ","
         << "\"manifestOk\":" << (pack.manifest_ok ? "true" : "false") << ","
         << "\"tensorCount\":" << pack.tensor_count << ","
         << "\"semantic\":" << (pack.semantic ? "true" : "false") << ","
         << "\"coarse\":" << (pack.coarse ? "true" : "false") << ","
         << "\"fine\":" << (pack.fine ? "true" : "false") << ","
         << "\"codec\":" << (pack.codec ? "true" : "false") << ","
         << "\"speaker\":" << (pack.speaker ? "true" : "false") << ","
         << "\"seed\":\"" << std::hex << pack.seed << std::dec << "\","
         << "\"warmth\":" << pack.warmth << ","
         << "\"clarity\":" << pack.clarity << ","
         << "\"density\":" << pack.density << ","
         << "\"pitchBias\":" << pack.pitch_bias << ","
         << "\"tractLength\":" << pack.tract_length << ","
         << "\"breathiness\":" << pack.breathiness << ","
         << "\"brightness\":" << pack.brightness << ","
         << "\"consonantGain\":" << pack.consonant_gain << ","
         << "\"articulation\":" << pack.articulation_bias << ","
         << "\"paceBias\":" << pack.pace_bias
         << "}";
    copy_c_string(json.str(), out_json, out_json_len);
    return pack.manifest_ok ? 1 : 0;
  } catch (const std::exception& ex) {
    (void)ex;
    copy_c_string(
        "{\"native\":\"naza_bark_ffi_v2_source_filter\",\"error\":\"probe failed\"}",
        out_json,
        out_json_len);
    return -1;
  } catch (...) {
    copy_c_string(
        "{\"native\":\"naza_bark_ffi_v2_source_filter\",\"error\":\"unknown probe error\"}",
        out_json,
        out_json_len);
    return -1;
  }
}

NAZA_BARK_EXPORT int32_t naza_bark_render_wav(
    const char* pack_dir,
    const char* script,
    const char* voice,
    const char* style,
    const char* output_wav,
    int32_t sample_rate,
    int32_t max_seconds,
    char* error,
    int32_t error_len) {
  return render_wav_impl(
      pack_dir,
      script,
      voice,
      style,
      output_wav,
      sample_rate,
      max_seconds,
      kRenderFlagBalanced,
      96,
      error,
      error_len);
}

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
    int32_t error_len) {
  return render_wav_impl(
      pack_dir,
      script,
      voice,
      style,
      output_wav,
      sample_rate,
      max_seconds,
      performance_flags,
      max_events,
      error,
      error_len);
}
