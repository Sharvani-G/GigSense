# GigSense — Project Hand-off Context & Current Architecture

This document serves as a detailed narrative of the system's current architecture, recent implementation changes, and verification checks. Use this to transition to the next phase of development with zero misunderstanding.

---

## 1. Project Overview & Architecture
* **Frontend:** A cross-platform Flutter mobile application renamed **GigSense** (updated across Android configurations and iOS configurations).
* **Backend:** A local FastAPI Python application (`backend/main.py`) running on port `8000`.
* **Database:** Firebase Firestore is used for all state persistence (storing user documents, logged jobs, chat session history, and application settings).
* **Live Tunneling:** An active ngrok tunnel forwards public requests from `https://evolve-eternity-epidural.ngrok-free.dev` to the local backend, allowing physical devices over cellular connections to communicate with the FastAPI server.
* **Whisper Model (STT):** A `faster_whisper` "small" model is initialized globally on CPU in the backend (`backend/stt.py`) with `int8` quantization for standard laptop CPU transcription.

---

## 2. Database Schema & Profile State
The user profile schema in Firestore `/users/{uid}` persists:
* `name` (String)
* `phoneNumber` (normalized 10-digit number)
* `workerType` (e.g., `cab_driver`, `delivery_rider`, `other_gig_worker`)
* `language` (e.g., `en`, `hi`, `kn`, `te`, `ta`, `ml`)
* `sos_contacts` (List of Map items containing `name` and `phone`)
* `savings_goal` (Integer target value)

---

## 3. Language Prompts & Localization Parity
* **System Prompt Constraints:**
  * Updated `backend/llm.py` (`get_chat_system_prompt`) to enforce strict script and language rules:
    * The LLM prioritizes the language of the user's most recent message over the stored language preference.
    * If the user message is written in English, the response is in English.
    * If the user message is written in a regional language (native script or romanized Latin letters), the response is in fluent regional language using its **native script** (never romanized).
* **UI Localization System:**
  * The app utilizes `StringsProvider.instance` (`app/lib/i18n/strings.dart`) to fetch localized translations.
  * Audits are managed via `scripts/audit_locales.py` to ensure 100% key parity across all 6 regional languages.
  * Hardcoded strings in walkthroughs, SOS settings, and manual logs have been fully extracted.

---

## 4. Part 1 — Onboarding Walkthrough Markdown Fix
* **The Problem:** The help screen (`HelpWalkthroughScreen`) displayed raw Markdown asterisks (`**`) instead of formatted bold text because it loaded descriptions into a standard Flutter `Text` widget.
* **The Solution:** Modified [help_walkthrough_screen.dart](file:///C:/Users/gjaya/OneDrive/Desktop/GIG/GigSense/app/lib/screens/help_walkthrough_screen.dart) to route all feature descriptions through the existing `PlayfulMarkdownText` widget, resolving the formatting issues.

---

## 5. Part 2 & 3 — UI Contrast Enhancements
All components on the Log Job screen and settings sheets have been updated to exceed WCAG compliance thresholds (minimum 4.5:1 ratio for body text, 3:1 for large elements/icons):
* **Input Placeholders:** Upgraded `PlayfulInput` hint style from `#94A3B8` (2.22:1) to `PlayfulColors.foreground.withOpacity(0.75)` (>5:1).
* **Toggles & Unit Selectors:** Modified the selected pill/unit backgrounds in `PlayfulToggle` and `PlayfulUnitInput` to use `PlayfulColors.foreground` near-black instead of violet (`PlayfulColors.accent`), guaranteeing high-contrast white text legibility (10.9:1).
* **Mic & Language Indicators:**
  * Upgraded `PlayfulMicButton` language indicator text color to `PlayfulColors.foreground` on hot pink background (4.9:1).
  * Programmed the mic icon to dynamically swap from white to `PlayfulColors.foreground` when in the yellow/tertiary listening state (>6:1).
* **Disabled States:** Upgraded `PlayfulButton` disabled text color to `PlayfulColors.foreground` (5.8:1).
* **Cancel Buttons:** Set cancel buttons inside settings sheet dialogs, long-trip warnings, and permissions modals to `PlayfulColors.foreground` (>10:1).
* **Helper Descriptions:** Swapped OCR scan descriptions (`_fareOcrNote` etc.) and the form page subtitle to `PlayfulColors.foreground` (>10:1).

---

## 6. Part 4 & 5 — Voice Input Failures & Emulator Connectivity
* **OS Declarations:** 
  * Declared `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` keys with descriptive justification strings in the iOS [Info.plist](file:///C:/Users/gjaya/OneDrive/Desktop/GIG/GigSense/app/ios/Runner/Info.plist) to prevent runtime crashes.
  * Confirmed that `android.permission.RECORD_AUDIO` is declared and runtime permission hooks check for denials.
* **Silent Failure Prevention:** 
  * Handled empty speech-recognition returns in `PlayfulMicButton`. If Whisper processes silent recording and yields a blank transcript, the app triggers the error SnackBar ("Didn't catch that clearly, please try again") instead of stalling silently.
* **Emulator Loopback Translation:**
  * To fix network timeout/connection errors inside local development environments (where `127.0.0.1` refers to the emulator itself), added translation logic inside [playful_widgets.dart](file:///C:/Users/gjaya/OneDrive/Desktop/GIG/GigSense/app/lib/screens/playful_widgets.dart), [log_job_screen.dart](file:///C:/Users/gjaya/OneDrive/Desktop/GIG/GigSense/app/lib/screens/log_job_screen.dart), [chat_screen.dart](file:///C:/Users/gjaya/OneDrive/Desktop/GIG/GigSense/app/lib/screens/chat_screen.dart), [home_screen.dart](file:///C:/Users/gjaya/OneDrive/Desktop/GIG/GigSense/app/lib/screens/home_screen.dart), [batch_confirm_screen.dart](file:///C:/Users/gjaya/OneDrive/Desktop/GIG/GigSense/app/lib/screens/batch_confirm_screen.dart), and [settings_screen.dart](file:///C:/Users/gjaya/OneDrive/Desktop/GIG/GigSense/app/lib/screens/settings_screen.dart).
  * If the app runs on Android and the endpoint starts with `127.0.0.1` or `localhost`, the URL is rewritten to `10.0.2.2` (mapping to the host developer loopback machine).

---

## 7. Status & Verification Results
1. **Locale Key Parity:** `python scripts/audit_locales.py` passes successfully with `100% key parity`.
2. **Flutter Widget Tests:** `flutter test` completes successfully.
3. **Application Build:** Clean compiled release APK successfully saved at: [GigSense-release.apk](file:///c:/Users/gjaya/OneDrive/Desktop/GIG/GigSense/GigSense-release.apk) (56.9MB).
