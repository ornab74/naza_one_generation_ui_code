# MSL-PQ Reader Firmware Targets

`research_reader` is a buildable ESP32-S3 laboratory collector. It exports all
12 AS7341 readings as bounded JSON and therefore cannot be used for
authentication. `locked_reader` is a deliberate fail-closed production target:
it builds, but refuses authentication until a reviewed secure-element/native
backend replaces the repository stub.

The separation is a security boundary. Never add a build flag that enables the
research reader as `MslSecureReader`, and never provision an attestation or
surface key as a source-code constant.

Required Arduino libraries for the research target:

- Adafruit AS7341
- Adafruit NeoPixel
- ESP32Servo
- Adafruit BusIO (dependency)

Wire the AS7341 over I2C, RGBW Jewel data to GPIO 5, polarizer servo signal to
GPIO 6 with separate regulated 5 V power and common ground, and a normally
closed enclosure switch to GPIO 9. Confirm pins against the exact ESP32 board
before applying power.

Serial commands are newline terminated:

```text
HELLO
RESET,30000
STEP,1,255,0,0,0,64,0,300
STEP,2,0,255,0,0,64,45,300
```

See the main repository README and
`docs/msl-pq-laboratory-validation-spec.md` for the complete build and evidence
requirements.
