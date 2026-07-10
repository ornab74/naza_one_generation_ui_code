# Privacy Policy for Naza One

**Effective date:** July 10, 2026
**Last updated:** July 10, 2026

Naza One (“Naza One,” “the App,” “we,” “us,” or “our”) is a local-first artificial intelligence assistant for Android. This Privacy Policy explains how Naza One accesses, processes, stores, transmits, and protects information when you use the App.

This policy applies to the Android version of Naza One associated with the package identifier `com.qroadscan.lightcal` and the Naza One source-code project.

## 1. Privacy Summary

Naza One is designed to perform its primary artificial intelligence functions locally on your device.

Naza One does not require an account and does not include advertising, behavioral tracking, a cloud AI chat service, or a developer-operated server that receives your conversations.

The App may nevertheless connect to the internet for limited purposes:

* downloading the local Gemma model from Hugging Face;
* downloading optional Bark voice-model resources from GitHub;
* using an Android speech-recognition or text-to-speech provider when you choose voice features; and
* participating in Android backup or device-transfer services, depending on your device and settings.

## 2. Information You Provide or Create

### 2.1 Chat content

When you type a prompt, message, instruction, or other text into Naza One, the App processes that content locally to produce a response.

The App may store:

* your prompts;
* locally generated assistant responses;
* timestamps;
* internal routing labels and confidence scores;
* summaries, keywords, tags, and local vector-memory representations derived from conversations.

Chat history and vector memory are used to provide conversation history, context, continuity, and local memory features.

### 2.2 Scanner information

Naza One includes road and food/water scanner tools. Information manually entered into these tools may be stored as local drafts. Depending on what you enter, this information could include personal, safety-related, health-related, food-related, location-related, or other sensitive details.

The App does not automatically access GPS location, the camera, contacts, photos, or files for these scanner tools in the reviewed version. Scanner information is based on information you choose to enter.

### 2.3 Voice input

When you activate a voice-input feature, Naza One requests access to your device’s microphone and uses Android’s speech-recognition service to convert speech into text.

Naza One requests offline recognition when supported. However, the selected Android speech-recognition provider may ignore that preference or may transmit audio to remote servers. The speech provider, device manufacturer, operating-system provider, or recognition-engine provider may process audio, transcripts, language information, confidence scores, and technical data under its own privacy policy.

Naza One receives the resulting transcript and uses it as local input for the App.

Naza One does not continuously record audio in the background. Microphone access is intended to occur only when you intentionally activate a voice-listening feature.

### 2.4 Text-to-speech and voice output

When you use spoken-response features, Naza One may send locally generated response text to the Android text-to-speech engine selected on your device.

Text-to-speech processing may occur locally or through the selected provider’s service. The text-to-speech provider may process text and technical information according to its own privacy policy.

### 2.5 Generated audio and scripts

The Bark/Convo feature can create scripts and WAV audio files locally. Generated scripts, audio files, render traces, and cache metadata may be stored in the App’s private support directory so the App can replay or reuse previous renders.

Generated Convo WAV files and associated script or cache metadata are not protected by the App’s AES-encrypted chat vault in the reviewed version. They remain protected by Android’s app sandbox and device security, but a person or process with sufficient access to the device or its backups may be able to access them.

Do not include information in a Convo request that you would not want stored as a local audio or script file.

## 3. Technical and Network Information

### 3.1 Local AI model downloads

The Gemma model is not bundled with the App. When the model is not already installed, Naza One may download it over HTTPS from Hugging Face and store it in the App’s private support directory.

The App verifies the downloaded model with a pinned SHA-256 hash before use.

The App does not include your prompts, conversations, scanner entries, or generated responses in the model-download request. However, Hugging Face and its content-delivery providers may automatically receive standard network information such as:

* your IP address;
* request date and time;
* requested file;
* user-agent information;
* network and connection metadata.

### 3.2 Bark voice-resource downloads

When you install or use optional Bark/Convo resources, Naza One may download a BarkPack index and model files over HTTPS from GitHub or GitHub-operated content-delivery hosts.

The App validates download hosts, file names, sizes, and SHA-256 hashes before installing those resources.

The App does not intentionally include your prompts, conversations, or generated scripts in BarkPack download requests. GitHub and its infrastructure providers may receive standard network information such as your IP address, request time, requested resource, user-agent information, and connection metadata.

### 3.3 Local diagnostics

Naza One creates local runtime status information, verification records, model-status information, generation settings, backend preferences, performance preferences, and local error messages. These records are used to operate, secure, and troubleshoot the App.

Naza One does not include an analytics or crash-reporting SDK in the reviewed version and does not automatically send these local diagnostics to the developer.

If you manually copy or share an error message, trace, screenshot, repository issue, or diagnostic file, the recipient will receive whatever information you choose to share.

## 4. Information Naza One Does Not Intentionally Collect

In the reviewed version, Naza One does not intentionally collect or access:

* your name or email address through an in-app account;
* passwords or authentication credentials;
* payment or financial information;
* advertising identifiers;
* precise or approximate GPS location;
* contacts or address-book information;
* call logs or SMS messages;
* photos or videos;
* camera data;
* browsing history;
* a list of installed apps;
* biometric identifiers;
* persistent device identifiers for advertising;
* analytics profiles;
* advertising data.

Naza One does not sell personal information and does not use personal information for targeted advertising.

## 5. How Information Is Used

Information processed by Naza One is used to:

* generate local AI responses;
* maintain optional chat history and conversational continuity;
* create and retrieve local vector memory;
* process road and food/water scanner entries;
* convert speech to text when requested;
* speak responses when requested;
* generate and cache local scripts and audio;
* save settings and preferences;
* verify downloaded model resources;
* maintain security and integrity;
* diagnose local failures and display status information.

## 6. Local Storage and Security

Naza One stores data in Android app-private storage.

The reviewed version uses AES-256-GCM encryption for:

* saved chat history;
* local vector-memory content;
* scanner drafts;
* certain verification and settings records.

Encryption keys are generated and stored within the App’s private support storage. This helps protect stored content from ordinary access, but it is not a guarantee against all forms of device compromise, malware, root access, forensic access, operating-system vulnerabilities, physical access, or backup access.

Some local files are not encrypted by the App’s AES vault, including generated WAV audio, Convo script/cache metadata, downloaded model resources, and some preference or runtime files.

Network model downloads use HTTPS and cryptographic file verification. No storage or transmission method is completely secure.

You are responsible for maintaining appropriate device protections, such as a screen lock, current security updates, storage encryption, and control over who can access your device.

## 7. Android Backup and Device Transfer

Depending on your Android version, device manufacturer, Google account, and backup settings, Android may back up or transfer some App data to Google Drive or another device.

This may include files from the App’s private storage unless they are excluded by Android backup rules. Backup data is handled by Android, Google, the device manufacturer, or the applicable backup provider under their respective privacy policies.

Disabling or deleting information inside Naza One may not immediately delete an older backup copy. Backup retention and deletion are controlled by the applicable backup provider and your device or account settings.

## 8. Sharing and Disclosure

Naza One does not sell, rent, or trade your personal information.

Information may be processed or disclosed in the following limited circumstances:

1. **At your direction.** Information is shared when you intentionally copy, export, post, send, or otherwise disclose it.
2. **Device speech providers.** Audio or text may be handled by the Android speech-recognition or text-to-speech provider when you use voice features.
3. **Download providers.** Hugging Face, GitHub, and their delivery infrastructure receive standard network requests when model resources are downloaded.
4. **Backup and device-transfer providers.** Android or another provider may back up or transfer App data according to device settings.
5. **Legal and safety reasons.** We may disclose information actually available to us if required by applicable law, legal process, or a valid governmental request, or when reasonably necessary to protect rights, safety, and security. Because Naza One is local-first and does not operate a conversation server, we ordinarily do not possess your locally stored conversations.

## 9. Retention

Naza One retains local data for as long as needed to provide the feature or until it is deleted, overwritten, automatically trimmed, the App’s storage is cleared, or the App is uninstalled.

The App applies internal limits to some records, including chat history, vector memory, and render caches. Other files, including scanner drafts, downloaded models, generated audio, settings, and support files, may remain until you remove them or clear the App’s storage.

Third-party speech, download, backup, and device-transfer providers determine their own retention periods.

## 10. Deleting Your Information

Naza One does not use user accounts, so there is no App account to delete.

Depending on the version and available controls, you may:

* clear saved chat history inside the App;
* disable or clear local vector memory inside the App;
* overwrite or remove scanner entries where controls are available;
* revoke microphone permission in Android settings;
* clear all Naza One storage through Android Settings;
* uninstall Naza One.

To remove all on-device App data, use:

**Android Settings → Apps → Naza One → Storage & cache → Clear storage**

Menu wording may vary by Android version and device manufacturer.

Clearing storage or uninstalling the App removes the active on-device copy, subject to Android behavior. Backup copies may remain with the applicable backup provider until deleted or expired under that provider’s rules.

For privacy questions or deletion assistance, contact us using the information in Section 15.

## 11. Permissions

### Internet

Internet permission is used to download verified AI model and voice-resource files and may also be used by the device’s speech provider.

### Microphone

Microphone permission is used only for voice-input functionality that you activate. You may deny or revoke this permission. Text-based features remain available without microphone access, although voice input will not function.

## 12. Children’s Privacy

Naza One is not directed to children under 13 and is not designed as a child-directed service.

We do not knowingly operate a server that collects personal information from children. Parents or guardians who believe a child has disclosed personal information through a third-party speech, backup, or sharing service should contact that provider and may also contact us.

## 13. Your Privacy Choices and Rights

You can choose whether to:

* type or speak a prompt;
* enable microphone access;
* enable or disable local vector memory;
* retain or clear chat history;
* install optional Bark voice resources;
* use Android backup;
* share diagnostics or generated content.

Depending on your location, privacy law may provide rights concerning access, correction, deletion, restriction, objection, portability, or withdrawal of consent.

Because Naza One’s primary user content is stored locally and is not transmitted to a developer-operated account or server, the developer may not have possession of or access to that content. The most direct method of exercising control is through the App and Android storage settings.

## 14. Changes to This Privacy Policy

We may update this Privacy Policy when Naza One’s features, dependencies, permissions, data practices, or legal obligations change.

The updated policy will display a revised “Last updated” date. Material changes should also be reflected in the App, its store listing, and its Google Play Data safety disclosures.

## 15. Contact

**App:** Naza One
**Privacy contact:** [janulis@graylan@gmail.com](mailto:janulisgraylan@gmail.com)
**Source-code project:** https://github.com/ornab74/naza_one_generation_ui_code

Please do not include passwords, financial information, private medical records, government identification numbers, or other highly sensitive information in a public GitHub issue.
