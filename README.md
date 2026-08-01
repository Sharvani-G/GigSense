# GigSense (GigShield)
Submission for the Synaptrix Hackathon

[![Direct Download](https://img.shields.io/badge/Download-APK-green?style=for-the-badge&logo=android)](https://github.com/Sharvani-G/GigSense/releases/download/v1.0.0/gigSense_v1.0.0.apk)

📲 **[Download the GigSense v1.0.0 APK Directly Here](https://github.com/Sharvani-G/GigSense/releases/download/v1.0.0/gigSense_v1.0.0.apk)**

## Problem Statement Chosen
**Domain:** GigShield
**Problem Statement:** Let the worker log each job manually, or scan a screenshot of their delivery/ride app using OCR to auto-extract the earnings data. Check if it's fair compared to benchmarks, provide an AI chatbot, and build a unified multi-platform dashboard with weekly insights to protect gig workers from underpayment.

## Team
**Team Name:** Mutex
* **Sharan S**
* **Sharvani G**

## Our Solution
GigSense is a mobile-first safety and earnings companion app designed specifically for gig workers in India (Ola, Uber, Swiggy, Zomato, Rapido). It aggregates job metrics, runs automated fairness checks using regional platform rate benchmarks, and includes an interactive AI Chatbot (GigChat) along with weekly analytics. The entire interface utilizes a striking, custom "Playful Geometric" design system featuring vibrant colors, bold offset borders, rounded pill tabs, and custom micro-animations to make financial transparency and legal rights accessible to low-literacy users.

## AI Component (Optional)
* **What AI is used:** Google Gemini API (with local Ollama Gemma 3 4B fallback) and Tesseract OCR (with an custom heuristic receipt classifier).
* **What it does in your app:** 
  * **Intelligent OCR Screenshot parsing:** Scans uploaded ride/delivery receipts, auto-extracts earnings, and utilizes a classifier to reject invalid/irrelevant images (like food receipt orders).
  * **Context-Aware GigChat Assistant:** Grounded directly in the user's Firestore job logs to answer specific questions regarding pay shortfalls and Indian labor regulations.
  * **Weekly Insights Generator:** Compiles custom, action-oriented financial performance suggestions based on cumulative weekly logs.
  * **Route Safety & Fatigue Checkers:** Dynamically advises safety precautions for night runs and drafts panic coordinates for trusted contacts.
* **Why we chose this approach:** Integrating Gemini API with a local Ollama fallback enables secure, lightning-fast, and cost-efficient processing. Fact-grounding the LLM system prompt with static legal references prevents AI hallucinations on labor laws.

## Tech Stack
* **Frontend:** Flutter (Dart)
* **Backend:** FastAPI (Python)
* **AI/ML:** Google Gemini API (or local `gemma3:4b`), pytesseract (OCR)
* **Database/Storage:** Firebase Firestore, Firebase Authentication
* **Other tools/APIs:** `fl_chart` (Data visualization), `speech_to_text` (Voice input), `share_plus` (Emergency SOS dispatch), `dotenv` (Environment config)

## Features Implemented

### Core Requirements:
* **Manual & OCR Job Logging:** Form-based trip creation with distance/time unit conversions, plus a screenshot scanner that auto-extracts data and rejects invalid receipts.
  * *How to use:* Tap the green **`+` (Add)** FAB at the bottom-right of the Home Screen. Fill out manually or tap **Scan Screenshot** at the top.
* **Underpayment & Fairness Check:** Evaluates logged jobs against live Firestore benchmarks and flags deviations as possible underpayment.
  * *How to use:* If a logged trip has a low payout, you will see a red **⚠️ Possible Underpayment** warning card on the Home Screen. Tapping it opens the detailed fairness calculation view.
* **AI Chatbot (GigChat):** Interactive chat grounded in user logs, featuring native script output and fact-restricted Indian legal references.
  * *How to use:* Tap the **Chat** option on the bottom navigation bar and ask questions. It automatically loads your trip history in the background.
* **Weekly Dashboard:** Highlights total earnings, underpaid trips, total hours worked, and platform distribution via colorful charts.
  * *How to use:* Visible on the main **Home Screen** showing real-time summary cards at the top.
* **Multi-Platform Aggregation:** Displays unified analytics from ridesharing (Uber, Ola) and delivery (Swiggy, Zomato) platforms side-by-side.
  * *How to use:* Scroll to the "Platform Distribution" section on the **Home Screen** dashboard to see the color-coded chart.
* **AI Weekly Insights:** Produces custom weekly performance summaries with rest and earnings optimization tips.
  * *How to use:* Appears as a summary card under the header on the **Home Screen** dashboard.

### Bonus Features Attempted:
* **Voice-to-Text Interaction (STT):** Integrates speech-to-text directly in GigChat, adjusting recognition models automatically based on user language preferences.
  * *How to use:* Inside the **Chat Screen**, press and hold the **Microphone icon** next to the input field, speak, and release to send.
* **AI Route Safety Score:** Assesses risk levels and generates safety recommendations dynamically for late-night or evening trips.
  * *How to use:* Tap any logged trip on the dashboard to open the **Fairness Result Screen**. If it occurred between 9 PM – 6 AM, tap the **🌆 Evening trip** or **🌙 Late-night trip** badge to expand route safety tips.
* **Multilingual Support:** Fully localizes the UI and prompts into 6 languages: English, Hindi, Kannada, Tamil, Telugu, and Malayalam.
  * *How to use:* Go to the **Settings** screen (4th navigation tab), open the language picker under "Preferences," and select a language.
* **AI Dispute Complaint Drafts:** Automatically generates formal dispute copy-paste text based on flagged underpayments.
  * *How to use:* Open the **Fairness Result Screen** for an underpaid trip, scroll to the bottom, and tap **Draft Dispute Message**.
* **Fatigue & Burnout Detector:** Monitors active hours and triggers friend-like reminders to rest if daily (10+ hrs) or weekly (50+ hrs) limits are exceeded.
  * *How to use:* A **"Fatigue Warning"** banner appears automatically on the **Home Screen** dashboard when limits are breached.
* **"I Feel Unsafe" (SOS Alert):** Instant emergency button that drafts coordinates and opens a native share-sheet for trusted contacts.
  * *How to use:* Tap the red **SOS** floating button on the bottom-right of the **Home Screen** (above the Add button).
* **Savings Goal Tracker:** Lets workers configure weekly targets and tracks target progress via animated progress indicators.
  * *How to use:* Configure your target amount in **Settings**, and see the progress bar update on the **Home Screen** dashboard.
* **Community Fairness Benchmark:** Simulates crowdsourced rates from other local drivers to update and improve baseline rate accuracy.
  * *How to use:* Automatically integrated into the fairness engine check when evaluating trip payouts.

---

## How to Run This Project

### Clone the repo
```bash
git clone https://github.com/Sharvani-G/GigSense.git
```

### Install dependencies
1. **FastAPI Backend:**
   ```bash
   cd backend
   pip install -r requirements.txt
   ```
2. **Flutter Frontend:**
   ```bash
   cd app
   flutter pub get
   ```

### Copy the example env file and fill in your own keys
```bash
cd app
cp .env.example .env
```
Update the API URL in `app/.env`:
```env
API_URL=http://127.0.0.1:8000
```
*(If running on an Android Emulator, set to `API_URL=http://10.0.2.2:8000`)*

### Run the project
1. **Start Ollama** (If using local LLM fallback):
   ```bash
   ollama run gemma3:4b
   ```
2. **Launch FastAPI server:**
   ```bash
   cd backend
   uvicorn main:app --reload
   ```
3. **Launch Flutter application:**
   ```bash
   cd app
   flutter run
   ```

### API Keys / Environment Variables
Add your Gemini API Key in the backend `.env` file to enable the cloud LLM services:
```env
GEMINI_API_KEY=your_gemini_api_key_here
```
*(Firebase configuration files and keys are loaded via the assets and ignored from git to enforce security).*

### Pre-Demo Checklist
Before presenting a demo or performing a release run:
1. **Verify Local LLM (Ollama)**:
   Ensure Ollama is running and has downloaded the model:
   ```bash
   ollama run gemma3:4b
   ```
2. **Run Localization Key Audit**:
   Verify key consistency and translations across all 6 supported languages:
   ```bash
   python scripts/audit_locales.py
   ```
   Ensure it prints: `Success: All languages have 100% key parity with English!`.
