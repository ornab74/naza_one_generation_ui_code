# Privacy Policy for Naza One

**Effective date:** July 14, 2026

**Last updated:** July 18, 2026

Naza One (the “App”) is a local-first artificial intelligence assistant. This
policy describes how the App processes, stores, and protects information. It
applies to the Naza One source project and its supported desktop and mobile
builds, including the Android package `com.qroadscan.lightcal`.

## 1. Summary

Naza One performs chat, scanner, food-vision, memory, and model inference on your device. It
does not require an account and does not contain advertising, behavioral
tracking, a developer-operated chat server, microphone features, or voice
generation.

The App connects to the internet to download its local AI model when a verified
copy is not already available. Automatic Android cloud backup and
device-to-device transfer are disabled for App-private data. You may still
create and move an encrypted recovery export yourself.

## 2. Information you provide or create

### Chat and local memory

Text you enter is processed locally. The App may retain prompts, locally
generated responses, timestamps, routing labels, summaries, tags, scanner
drafts, and local vector-memory representations to provide history and
continuity.

### Road and text scanners

Scanner entries are information you intentionally provide. Depending on the
entry, they may contain location descriptions, health or safety observations,
food details, or other sensitive text. The App does not automatically acquire
GPS location or contacts.

### Images you capture or select

If you attach an image to a supported prompt, the system picker grants the App
access to that selected file so it can be processed by the local model. The App
does not scan your photo library or other files. On supported mobile devices,
you may also choose to open the camera for a fridge or bake-completion photo.

Food photos are converted to bounded, metadata-free PNG images before local
analysis. When you analyze and save a fridge or bake entry, the normalized
photo and its structured result are retained as encrypted SQLite records so
you can revisit the food history or re-run an interrupted analysis. Chat image
history may retain the selected file's name and dimensions. Images are not
uploaded to a developer-operated service.

### Passwords and recovery material

The boot password is used locally to derive an encryption key with Argon2id. It
is not stored or transmitted, and the developer cannot recover it. If you
set up post-quantum recovery, only its public enrollment state is retained in
the vault. The password-protected private recovery key kit and encrypted vault
backup are exported as separate local files. They remain local unless you
choose to move, copy, or share them.

## 3. Model downloads and network data

The Gemma model is downloaded over HTTPS from a revision-pinned Hugging Face
URL. The App verifies the artifact against a pinned SHA-256 digest before use.
The request does not intentionally contain prompts, conversations, scanner
entries, images, or generated responses.

Hugging Face and its delivery providers may receive normal connection data,
such as your IP address, request time, requested file, user-agent string, and
network metadata, under their own policies.

The App has no analytics or crash-reporting SDK and does not automatically send
local diagnostics to the developer. If you share a screenshot, error, log, or
issue report, its recipient receives the information you include.

## 4. Local storage and security

The App stores data in its private support directory. User records, including
history, memory, drafts, settings, and model-integrity attestations, are stored
in SQLite with independently authenticated AES-256-GCM ciphertexts. Logical
record identifiers are HMAC-derived rather than stored in plaintext.

By default, each fresh App process requires the boot password before the vault
or the rest of the App is opened. The password derives a key-encryption key that
unwraps a random vault-unlock key; that key unwraps versioned data-encryption
keys. Password changes rewrap key material, while transactional key rotation
re-encrypts records under a new data key.

You can opt out of the per-process password prompt. In that mode, a random
unlock secret is stored in the operating system's secure credential store; the
App does not silently fall back to a plaintext key when that service is
unavailable.

The SQLite file is protected at the record level, not encrypted page by page.
Someone who obtains it may still infer database schema, approximate record
count, ciphertext sizes, key-version identifiers, and update times. Downloaded
model files and some non-secret runtime metadata are not AES-encrypted. Device
compromise, malware, root or administrator access, keylogging, a modified App,
or access while the vault is unlocked can defeat these protections.

The App stores an encrypted trust attestation after a model artifact passes its
SHA-256 check. An unchanged artifact can use that attestation instead of being
hashed on every boot or message. A changed or unauthenticated artifact is
verified again and rejected if it does not match.

No storage system is completely secure. Use a device screen lock, current
security updates, and appropriate control over physical and administrative
access.

## 5. Encrypted backup and recovery

Post-quantum recovery is enabled as the default recovery policy for new and
migrated vaults, but it does not become ready until you complete setup and
verify the exported files. The current format uses hybrid ML-KEM-1024 and
X25519 key establishment, ML-DSA-87 backup-origin signatures, HKDF-SHA-512,
AES-256-GCM, and an Argon2id-protected private recovery key kit. Creating a new
backup therefore requires the separate kit and recovery password. Recovery is
separate from normal local database unlock and does not transmit a backup. The
App can still read its earlier combined ML-KEM-768 recovery format for
compatibility.

Recovery is useful only if the password-protected private recovery key kit is
kept separately from the encrypted backup. Anyone who obtains both files and
the recovery password may decrypt the exported content. Losing any required
file or the password can make the backup unrecoverable.

## 6. Information the App does not intentionally collect

Naza One does not intentionally collect:

- account names or email addresses;
- payment information or advertising identifiers;
- contacts, call logs, SMS messages, or browsing history;
- microphone recordings or speech transcripts;
- GPS location or biometric identifiers;
- a list of installed apps;
- advertising or analytics profiles.

Naza One does not sell personal information or use it for targeted advertising.

## 7. Use of information

Locally processed information is used to:

- generate AI responses and scanner results;
- maintain history and optional local memory;
- restore drafts and preferences;
- process an image you deliberately capture or select;
- maintain an encrypted fridge and bake-analysis history;
- verify the downloaded model and maintain security state;
- display local status, errors, and diagnostics;
- create an encrypted backup when you request one.

## 8. Sharing and third parties

The App does not sell, rent, or trade personal information. Information may be
handled in these limited circumstances:

1. **At your direction.** You copy, export, post, or otherwise share content,
   diagnostics, recovery material, or an encrypted backup.
2. **Model delivery.** Hugging Face and its infrastructure receive the network
   request used to download the model.
3. **Operating-system services.** The camera, system file or photo picker, and
   secure credential store operate under the platform provider's policies.
4. **Legal and safety matters.** The developer may disclose information
   actually available to them when required by valid legal process or needed to
   protect rights and safety. Because there is no conversation server, the
   developer ordinarily does not possess locally stored user content.

## 9. Backup and device transfer

Automatic Android cloud backup and Android device-to-device transfer are
disabled for App-private files, databases, shared preferences, and external
App storage. This reduces unintended copying but is not a guarantee against a
compromised device, administrator tools, manufacturer behavior, or copies made
outside the App. Older provider-managed copies created by a previous App
version may remain subject to the provider's retention rules.

Treat exported recovery files as sensitive. Store encrypted backups separately
from their private recovery material and passwords.

## 10. Retention and deletion

Local data remains until it is deleted, overwritten, automatically trimmed,
App storage is cleared, or the App is uninstalled. The model and settings may
remain until App storage is cleared. User-exported recovery files remain where
you placed them, and any older provider-managed copies follow the provider's
retention rules.

There is no App account to delete. Available controls may let you clear history
or memory. To remove all active on-device data, clear Naza One's application
storage in system settings or uninstall the App. Menu wording varies by
platform. Secure deletion from flash storage and deletion of prior backups
cannot be guaranteed.

## 11. Permissions

- **Internet:** downloads the verified local AI model.
- **Camera (when you choose it):** captures a fridge or bake-completion image
  for local food analysis on supported mobile devices.
- **Files or photos selected by you:** the system picker provides access only
  to the item you choose, subject to platform behavior.

Text features do not require microphone access.

## 12. Children

Naza One is not directed to children under 13. The developer does not knowingly
operate a server that collects children's personal information through the
App. Parents or guardians should manage device access, backups, and anything a
child intentionally shares.

## 13. Your choices and rights

You can decide whether to retain local history or memory, capture or attach an
image, require a boot password, complete recovery setup, export recovery
material, or share content. Privacy law may also provide rights of access, correction,
deletion, restriction, objection, or portability.

Because primary user content remains on your device, the developer generally
cannot access, correct, or delete it remotely. Use the App and platform storage
controls to manage that content.

## 14. Policy changes

This policy may change when features, dependencies, permissions, or data
practices change. The revision will show an updated date and should be reflected
in relevant store disclosures.

## 15. Contact

**App:** Naza One

**Privacy contact:** [janulisgraylan@gmail.com](mailto:janulisgraylan@gmail.com)

**Source project:** <https://github.com/ornab74/naza_one_generation_ui_code>

Do not put passwords, recovery private keys, medical records, government
identifiers, or other highly sensitive information in a public issue.
