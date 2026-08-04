# GiGly — Pay Fairness & Safety Companion for Gig Workers

Submission for the **Synaptrix Hackathon** — Polished and perfected through intense post-hackathon cycles of real-world trials, error-tracking, and robust optimization.

---

## 📲 Download GiGly v1.2.0

Select the appropriate package for your device to download directly from the GitHub Release:

* 📱 **[Universal Build (All Devices)](https://github.com/Sharvani-G/GigSense/releases/download/v1.2.0/GiGly-v1.2.0-release.apk)** (58.1 MB) — *Contains support for all hardware configurations. Recommended if you are unsure.*
* 🚀 **[Modern Mobiles (ARM64)](https://github.com/Sharvani-G/GigSense/releases/download/v1.2.0/GiGly-v1.2.0-modern-mobiles.apk)** (21.3 MB) — *Optimized for 64-bit modern devices (arm64-v8a).*
* 💾 **[Older Mobiles (ARMv7)](https://github.com/Sharvani-G/GigSense/releases/download/v1.2.0/GiGly-v1.2.0-old-mobiles.apk)** (19.1 MB) — *Optimized for older 32-bit devices (armeabi-v7a).*
* 💻 **[Emulator Testing (x86_64)](https://github.com/Sharvani-G/GigSense/releases/download/v1.2.0/GiGly-v1.2.0-emulator-testing.apk)** (22.8 MB) — *Built for x86_64 emulator configurations.*

---

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

## 💡 Key App Concepts & Major Features

### 🗺️ Real-Time Pay Fairness Map (Crowdsourced)
* **Actual Worker Logs (Not Company Claims)**: Unlike static maps that display platform-advertised rates, GiGly compiles real-time ride and delivery data logged directly by workers in the city.
* **Zone Fairness Baselines**: Aggregates average pay metrics across neighborhoods (like Indiranagar, Koramangala, Yelahanka) and colors them Green (Fair pay), Orange (Mixed), or Pink (Underpaid) based on expectations.
* **Real-time Filters**: Allows workers to dynamically filter neighborhood averages by platform (Uber, Ola, Swiggy, Zomato) and shift hour (Morning, Evening, Late-Night) to plan their routes for maximum earnings.

### 🤖 GiGi AI Assistant & Adaptive Memory
* **Context-Aware Coaching**: GiGi acts as a personalized legal coach. It dynamically parses the worker's recent ride logs in Firestore to answer specific questions (e.g., *"Why was my Rapido trip flagged?"*).
* **GiGi Memory (Adaptive Context Caching)**: Includes a persistent memory system where GiGi remembers critical context about the worker (e.g., *full-time delivery rider, working 10+ hour shifts in Indiranagar*). It uses this memory to adapt suggestions and advice over time, avoiding repetitive introductions.
* **Indian Labor Law Grounding**: GiGi is fact-restricted and grounded in verified legal guidelines like the **Code on Social Security 2020** and the **Karnataka Platform-Based Gig Workers Act 2025** to explain pay guidelines, rate deductions, and union benefits.

### 🌐 Deep Multilingual Coverage
* **Zero Language Mixture**: The user interface is completely translated across all screens—preventing confusing English and regional language mixtures.
* **Supported Languages**: Fully localizes both UI labels and AI assistant prompts into 6 major languages: **English, हिन्दी (Hindi), ಕನ್ನಡ (Kannada), தமிழ் (Tamil), తెలుగు (Telugu), and മലയാളം (Malayalam)**.
* **Adaptive Voice Input**: GiGi adjusts its speech recognition model automatically to parse Kannada, Hindi, and other languages based on the user's active application language.

### ⚠️ Burnout & Fatigue Monitoring
* **Continuous Shift Tracker**: Scans logged trip timestamps in a rolling 24-hour window.
* **Fatigue Alerts**: Displays proactive, friendly alert nudges on the Home Screen dashboard if daily active hours exceed 10 hours (or weekly totals exceed 50 hours), encouraging workers to rest before they experience exhaustion or risk safety.

### 🛡️ Stateful SOS Safety Broadcast
* **Silent Native SMS Dispatch**: Calls Android `SmsManager` to send silent live coordinate updates in the background to emergency contacts.
* **Stateful Navigation Lockout**: Locks the worker's interface to the active SOS safety card, preventing accidental exits while a safety session is broadcasting.

### 📷 Screenshot OCR Receipt Classifier
* **Heuristic OCR Extractor**: Parses screenshots of ride summaries, automatically extracting the platform, earnings (₹), trip duration (minutes), and distance (KM).
* **Invalid Image Filter**: An integrated receipt classifier filters out irrelevant images (like food menus, general screenshots) and requests a valid ride receipt.
