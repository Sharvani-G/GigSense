# GiGly — Pay Fairness & Safety Companion for Gig Workers

Submission for the Synaptrix Hackathon.

GiGly is a mobile-first earnings companion and safety shield designed for gig workers in India ( Ola, Uber, Swiggy, Zomato, Rapido). It aggregates job metrics, evaluates pay fairness using crowdsourced rate benchmarks, provides a context-aware AI assistant (GiGi), and secures workers with stateful SOS tracking.

The entire app is built on a custom **Playful Geometric Design System** featuring vibrant, high-contrast HSL colors, bold offset borders, rounded card widgets, and custom micro-animations to ensure maximum accessibility.

---

## 👥 Contributors

This project was built during the Synaptrix Hackathon by:

* **Sharan S** — [@sharancode3](https://github.com/sharancode3)
* **Sharvani G Bhaskar** — [@Sharvani-G](https://github.com/Sharvani-G)

---

## 🚀 What's New in v1.2.0

Version `v1.2.0` focuses on **100% UI localization parity and build stability**. It eliminates mixed-language screens and implements:

* **Complete App-wide Localization**: fully translated all remaining English placeholders in the Settings, Languages, and Map screens. Settings items like `Emergency Contacts`, `GiGi Memory`, and `Manage` are fully localized.
* **Pay Fairness Map Localization**: Fully localized all map filters (`Morning`, `Evening`, `Late-Night`, `All Platforms`, `All Day`), legends (`Fair`, `Mixed`, `Underpaid`, `No Data`), and metadata cards (`Estimated`, `Growing`, `Well-established` confidence levels).
* **Safe Translation Engine**: Re-engineered key injection to handle nested single quote escapes (e.g., `'I\'m'`) preventing Dart compiler failures.
* **Dynamic Localized Insights**: Translated all dynamic summary comparison sentences (e.g., "*Indiranagar pays best...*") across all 6 supported languages.

---

## 🛠 How Core Features Work

### 1. Manual & OCR Job Logging
* **Form-based Input**: Workers log trips manually with easy forms that handle distance (KM) and time (Minutes) units automatically.
* **Screenshot OCR Scanner**: Workers take screenshots of delivery/ride payouts and upload them. The app runs Tesseract OCR to automatically parse the fare, duration, and distance.
* **Receipt Filter**: A custom classifier automatically filters out irrelevant/invalid screenshot uploads (like restaurant food bills or delivery lists) to keep log data clean.

### 2. Underpayment & Pay Fairness Check
* **Fairness Flag**: Compares the worker's logged job payout to active crowdsourced benchmarks in Firestore. If the payout is lower than expected, it marks the trip with a **⚠️ Possible Underpayment** warning card on the Home Screen.
* **Deduction Alert**: Triggers if the platform makes deductions without giving a reason, violating local labor transparency guidelines.
* **Dispute Complaint Draft**: For any underpaid trip, the app automatically drafts a formal dispute text (e.g., under the Code on Social Security 2020) that the user can copy and paste into aggregator chat boxes.

### 3. ADVANCED Locality Pay Fairness Map
* Shows Pay Fairness Health across different regions (zones) in the city using real-time worker logs.
* **Color-Coded Zones**:
  * **Green**: Pays full expected rates.
  * **Orange**: Pays close to expected rates.
  * **Pink**: Underpayment patterns detected.
* **Time & Platform Filters**: Users can filter trends by platforms (Zomato, Swiggy, Ola, Uber) and time of day (Morning, Evening, Late-Night).
* **Search Cache**: Saves search queries locally to prevent IP rate-limiting on Nominatim.

### 4. Interactive AI Chatbot (GiGi)
* An AI assistant grounded directly in the user's logged trips and Firestore databases.
* **Indian Labor Law Grounding**: Fact-checked responses regarding worker rights, social security, and local regulations.
* **Voice & Text Input**: Supports speech-to-text input, adjusting its language recognition models dynamically based on the active UI language.

### 5. Stateful SOS Safety Broadcast
* **Silent Background SMS**: Utilizes Android `SmsManager` to send silent live coordinates to trusted emergency contacts.
* **Persistent Lockout**: Navigation is locked to the active SOS view while broadcasting is active, ensuring the worker's safety interface remains visible.
* **WhatsApp Templates**: Pre-fills emergency coordinate templates to send via WhatsApp quickly.

---

## 📁 Repository Structure

```
├── app/                        # Flutter Mobile Frontend Application
│   ├── lib/
│   │   ├── i18n/               # Localization strings (strings.dart) & ChangeNotifier provider
│   │   ├── models/             # Data models (Job, SOS Settings, Contact)
│   │   ├── screens/            # Application Screens (Home Dashboard, Map, OCR, Settings, SOS)
│   │   └── widgets/            # Reusable UI widgets (Playful Buttons, Cards, Charts)
│   └── pubspec.yaml            # Project dependencies & assets configuration
│
└── backend/                    # FastAPI Backend Application (Python)
    ├── main.py                 # API server routing, OCR receipt parsing, Gemini AI helper integrations
    ├── schemas.py              # Pydantic schemas for data validation
    └── requirements.txt        # Python library dependencies
```

---

## 📦 How to Run the Project

### 1. Clone the repository
```bash
git clone https://github.com/Sharvani-G/GigSense.git
```

### 2. Configure & Run Backend (FastAPI)
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Set your environment variables in `.env`:
   ```env
   GEMINI_API_KEY=your_gemini_api_key_here
   ```
4. Start the server:
   ```bash
   uvicorn main:app --reload
   ```

### 3. Configure & Run Mobile App (Flutter)
1. Navigate to the app directory:
   ```bash
   cd ../app
   ```
2. Get Flutter packages:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```
