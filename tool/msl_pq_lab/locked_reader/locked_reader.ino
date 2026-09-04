// MSL-PQ locked-reader firmware target.
//
// This target is intentionally fail-closed until a reviewed secure backend is
// installed. It must never be replaced by the research reader or by a compiled
// plaintext key. The backend must provide secure boot, encrypted firmware,
// monotonic state, hardware attestation, internal fuzzy reconstruction, and a
// non-exportable application-key operation.
#include <Arduino.h>

constexpr uint32_t BAUD = 115200;
constexpr uint8_t LID_PIN = 9;

// Set by a board-specific secure-element integration only after provisioning.
// The repository default remains false so an accidental upload cannot claim
// production readiness.
bool secureBackendProvisioned() { return false; }

void setup() {
  pinMode(LID_PIN, INPUT_PULLUP);
  Serial.begin(BAUD);
  delay(100);
  Serial.println(
      "{\"type\":\"ready\",\"mode\":\"locked\","
      "\"authentication_enabled\":false}");
}

void loop() {
  if (digitalRead(LID_PIN) != LOW || !secureBackendProvisioned()) {
    if (Serial.available()) {
      while (Serial.available()) Serial.read();
      Serial.println(
          "{\"type\":\"error\",\"code\":"
          "\"SECURE_BACKEND_NOT_PROVISIONED\"}");
    }
    delay(10);
    return;
  }

  // Unreachable in the repository build. A production board adapter must
  // replace this target and pass the laboratory gates before enabling auth.
  delay(1000);
}
