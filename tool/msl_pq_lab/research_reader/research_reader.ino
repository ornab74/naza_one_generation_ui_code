// MSL-PQ laboratory reader for ESP32-S3 + AS7341 + RGBW NeoPixel + servo.
// LABORATORY ONLY: exports raw channels and MUST NOT authenticate anything.
#include <Adafruit_AS7341.h>
#include <Adafruit_NeoPixel.h>
#include <ESP32Servo.h>
#include <Wire.h>

constexpr uint32_t BAUD = 115200;
constexpr uint8_t PIXEL_PIN = 5;
constexpr uint8_t PIXEL_COUNT = 7;
constexpr uint8_t SERVO_PIN = 6;
constexpr uint8_t LID_PIN = 9;
constexpr size_t MAX_COMMAND = 160;

Adafruit_AS7341 sensor;
Adafruit_NeoPixel pixels(PIXEL_COUNT, PIXEL_PIN, NEO_GRBW + NEO_KHZ800);
Servo polarizer;
char commandBuffer[MAX_COMMAND + 1];
size_t commandLength = 0;

void lightsOff() {
  pixels.clear();
  pixels.show();
}

void fail(const char *code) {
  lightsOff();
  Serial.print("{\"type\":\"error\",\"code\":\"");
  Serial.print(code);
  Serial.println("\"}");
}

bool lidClosed() { return digitalRead(LID_PIN) == LOW; }

void emitSample(unsigned long sequence, int polarization, int durationMs,
                const uint16_t readings[12]) {
  bool saturated = false;
  for (int i = 0; i < 12; ++i) saturated |= readings[i] >= 65500;
  const bool underexposed = readings[10] < 5;
  Serial.print("{\"type\":\"sample\",\"sequence\":");
  Serial.print(sequence);
  Serial.print(",\"channels\":[");
  for (int i = 0; i < 12; ++i) {
    if (i) Serial.print(',');
    Serial.print(readings[i]);
  }
  Serial.print("],\"polarization_deg\":");
  Serial.print(polarization);
  Serial.print(",\"duration_ms\":");
  Serial.print(durationMs);
  Serial.print(",\"saturated\":");
  Serial.print(saturated ? "true" : "false");
  Serial.print(",\"underexposed\":");
  Serial.print(underexposed ? "true" : "false");
  Serial.println(",\"temperature_c\":null}");
}

void executeStep(char *line) {
  unsigned long sequence;
  int r, g, b, w, brightness, polarization, durationMs;
  if (sscanf(line, "STEP,%lu,%d,%d,%d,%d,%d,%d,%d", &sequence, &r, &g,
             &b, &w, &brightness, &polarization, &durationMs) != 8) {
    fail("BAD_COMMAND");
    return;
  }
  if (r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255 ||
      w < 0 || w > 255 || brightness < 1 || brightness > 192 ||
      polarization < 0 || polarization > 180 || durationMs < 10 ||
      durationMs > 10000) {
    fail("OUT_OF_RANGE");
    return;
  }
  if (!lidClosed()) {
    fail("LID_OPEN");
    return;
  }
  polarizer.write(polarization);
  delay(250);
  pixels.setBrightness(brightness);
  for (uint8_t i = 0; i < PIXEL_COUNT; ++i) {
    pixels.setPixelColor(i, pixels.Color(r, g, b, w));
  }
  pixels.show();
  delay(durationMs);
  uint16_t readings[12] = {0};
  const bool ok = sensor.readAllChannels(readings);
  lightsOff();
  if (!ok) {
    fail("SENSOR_READ");
    return;
  }
  emitSample(sequence, polarization, durationMs, readings);
}

void processCommand(char *line) {
  if (strcmp(line, "HELLO") == 0) {
    Serial.println("{\"type\":\"hello\",\"mode\":\"research\",\"protocol\":1}");
    return;
  }
  if (strncmp(line, "RESET,", 6) == 0) {
    const long resetMs = strtol(line + 6, nullptr, 10);
    if (resetMs < 1000 || resetMs > 120000) {
      fail("OUT_OF_RANGE");
      return;
    }
    lightsOff();
    delay(resetMs);
    Serial.println("{\"type\":\"reset\",\"ok\":true}");
    return;
  }
  if (strncmp(line, "STEP,", 5) == 0) {
    executeStep(line);
    return;
  }
  fail("UNKNOWN_COMMAND");
}

void setup() {
  pinMode(LID_PIN, INPUT_PULLUP);
  Serial.begin(BAUD);
  Wire.begin();
  pixels.begin();
  lightsOff();
  polarizer.attach(SERVO_PIN, 500, 2500);
  if (!sensor.begin()) {
    fail("AS7341_NOT_FOUND");
    while (true) delay(1000);
  }
  sensor.setATIME(100);
  sensor.setASTEP(999);
  sensor.setGain(AS7341_GAIN_128X);
  Serial.println("{\"type\":\"ready\",\"mode\":\"research\"}");
}

void loop() {
  if (!lidClosed()) lightsOff();
  while (Serial.available()) {
    const char c = static_cast<char>(Serial.read());
    if (c == '\n') {
      commandBuffer[commandLength] = '\0';
      if (commandLength) processCommand(commandBuffer);
      commandLength = 0;
    } else if (c != '\r') {
      if (commandLength >= MAX_COMMAND) {
        commandLength = 0;
        fail("COMMAND_TOO_LONG");
      } else {
        commandBuffer[commandLength++] = c;
      }
    }
  }
}
