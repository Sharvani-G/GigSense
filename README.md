# GigShield
Submission for the Synaptrix Hackathon

## Problem Statement Chosen
- **Domain**: GigShield
- **Problem Statement**: Delivery riders, cab drivers, and other gig workers rarely have tools built for them. Most apps in this space are built for the platforms (Uber, Zomato, Rapido), not for the people doing the work. Underpayment, unsafe conditions, and a total absence of institutional support are everyday realities. There is almost no accessible technology addressing this from the worker's side.

## Team
- **Team Name**: Mutex
- **Participants**:
  - Sharan S
  - Sharvani G

## Our Solution
GigShield is a mobile-first companion app designed for gig workers in India to instantly verify if platform earnings match actual work completed. It aggregates trip metrics, performs rule-based fairness checks using regional platform rate benchmarks, and embeds an offline-resilient local AI chatbot (GigChat) and a scale-animated Weekly Insight card. All UI screens adhere to a striking "Playful Geometric" styling (vibrant color tokens, hard offset shadows, rounded pill elements, and bouncy micro-animations) to make tracking and asserting labor rights engaging and accessible.

## AI Component (Optional)
- **What AI is used**: Ollama with Gemma 3 4B (`gemma3:4b` locally hosted) and Tesseract OCR (`pytesseract`).
- **What it does in your app**: 
  - **Screenshot Scanning**: Extracts platform name, fare, distance, and duration directly from receipt screenshots, pre-filling the entry form and highlighting results with a soft pulse.
  - **GigChat Assistant**: Grounded in the user's recent Firestore trip data, GigChat answers questions about specific payouts, labour rights, and dispute resolutions in India.
  - **Weekly Insights**: Dynamically summarizes the user's weekly earnings, flags underpayment concentrations (e.g. particular apps/days), and suggests next steps like a coach.
- **Why we chose this approach**: Running LLMs locally (Ollama/Gemma 3) ensures complete data privacy for gig workers, eliminates expensive cloud token API fees, and allows offline utility, making it highly feasible for high-traffic operations.

## Tech Stack
- **Frontend**: Flutter (Dart)
- **Backend**: FastAPI (Python)
- **AI/ML**: Ollama API, Gemma 3 4B Model, pytesseract
- **Database/Storage**: Firebase Firestore (NoSQL Database), Firebase Auth (Anonymous Sessions)
- **Other libraries**: `fl_chart` (Dashboard graphs), `image_picker` (Screenshot imports), `http` (API integration), `Pillow` (Image manipulation)

## Features Implemented
- **Core Requirements**:
  - **Manual Entry & Benchmark Engine**: Form validating platforms, fare, distance, and duration, checking them against remote Firestore benchmarks.
  - **Playful Dashboard**: Real-time stats (Earnings, Hours, Flagged Jobs), daily earnings bar chart, and colored platform confetti tags.
  - **OCR Screenshot Import**: Scans files, auto-fills form inputs, details unparsed values with helper alerts, and triggers a 600ms highlight pulse.
  - **GigChat Thread**: Custom asymmetric message bubble layout, quick-reply outlined pills (tap-fill color), and bouncing dot typing indicators.
  - **Weekly AI Coach Summary**: Triggers async insight queries, displaying a loading indicator and popping in card text via ScaleTransition on load.
  - **Job History Log**: Dedicated screen showing paginated, filterable logs of all past work, integrated seamlessly with read-only Fairness Results.
  - **Settings Profile**: 4th navigation tab providing worker profile summaries and comprehensive app preferences using playful geometric cards.
- **Bonus Features**:
  - **Offline Resilience**: Automatic cache fallback for database benchmarks and writes.
  - **Reduced Motion Accessibility**: Checks system settings and replaces bouncing dots with static `...` typing indicators.

## How to Run This Project

### Clone the repo
```bash
git clone https://github.com/Sharvani-G/GigSense.git
```

### Install dependencies
1. **FastAPI Backend**:
   ```bash
   cd backend
   pip install -r requirements.txt
   ```
2. **Flutter Frontend**:
   ```bash
   cd app
   flutter pub get
   ```

### Set up Environment Variables
Create an `.env` file in the `app/` directory:
```bash
cd app
# Copy the example
cp .env.example .env
```
Inside `app/.env`, configure your FastAPI URL:
```env
API_URL=http://127.0.0.1:8000
```
*(If running on an Android Emulator, change to `API_URL=http://10.0.2.2:8000`. If using Ngrok to host the backend publicly, set this to your Ngrok forwarding URL: `API_URL=https://your-ngrok-url.ngrok-free.dev`)*

### Run the project
1. **Start Ollama** (Ensure `gemma3:4b` is installed):
   ```bash
   ollama run gemma3:4b
   ```
2. **Launch FastAPI server**:
   ```bash
   cd backend
   uvicorn main:app --reload
   ```
3. **Launch Flutter application**:
   ```bash
   cd app
   flutter run
   ```

### API Keys / Environment Variables
Configurations and Firebase Service account keys are completely ignored from Git to enforce security practices.
