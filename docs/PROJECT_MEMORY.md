# PROJECT MEMORY: GiGly (formerly GiGly)

## Project Overview
GiGly is a cross-platform mobile application and backend service built to empower gig workers (cab drivers, delivery riders, etc.) by tracking pay fairness, scanning screenshot receipts with OCR, logging trips via multilingual voice-first input, calculating fatigue nudges, offering localized smart AI coaching (GiGi), and providing safety features (SOS Alert Shield).

### Main Features
1. **Locality Fairness Map:** Live, reactive Firestore-backed map displaying pay fairness health (Fair, Underpaid, Mixed) across regions in Bengaluru.
2. **Log Trip & Voice-First Input:** Trip entry form with real-time unit conversion (km/m, min/hr) and slot-filling multilingual speech-to-text recognition supporting English, Hindi, Kannada, Telugu, Tamil, and Malayalam.
3. **Smarter OCR Scanner:** Scans trip screenshots, validates receipt relevance to prevent LLM hallucinations, and visualizes payout comparisons against community benchmarks on a clean OCR Result screen.
4. **GiGi Assistant:** Localized AI coach providing legal/financial help with persistent disclaimers and localized multilingual greetings.
5. **SOS Emergency Shield:** Configurable contacts list with a floating quick-trigger alert and automated emergency message broadcasts.
6. **Global Text Sizing:** Global accessibility font scale configuration (Small, Medium, Large).

### Current Project Status
All core modules (Map, Voice Logging, OCR Scanning, GiGi, SOS Alert) are stable, compiled, localized, and tested against regional key parities.

---

## Tech Stack
* **Frontend:** Flutter SDK (`>=3.12.0 <4.0.0`)
* **Backend:** FastAPI (Python `3.10+`)
* **Database:** Firebase Firestore
* **Speech to Text:** `faster_whisper` (small model running on CPU)
* **LLM Engine:** Google Gemini (via backend API integration)
* **Tunneling:** ngrok (forwarding local backend requests during real-device testing)

---

## Architecture

### Folder Structure
```
GiGly/
├── app/                       # Flutter Mobile Application
│   ├── android/               # Android native configuration
│   ├── ios/                   # iOS native configuration
│   ├── lib/
│   │   ├── main.dart          # Entry point, theme, and font scaler setup
│   │   ├── firebase_options.dart
│   │   ├── i18n/
│   │   │   └── strings.dart   # Localized translation tables
│   │   └── screens/           # UI Screens & Components
│   └── test/                  # Widget & unit tests
├── backend/                   # FastAPI Python Server
│   ├── main.py                # Server entry point & API endpoints
│   ├── llm.py                 # Gemini LLM helper functions & prompts
│   ├── ocr.py                 # OCR image processing helpers
│   ├── stt.py                 # Whisper voice transcription service
│   ├── safety.py              # SOS alert processing
│   ├── retriever.py           # Context retrieval for AI chat
│   └── schemas.py             # Pydantic data schemas
└── scripts/                   # Audits and setup scripts
    ├── audit_locales.py       # Checks localized key parity
    └── patch_ngrok.py         # Automates local proxy tunnels
```

### Important Modules
* **Strings System (`strings.dart`):** Central translation provider supporting `en`, `hi`, `kn`, `te`, `ta`, and `ml`. Key parity is strictly audited.
* **Playful Widgets (`playful_widgets.dart`):** Predefined design library implementing input fields, neubrutalist buttons, toggle pills, and custom bold Markdown widgets.

### Navigation
The navigation handles flow transitions from the `LoginScreen` or `OnboardingScreen` to the `HomeScreen` dashboard, which hosts sub-pages (Dashboard, History, Fairness Map, and GiGi).

### State Management
* App state is managed via Flutter's reactive stateful widgets (`StatefulWidget`) and Firestore's stream listeners (`StreamBuilder`) to update components immediately on collection writes.
* Font scaling uses a global accessibility setting initialized in `main.dart`.

---

## Database (Cloud Firestore)

### Collections & Schemas
1. **`users` (`/users/{uid}`):**
   * `name` (String)
   * `phoneNumber` (String, normalized 10-digit number)
   * `workerType` (String: `cab_driver`, `delivery_rider`, `other_gig_worker`)
   * `language` (String: `en`, `hi`, `kn`, `te`, `ta`, `ml`)
   * `sos_contacts` (List of Map items containing `name` and `phone`)
   * `savings_goal` (Integer)
2. **`jobs` (`/jobs/{jobId}`):**
   * `user_id` (String)
   * `platform` (String, e.g. `uber`, `zomato`)
   * `fare` (Double)
   * `distance_km` (Double)
   * `duration_min` (Double)
   * `expected_fare` (Double)
   * `is_underpaid` (Boolean)
   * `explanation` (String)
   * `source` (String: `manual`, `ocr`, `stt`)
   * `rate_source` (String: `fallback`, `community`)
   * `job_timestamp` (Timestamp/ServerTimestamp)
3. **`chats` (`/chats/{chatId}`):**
   * `user_id` (String)
   * `title` (String)
   * `created_at` (Timestamp)
   * `updated_at` (Timestamp)
   * **Subcollection `messages` (`/chats/{chatId}/messages/{messageId}`):**
     * `role` (String: `user`, `assistant`)
     * `content` (String)
     * `timestamp` (Timestamp)
 4. **`benchmarks` (`/benchmarks/{platformId}`):**
   * `displayName` (String)
   * `ratePerKm` (Double)
   * `ratePerMin` (Double)
   * `category` (String)
   * `sampleSize` (Integer)
   * `seedRate` (Map containing `rate_per_km` and `rate_per_min`)
   * `communityRate` (Map or Null)
 5. **`mapFairnessReports` (`/mapFairnessReports/{reportId}`):**
   * `isSeedData` (Boolean)
   * `platform` (String, e.g. `zomato`, `uber`)
   * `locality` (String, e.g. `koramangala`, `indiranagar`)
   * `timeOfDay` (String: `morning`, `evening`, `latenight`)
   * `fareActual` (Double)
   * `fareExpected` (Double)
   * `distanceKm` (Double)
   * `durationMin` (Double)
   * `reportedAt` (Timestamp/ServerTimestamp)

---

## APIs

### Internal Endpoints (FastAPI)
1. `POST /jobs/scan` -> Extracts text from payslip screenshots and structures data using Gemini.
2. `POST /stt` -> Audio file speech-to-text transcriber using CPU Whisper.
3. `POST /jobs/voice-parse` -> Slot-filler parsing entities from voice transcripts.
4. `POST /chat` -> Retrieves database contexts and responds with local system prompting.
5. `GET /weekly-insight` -> Weekly summary compiler.
6. `POST /admin/recalculate-benchmarks` -> Recalculates community benchmarks.
7. `POST /sos-alert` -> Sends alert packages.
8. `POST /fatigue-nudge` -> Verifies fatigue metrics.

### External APIs
* Firebase Authentication, Cloud Firestore.
* Gemini API (Google AI SDK).

---

## Environment
* **Flutter Environment:** `.env` at `app/.env` requires `API_URL` config pointing to the backend.
* **Backend Environment:** `.env` at `backend/.env` requires `FIREBASE_CREDENTIALS_PATH` (defaults to `firebase-service-account.json`).
* **Android Emulator Translation:** On mobile startup, localhost/127.0.0.1 references inside network calls are dynamically rewritten to `10.0.2.2` when executing on Android emulator environments.

---

## Coding Conventions
1. **Color Contrast Compliance:** All labels, input fields, toggles, indicators, and buttons must enforce WCAG 4.5:1 ratio (>3:1 for large elements) against backgrounds.
2. **Text Rendering:** Do not display raw Markdown characters (`**`) directly on screen; use `PlayfulMarkdownText` inside walkthrough or help descriptions.
3. **Emulator Compatibility:** Wrap local endpoint definitions in the loopback IP converter (`127.0.0.1` -> `10.0.2.2`) when running on Android.
4. **Language Rules:** AI prompts must prioritize the language script of the user's most recent message.

---

## Decisions Made
* **Authentication:** Uses Firebase Auth exclusively.
* **Storage:** Locally processed temp audio storage; remote logging writes to Firestore directly.
* **Chat streams:** UI queries Firestore stream updates for message feeds.
* **STT Validation:** Transcription returns returning blank/empty strings must invoke a visual SnackBar warning rather than executing silent code branches.
* **OS Setup:** Info.plist has explicitly declared keys for Microphone and Speech Recognition to avoid device rejections.

---

## Recent Changes
1. Decoupled the public Fairness Map collection by introducing `mapFairnessReports`, separating map metrics data entirely from user identity fields.
2. Configured manual, voice, and OCR logging screens to double-write to both `jobs` (private logs) and `mapFairnessReports` (anonymized logs).
3. Created an idempotent, repeatable database seeding script (`seed_map_reports.py`) to generate 150 skewed map coordinates report signals.
4. Replaced circular locality map markers with realistic boundary polygons and implemented point-in-polygon checks to trigger detail sheets on user location centering.
5. Swapped walkthrough text widgets for `PlayfulMarkdownText` to support bold tags.
6. Upgraded input placeholder styling colors in `PlayfulInput` to pass WCAG 4.5:1 contrast thresholds.
7. Upgraded `PlayfulToggle`, `PlayfulUnitInput`, and `PlayfulMicButton` background elements to pass WCAG color contrast criteria.
8. Corrected emergency contact and permission modal button styles.
9. Added runtime exception handling in STT uploads to alert users when whisper output is empty.
10. Implemented automatic loopback IP converter (`127.0.0.1` -> `10.0.2.2`) inside mobile endpoints on Android.
11. Declared `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` keys inside iOS `Info.plist`.
12. Imported missing localization elements in `settings_screen.dart` and `fairness_map_screen.dart`.
13. Added a new `ocr_result_screen.dart` to display clean receipt calculations comparing payout against community stats.
14. Added `seed_jobs.py` for populating dummy databases.
15. Resolved the broken DB fetch and layout issue on the home screen; dashboard sections (Summary, Savings Target, Daily Earnings chart, Platform Breakdown) now display consistently instead of hiding under empty-state banners.
16. Implemented a persistent Notification/Bell icon and slide-up inbox sheet with unread count badges in the home screen header. Fatigue nudges are saved to the persistent `users/{uid}/notifications` collection.
17. Resolved the natural language generation bug in `/fatigue-nudge` that caused Gemma to generate Chinese script due to contradictory prompting instructions.
18. Enhanced `/weekly-insight` to dynamically check weekly cadence and evaluate if newly logged jobs exist since the last generation date before regenerating.
19. Added a 15-second timeout and manual retry trigger on the AI insight dashboard card.
20. Fixed the daily earnings chart to always sort Monday-to-Sunday and implemented forward/backward week navigation controls syncing with the header date range.
21. Suppressed sparse/insufficient data projection ranges in the savings goal pacing calculator (below 3 days or 3 logged jobs).
22. Rectified the month offset bug that pointed to July for August dates.
23. Fixed singular/plural job text rendering in `batch_confirm_screen.dart` and `home_screen.dart`.
24. Seeded locality-specific benchmarks for 8 Bangalore zones across 15 platforms in Firestore.
25. Swapped `_locateUser` collection query to target decoupled `mapFairnessReports` and added transparency warning banners in low-confidence zones.
26. Fixed visual contrast on the "Speak to Log a Job" card by replacing the low-contrast transparent secondary background color with `PlayfulColors.accent` (Vivid Violet) and setting the heading and description text colors to `PlayfulColors.background` (cream).
27. Removed "EN" badges next to all mic icons on the Log Job screen by modifying the `PlayfulMicButton` component layout.
28. Upgraded the voice logging flow to implement natural pause/end-of-speech auto-stop using amplitude sound level monitoring.
29. Designed and implemented a targeted voice clarification loop for missing or low-confidence parsed fields (platform, fare, distance, duration) in voice logs using `flutter_tts` prompts, automatically starting mic capture after prompting.
30. Integrated fuzzy string matching for platforms and numeric fallbacks for single-word voice clarification responses on the backend.
# PROJECT MEMORY: GiGly (formerly GiGly)

## Project Overview
GiGly is a cross-platform mobile application and backend service built to empower gig workers (cab drivers, delivery riders, etc.) by tracking pay fairness, scanning screenshot receipts with OCR, logging trips via multilingual voice-first input, calculating fatigue nudges, offering localized smart AI coaching (GiGi), and providing safety features (SOS Alert Shield).

### Main Features
1. **Locality Fairness Map:** Live, reactive Firestore-backed map displaying pay fairness health (Fair, Underpaid, Mixed) across regions in Bengaluru.
2. **Log Trip & Voice-First Input:** Trip entry form with real-time unit conversion (km/m, min/hr) and slot-filling multilingual speech-to-text recognition supporting English, Hindi, Kannada, Telugu, Tamil, and Malayalam.
3. **Smarter OCR Scanner:** Scans trip screenshots, validates receipt relevance to prevent LLM hallucinations, and visualizes payout comparisons against community benchmarks on a clean OCR Result screen.
4. **GiGi Assistant:** Localized AI coach providing legal/financial help with persistent disclaimers and localized multilingual greetings.
5. **SOS Emergency Shield:** Configurable contacts list with a floating quick-trigger alert and automated emergency message broadcasts.
6. **Global Text Sizing:** Global accessibility font scale configuration (Small, Medium, Large).

### Current Project Status
All core modules (Map, Voice Logging, OCR Scanning, GiGi, SOS Alert) are stable, compiled, localized, and tested against regional key parities.

---

## Tech Stack
* **Frontend:** Flutter SDK (`>=3.12.0 <4.0.0`)
* **Backend:** FastAPI (Python `3.10+`)
* **Database:** Firebase Firestore
* **Speech to Text:** `faster_whisper` (small model running on CPU)
* **LLM Engine:** Google Gemini (via backend API integration)
* **Tunneling:** ngrok (forwarding local backend requests during real-device testing)

---

## Architecture

### Folder Structure
```
GiGly/
├── app/                       # Flutter Mobile Application
│   ├── android/               # Android native configuration
│   ├── ios/                   # iOS native configuration
│   ├── lib/
│   │   ├── main.dart          # Entry point, theme, and font scaler setup
│   │   ├── firebase_options.dart
│   │   ├── i18n/
│   │   │   └── strings.dart   # Localized translation tables
│   │   └── screens/           # UI Screens & Components
│   └── test/                  # Widget & unit tests
├── backend/                   # FastAPI Python Server
│   ├── main.py                # Server entry point & API endpoints
│   ├── llm.py                 # Gemini LLM helper functions & prompts
│   ├── ocr.py                 # OCR image processing helpers
│   ├── stt.py                 # Whisper voice transcription service
│   ├── safety.py              # SOS alert processing
│   ├── retriever.py           # Context retrieval for AI chat
│   └── schemas.py             # Pydantic data schemas
└── scripts/                   # Audits and setup scripts
    ├── audit_locales.py       # Checks localized key parity
    └── patch_ngrok.py         # Automates local proxy tunnels
```

### Important Modules
* **Strings System (`strings.dart`):** Central translation provider supporting `en`, `hi`, `kn`, `te`, `ta`, and `ml`. Key parity is strictly audited.
* **Playful Widgets (`playful_widgets.dart`):** Predefined design library implementing input fields, neubrutalist buttons, toggle pills, and custom bold Markdown widgets.

### Navigation
The navigation handles flow transitions from the `LoginScreen` or `OnboardingScreen` to the `HomeScreen` dashboard, which hosts sub-pages (Dashboard, History, Fairness Map, and GiGi).

### State Management
* App state is managed via Flutter's reactive stateful widgets (`StatefulWidget`) and Firestore's stream listeners (`StreamBuilder`) to update components immediately on collection writes.
* Font scaling uses a global accessibility setting initialized in `main.dart`.

---

## Database (Cloud Firestore)

### Collections & Schemas
1. **`users` (`/users/{uid}`):**
   * `name` (String)
   * `phoneNumber` (String, normalized 10-digit number)
   * `workerType` (String: `cab_driver`, `delivery_rider`, `other_gig_worker`)
   * `language` (String: `en`, `hi`, `kn`, `te`, `ta`, `ml`)
   * `sos_contacts` (List of Map items containing `name` and `phone`)
   * `savings_goal` (Integer)
2. **`jobs` (`/jobs/{jobId}`):**
   * `user_id` (String)
   * `platform` (String, e.g. `uber`, `zomato`)
   * `fare` (Double)
   * `distance_km` (Double)
   * `duration_min` (Double)
   * `expected_fare` (Double)
   * `is_underpaid` (Boolean)
   * `explanation` (String)
   * `source` (String: `manual`, `ocr`, `stt`)
   * `rate_source` (String: `fallback`, `community`)
   * `job_timestamp` (Timestamp/ServerTimestamp)
3. **`chats` (`/chats/{chatId}`):**
   * `user_id` (String)
   * `title` (String)
   * `created_at` (Timestamp)
   * `updated_at` (Timestamp)
   * **Subcollection `messages` (`/chats/{chatId}/messages/{messageId}`):**
     * `role` (String: `user`, `assistant`)
     * `content` (String)
     * `timestamp` (Timestamp)
 4. **`benchmarks` (`/benchmarks/{platformId}`):**
   * `displayName` (String)
   * `ratePerKm` (Double)
   * `ratePerMin` (Double)
   * `category` (String)
   * `sampleSize` (Integer)
   * `seedRate` (Map containing `rate_per_km` and `rate_per_min`)
   * `communityRate` (Map or Null)
 5. **`mapFairnessReports` (`/mapFairnessReports/{reportId}`):**
   * `isSeedData` (Boolean)
   * `platform` (String, e.g. `zomato`, `uber`)
   * `locality` (String, e.g. `koramangala`, `indiranagar`)
   * `timeOfDay` (String: `morning`, `evening`, `latenight`)
   * `fareActual` (Double)
   * `fareExpected` (Double)
   * `distanceKm` (Double)
   * `durationMin` (Double)
   * `reportedAt` (Timestamp/ServerTimestamp)

---

## APIs

### Internal Endpoints (FastAPI)
1. `POST /jobs/scan` -> Extracts text from payslip screenshots and structures data using Gemini.
2. `POST /stt` -> Audio file speech-to-text transcriber using CPU Whisper.
3. `POST /jobs/voice-parse` -> Slot-filler parsing entities from voice transcripts.
4. `POST /chat` -> Retrieves database contexts and responds with local system prompting.
5. `GET /weekly-insight` -> Weekly summary compiler.
6. `POST /admin/recalculate-benchmarks` -> Recalculates community benchmarks.
7. `POST /sos-alert` -> Sends alert packages.
8. `POST /fatigue-nudge` -> Verifies fatigue metrics.

### External APIs
* Firebase Authentication, Cloud Firestore.
* Gemini API (Google AI SDK).

---

## Environment
* **Flutter Environment:** `.env` at `app/.env` requires `API_URL` config pointing to the backend.
* **Backend Environment:** `.env` at `backend/.env` requires `FIREBASE_CREDENTIALS_PATH` (defaults to `firebase-service-account.json`).
* **Android Emulator Translation:** On mobile startup, localhost/127.0.0.1 references inside network calls are dynamically rewritten to `10.0.2.2` when executing on Android emulator environments.

---

## Coding Conventions
1. **Color Contrast Compliance:** All labels, input fields, toggles, indicators, and buttons must enforce WCAG 4.5:1 ratio (>3:1 for large elements) against backgrounds.
2. **Text Rendering:** Do not display raw Markdown characters (`**`) directly on screen; use `PlayfulMarkdownText` inside walkthrough or help descriptions.
3. **Emulator Compatibility:** Wrap local endpoint definitions in the loopback IP converter (`127.0.0.1` -> `10.0.2.2`) when running on Android.
4. **Language Rules:** AI prompts must prioritize the language script of the user's most recent message.

---

## Decisions Made
* **Authentication:** Uses Firebase Auth exclusively.
* **Storage:** Locally processed temp audio storage; remote logging writes to Firestore directly.
* **Chat streams:** UI queries Firestore stream updates for message feeds.
* **STT Validation:** Transcription returns returning blank/empty strings must invoke a visual SnackBar warning rather than executing silent code branches.
* **OS Setup:** Info.plist has explicitly declared keys for Microphone and Speech Recognition to avoid device rejections.

---

## Recent Changes
1. Decoupled the public Fairness Map collection by introducing `mapFairnessReports`, separating map metrics data entirely from user identity fields.
2. Configured manual, voice, and OCR logging screens to double-write to both `jobs` (private logs) and `mapFairnessReports` (anonymized logs).
3. Created an idempotent, repeatable database seeding script (`seed_map_reports.py`) to generate 150 skewed map coordinates report signals.
4. Replaced circular locality map markers with realistic boundary polygons and implemented point-in-polygon checks to trigger detail sheets on user location centering.
5. Swapped walkthrough text widgets for `PlayfulMarkdownText` to support bold tags.
6. Upgraded input placeholder styling colors in `PlayfulInput` to pass WCAG 4.5:1 contrast thresholds.
7. Upgraded `PlayfulToggle`, `PlayfulUnitInput`, and `PlayfulMicButton` background elements to pass WCAG color contrast criteria.
8. Corrected emergency contact and permission modal button styles.
9. Added runtime exception handling in STT uploads to alert users when whisper output is empty.
10. Implemented automatic loopback IP converter (`127.0.0.1` -> `10.0.2.2`) inside mobile endpoints on Android.
11. Declared `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` keys inside iOS `Info.plist`.
12. Imported missing localization elements in `settings_screen.dart` and `fairness_map_screen.dart`.
13. Added a new `ocr_result_screen.dart` to display clean receipt calculations comparing payout against community stats.
14. Added `seed_jobs.py` for populating dummy databases.
15. Resolved the broken DB fetch and layout issue on the home screen; dashboard sections (Summary, Savings Target, Daily Earnings chart, Platform Breakdown) now display consistently instead of hiding under empty-state banners.
16. Implemented a persistent Notification/Bell icon and slide-up inbox sheet with unread count badges in the home screen header. Fatigue nudges are saved to the persistent `users/{uid}/notifications` collection.
17. Resolved the natural language generation bug in `/fatigue-nudge` that caused Gemma to generate Chinese script due to contradictory prompting instructions.
18. Enhanced `/weekly-insight` to dynamically check weekly cadence and evaluate if newly logged jobs exist since the last generation date before regenerating.
19. Added a 15-second timeout and manual retry trigger on the AI insight dashboard card.
20. Fixed the daily earnings chart to always sort Monday-to-Sunday and implemented forward/backward week navigation controls syncing with the header date range.
21. Suppressed sparse/insufficient data projection ranges in the savings goal pacing calculator (below 3 days or 3 logged jobs).
22. Rectified the month offset bug that pointed to July for August dates.
23. Fixed singular/plural job text rendering in `batch_confirm_screen.dart` and `home_screen.dart`.
24. Seeded locality-specific benchmarks for 8 Bangalore zones across 15 platforms in Firestore.
25. Swapped `_locateUser` collection query to target decoupled `mapFairnessReports` and added transparency warning banners in low-confidence zones.
26. Fixed visual contrast on the "Speak to Log a Job" card by replacing the low-contrast transparent secondary background color with `PlayfulColors.accent` (Vivid Violet) and setting the heading and description text colors to `PlayfulColors.background` (cream).
27. Removed "EN" badges next to all mic icons on the Log Job screen by modifying the `PlayfulMicButton` component layout.
28. Upgraded the voice logging flow to implement natural pause/end-of-speech auto-stop using amplitude sound level monitoring.
29. Designed and implemented a targeted voice clarification loop for missing or low-confidence parsed fields (platform, fare, distance, duration) in voice logs using `flutter_tts` prompts, automatically starting mic capture after prompting.
30. Integrated fuzzy string matching for platforms and numeric fallbacks for single-word voice clarification responses on the backend.
31. Fixed the screenshot scanner loading state to only trigger when an image is actually selected and uploading, preventing the indefinite spinner state if picker is cancelled.
32. Implemented persistent red border outlines for fields with empty or unconfident values from screenshot scanner extraction.
33. Refactored the GiGi backend `/chat` endpoint to use Ollama's Chat API (`/api/chat`), natively formatting system prompts, conversation history (as distinct roles), and current user messages, fixing the conversation loop repetition bug.
34. Improved GiGi tone rules to enforce warm, coworker-like phrasing, explicitly avoiding formal policy or terms-of-service boilerplate.
35. Integrated a two-stage translation pipeline (`translate_to_language` using LLM translation prompt) for Kannada responses in `/chat` and `/weekly-insight`, preventing Russian/Portuguese word hallucinations inside Kannada text.
36. Resized the mic and image-picker buttons in the chat input bar to `38` and adjusted input constraints to prioritize text input workspace width.
37. Conducted a complete rebranding pass, replacing all user-facing occurrences of "GigShield" and "GigSense" with "GiGly", and "GigChat" with "GiGi" across code strings, all 6 localizations maps, OS manifests (`AndroidManifest.xml` launcher labels, `Info.plist` displayName and permissions descriptions), index.html, and backend system prompts.
38. Created the stateful `GiGiAvatar` widget implementing a circular head layout in `#4F46E5` with `2px` dark border, hard offset shadows, white dot eyes, colored cheek dots, and an animated mouth.
39. Configured `GiGiAvatar` to automatically alternate between closed and open mouth states (talking animation) on a 250ms periodic timer while streaming (`isStreaming`), briefly show a happy smile custom paint path on stream completion, and fall back to a static idle line shape when inactive or if motion reduction is requested.
40. Integrated `GiGiAvatar` into the message bubble, typing indicator bubble, and header avatar positions on the Chat screen.
41. Added a custom, neubrutalist-styled entrance splash screen (`GiGlySplash` in `splash_screen.dart`) that plays a staggered per-letter scale/bounce entrance animation (using the signature overshoot Cubic curve) for the wordmark and tagline on cold start, and automatically routes to `AuthGateway` using `Navigator.pushReplacement`.
42. Configured the splash screen to respect `prefers-reduced-motion` settings, immediately displaying the full text with a brief hold before routing.
43. Rewrote the system prompt for GiGi in `backend/llm.py` to establish a distinct, warm, friendly, and playful coworker personality, using casual language and contractions while maintaining strict grounding rules and factual accuracy.
44. Added a contextual tone shift rule instructing GiGi to immediately drop jokes and show empathy/care if the worker shares real frustration, money loss, or safety issues.
45. Loosened prompt structure constraints to encourage natural sentence variety, and revised disclaimer rules to avoid verbatim repetition across consecutive multi-turn chat messages.
46. Aligned the `get_weekly_insight_prompt` summary prompt to use the same supportive coworker coach persona.

---

## TODO
- [ ] Add unit tests for `regex_parse_transcript` slot-filling edge cases.
- [ ] Investigate audio formats for optimal latency reduction.
