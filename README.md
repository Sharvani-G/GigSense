# GiGly — Pay Fairness & Safety Companion for Gig Workers

Submission for the **Synaptrix Hackathon** — Polished and perfected through intense post-hackathon cycles of real-world trials, error-tracking, and robust optimization.

GiGly is a mobile-first earnings companion and safety shield designed for gig workers in India ( Ola, Uber, Swiggy, Zomato, Rapido). It aggregates job metrics, evaluates pay fairness using crowdsourced rate benchmarks, provides a context-aware AI assistant (GiGi), and secures workers with stateful SOS tracking.

The entire app is built on a custom **Playful Geometric Design System** featuring vibrant, high-contrast HSL colors, bold offset borders, rounded card widgets, and custom micro-animations to ensure maximum accessibility.

---

## 🛠 From Hackathon Prototype to Stable Release

While GiGly started as a fast-paced submission prototype for the **Synaptrix Hackathon**, we committed to transforming it into a production-ready application. Through multiple iterative trials, code testing, and solving real-world compilation/localization quirks, we refined every feature:

* **Translation Syntax & Engine Fixes**: Meticulously normalized translations to handle nested single quote escapes (e.g. `I'm`), resolving critical compiler crash states.
* **100% Native Language Parity**: Audited and fixed translation gaps across Settings and Maps views so that the user interface is completely local, with zero English mixture.
* **Dynamic Zone Comparisons**: Overhauled zone analysis calculations to support dynamic comparisons and multilingual updates.
* **Refined Database Validation**: Hardened backend schemas and Firebase sync systems to prevent errors when users transition between offline and online states.

---

## 👥 Contributors

This project was built and refined by:

* **Sharan S** — [@sharancode3](https://github.com/sharancode3)
* **Sharvani G Bhaskar** — [@Sharvani-G](https://github.com/Sharvani-G)

---

## 🚀 What's New in v1.2.0

* **Complete App-wide Localization**: fully translated all remaining English placeholders in the Settings, Languages, and Map screens. Settings items like `Emergency Contacts`, `GiGi Memory`, and `Manage` are fully localized.
* **Pay Fairness Map Localization**: Fully localized all map filters (`Morning`, `Evening`, `Late-Night`, `All Platforms`, `All Day`), legends (`Fair`, `Mixed`, `Underpaid`, `No Data`), and metadata cards (`Estimated`, `Growing`, `Well-established` confidence levels).
* **Safe Translation Engine**: Re-engineered key injection to handle nested single quote escapes (e.g., `'I\'m'`) preventing Dart compiler failures.
* **Dynamic Localized Insights**: Translated all dynamic summary comparison sentences (e.g., "*Indiranagar pays best...*") across all 6 supported languages.

---

## 💡 How Core Features Work

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

### 4. Interactive AI Chatbot (GiGi)
* An AI assistant grounded directly in the user's logged trips and Firestore databases.
* **Indian Labor Law Grounding**: Fact-checked responses regarding worker rights, social security, and local regulations.
* **Voice & Text Input**: Supports speech-to-text input, adjusting its language recognition models dynamically based on the active UI language.

### 5. Stateful SOS Safety Broadcast
* **Silent Background SMS**: Utilizes Android `SmsManager` to send silent live coordinates to trusted emergency contacts.
* **Persistent Lockout**: Navigation is locked to the active SOS view while broadcasting is active, ensuring the worker's safety interface remains visible.
* **WhatsApp Templates**: Pre-fills emergency coordinate templates to send via WhatsApp quickly.
