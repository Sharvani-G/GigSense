# GigShield (Synaptrix Hackathon)

GigShield is an AI-powered companion app for gig workers (delivery riders, cab drivers, food-delivery couriers) designed to answer one crucial question: **"Was I actually paid fairly for that job?"**

Built for the Synaptrix 8-hour hackathon (Gig Economy & Informal Sector Tech track), GigShield combines a rule-based fairness check with an AI chatbot that explains rights and options in plain language.

## Tech Stack & Architecture

- **Frontend:** Flutter (Fully responsive, implementing a custom "Playful Geometric" design system)
- **Backend:** FastAPI (Python)
- **Database & Auth:** Firebase (Firestore NoSQL and Firebase Anonymous Auth)
- **AI/LLM:** Gemma 3 4B running completely locally via Ollama (`gemma3:4b`)
- **OCR:** Tesseract via `pytesseract` for extracting data from screenshot uploads

*(Note: The project initially considered Supabase, but pivoted entirely to Firebase for NoSQL persistence and authentication.)*

## Project Structure

- `/app`: The Flutter frontend application.
- `/backend`: The FastAPI Python backend handling OCR and LLM inference.
- `/docs`: Contains original PRD, TRD, Design System, and Workflow documentation.

## Current Setup & State

### 1. Backend Setup
The backend is a standard Python FastAPI application. It is fully connected to the Firebase project via the Firebase Admin SDK.
- Requirements: `fastapi`, `uvicorn`, `firebase-admin`, `pytesseract`, `python-dotenv`.
- To run locally:
  ```bash
  cd backend
  pip install -r requirements.txt
  uvicorn main:app --reload
  ```
- *Note:* A `firebase-service-account.json` file must be present and linked in the `.env` file to initialize the database connection.

### 2. Frontend Setup
The Flutter app features a `BottomNavigationBar` scaffolding three main tabs: Home, Log Job, and Chat. 
- The app uses `firebase_core`, `firebase_auth`, and `cloud_firestore`.
- Anonymous authentication executes automatically upon app launch.
- *Developer Note:* To configure the frontend with real Firebase API keys, run:
  ```bash
  cd app
  flutterfire configure --project=gigshield-e38ec
  ```

## Design Philosophy
The UI follows a **Playful Geometric** design system. It avoids generic Material UI aesthetics in favor of vibrant colors, hard shadows, primitive shapes, and bouncy micro-animations to create a premium, engaging experience for the user.
