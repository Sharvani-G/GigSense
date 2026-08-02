# PROJECT MEMORY: GigSense (formerly GigShield)

## Project Overview
GigSense is a cross-platform mobile application and backend service built to empower gig workers (cab drivers, delivery riders, etc.) by tracking pay fairness, scanning screenshot receipts with OCR, logging trips via multilingual voice-first input, calculating fatigue nudges, offering localized smart AI coaching (GigChat), and providing safety features (SOS Alert Shield).

### Main Features
1. **Locality Fairness Map:** Live, reactive Firestore-backed map displaying pay fairness health (Fair, Underpaid, Mixed) across regions in Bengaluru.
2. **Log Trip & Voice-First Input:** Trip entry form with real-time unit conversion (km/m, min/hr) and slot-filling multilingual speech-to-text recognition supporting English, Hindi, Kannada, Telugu, Tamil, and Malayalam.
3. **Smarter OCR Scanner:** Scans trip screenshots, validates receipt relevance to prevent LLM hallucinations, and visualizes payout comparisons against community benchmarks on a clean OCR Result screen.
4. **GigChat Assistant:** Localized AI coach providing legal/financial help with persistent disclaimers and localized multilingual greetings.
5. **SOS Emergency Shield:** Configurable contacts list with a floating quick-trigger alert and automated emergency message broadcasts.
6. **Global Text Sizing:** Global accessibility font scale configuration (Small, Medium, Large).

### Current Project Status
All core modules (Map, Voice Logging, OCR Scanning, GigChat, SOS Alert) are stable, compiled, localized, and tested against regional key parities.

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
GigSense/
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
The navigation handles flow transitions from the `LoginScreen` or `OnboardingScreen` to the `HomeScreen` dashboard, which hosts sub-pages (Dashboard, History, Fairness Map, and GigChat).

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
1. Swapped walkthrough text widgets for `PlayfulMarkdownText` to support bold tags.
2. Upgraded input placeholder styling colors in `PlayfulInput` to pass WCAG 4.5:1 contrast thresholds.
3. Upgraded `PlayfulToggle`, `PlayfulUnitInput`, and `PlayfulMicButton` background elements to pass WCAG color contrast criteria.
4. Corrected emergency contact and permission modal button styles.
5. Added runtime exception handling in STT uploads to alert users when whisper output is empty.
6. Implemented automatic loopback IP converter (`127.0.0.1` -> `10.0.2.2`) inside mobile endpoints on Android.
7. Declared `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` keys inside iOS `Info.plist`.
8. Imported missing localization elements in `settings_screen.dart` and `fairness_map_screen.dart`.
9. Added a new `ocr_result_screen.dart` to display clean receipt calculations comparing payout against community stats.
10. Added `seed_jobs.py` for populating dummy databases.

---

## TODO
- [ ] Add unit tests for `regex_parse_transcript` slot-filling edge cases.
- [ ] Investigate audio formats for optimal latency reduction.
