GigShield — Technical Requirements Document (TRD)
1. Stack Decision & Rationale
Layer	Choice	Rationale
Data persistence	Supabase (Postgres)	Relational fit for jobs ↔ benchmarks lookups; hosted, zero server-maintenance; has a first-class Flutter SDK (supabase_flutter) so simple CRUD (insert job, read jobs, read dashboard aggregates) can be called directly from Flutter, without round-tripping through your own backend for every read/write
AI/logic backend	FastAPI (Python)	Handles everything Supabase can't: OCR processing, fairness computation (or this can also live in a Postgres function — see §4.4), and all Gemma calls
LLM	Gemma 3 4B via Ollama, local	Already installed, no API key/quota risk, offline-capable inference, strong privacy narrative
OCR	Tesseract via pytesseract	No API key, works offline, fast enough for screenshot text at hackathon scale
Frontend	Flutter	Cross-platform; talks to both Supabase (data) and FastAPI (AI endpoints)
Charts	fl_chart	Dashboard bar/line charts
Auth (minimal)	Supabase Anonymous Auth or a simple local device-based worker ID	Avoids building a real login system; anonymous auth still gives you a stable user_id to scope job rows to, which is good practice even in a demo
1.1 Why Supabase over Firebase specifically

Postgres is relational — your jobs table needs to look up benchmarks by platform on every insert, which is a natural join/query in SQL and an awkward manual double-fetch in Firestore's document model. Supabase also auto-generates a REST API and a realtime layer on top of plain Postgres tables, so you get realtime dashboard updates "for free" without hand-rolling websocket code. Firebase/Firestore remains a reasonable fallback (see §1.2) if your team is already more comfortable with it or Supabase project setup has friction on the day.

1.2 Firebase/Firestore equivalent (fallback reference only)

If you pivot to Firebase instead: use two Firestore collections, jobs and benchmarks. Since Firestore can't do a server-side join, fetch the relevant benchmark document client-side (or in a Cloud Function) before computing fairness, or simply duplicate the platform's rate values onto each job document at write time so no join is ever needed. Firestore's realtime listeners (snapshots()) are genuinely excellent for a live-updating dashboard and are arguably easier to wire in Flutter than Supabase's realtime channels — this is Firebase's strongest point in its favor.

1.3 SQLite fallback (offline safety net)

If venue wifi is unreliable, the entire Supabase layer can be swapped for local SQLite with near-identical table shapes (see the Database doc, §6, for the direct mapping). Decide which persistence layer you're using before Phase 0 of the build — don't leave this ambiguous going into the hackathon morning.

2. System Architecture
┌──────────────────────────────────────────────────────────┐
│                      Flutter App                            │
│                                                              │
│  Direct to Supabase (via supabase_flutter SDK):              │
│   - insert/read jobs                                         │
│   - read dashboard aggregates (via Postgres view or RPC)      │
│                                                              │
│  To FastAPI backend (via http/dio):                          │
│   - POST /jobs/scan       (OCR extraction)                    │
│   - POST /jobs/fairness   (fairness calc, if not done in DB)  │
│   - POST /chat            (Gemma Q&A)                         │
│   - GET  /weekly-insight  (Gemma summary)                     │
└───────────────┬──────────────────────────┬──────────────────┘
                │                          │
                ▼                          ▼
   ┌─────────────────────┐      ┌───────────────────────────┐
   │   Supabase (Postgres) │      │       FastAPI Backend       │
   │   - jobs table         │◄────┤   - reads/writes jobs via    │
   │   - benchmarks table   │      │     supabase-py client       │
   │   - dashboard view/RPC │      │   - ocr.py (Tesseract)       │
   └─────────────────────┘      │   - llm.py (Ollama calls)    │
                                 └──────────────┬────────────────┘
                                                │
                                                ▼
                                     ┌──────────────────────┐
                                     │  Ollama (local)        │
                                     │  gemma3:4b model        │
                                     └──────────────────────┘

Key architectural decision: Flutter talks to Supabase directly for plain data reads/writes (fast, no extra hop, less backend code to write), and only routes through FastAPI for anything that needs Python-side processing (OCR, LLM calls) or business logic you don't want duplicated in Postgres. This split meaningfully reduces how much backend CRUD code you need to hand-write in an 8-hour window.

3. API Contracts (FastAPI endpoints)
3.1 POST /jobs/scan

Extracts job data from an uploaded screenshot. Does not save to the database — this is a preview/extraction step; the actual insert happens via Supabase directly from Flutter once the user confirms.

Request: multipart/form-data, field image (the screenshot file)

Response 200:

json
{
  "platform": "zomato",
  "fare": 87.0,
  "distance_km": 4.2,
  "duration_min": 18,
  "confidence_note": "distance_km could not be confidently read",
  "raw_text": "... full OCR text for debugging ..."
}

Any field that couldn't be confidently parsed is returned as null, not guessed — the frontend must render that field blank for manual entry, never silently zero-filled.

Response 422 (image unreadable/corrupt): {"error": "Could not process image"} — frontend falls back to a fully blank manual-entry form, never a hard crash.

3.2 POST /jobs/fairness

Computes the fairness result for a given set of job values. (Alternative: implement this as a Postgres function/trigger instead — see Database doc §4 — so it runs automatically on insert and Flutter never needs to call this endpoint at all. Pick one approach and stick to it; don't build both.)

Request:

json
{ "platform": "zomato", "fare": 87.0, "distance_km": 4.2, "duration_min": 18 }

Response 200:

json
{
  "expected_fare": 91.60,
  "actual_fare": 87.0,
  "is_underpaid": false,
  "tolerance_band": 0.85
}
3.3 POST /chat

Request: { "message": "is this fare fair?", "user_id": "..." }

Backend fetches the user's most recent 3–5 jobs from Supabase (via supabase-py) before building the Gemma prompt, so the response is grounded in real recent data.

Response 200:

json
{ "response": "Looking at your last Zomato trip, ₹87 for 4.2km and 18 minutes is actually right around fair for that platform's typical rate — nothing alarming there. If you ever see a fare come in noticeably below what a similar-length trip usually pays, that's worth flagging." }

Response 503 (Ollama unreachable): {"error": "Assistant is temporarily unavailable — please try again in a moment."} — never a raw stack trace to the frontend.

3.4 GET /weekly-insight?user_id=...

Response 200:

json
{
  "insight_text": "You earned 12% less than usual this week, and most of that gap came from Tuesday and Wednesday night deliveries on Zomato — worth checking if those particular shifts are consistently lower-paying before you commit more evening hours there.",
  "stats_used": {
    "total_earnings": 4120.0,
    "total_hours": 31.5,
    "flagged_count": 3,
    "platform_breakdown": [{"platform": "zomato", "total_earnings": 2600.0, "job_count": 14}]
  }
}

Always return stats_used alongside the generated text — the frontend should show both, so the insight never feels like an unexplained black box (this is also a good "AI Integration & Creativity" scoring point: transparency, not just a chat bubble).

4. Error Handling Standards (apply across every endpoint)
Never return a raw Python traceback to the frontend. Catch exceptions, log them server-side for your own debugging, return a clean {"error": "human-readable message"} with an appropriate status code.
Every AI-backed endpoint (/chat, /weekly-insight) must handle Ollama being unreachable as a first-class case, not an afterthought — test this explicitly by stopping Ollama mid-development at least once.
OCR failures degrade to an empty editable form, never a blocked flow — the user must always be able to fall back to fully manual entry from the same screen.
Network failures from Flutter to either Supabase or FastAPI should show a simple retry-able error state in the UI, not a silent failure or an app freeze.
5. Environment & Local Setup Requirements
Python 3.10+, FastAPI, uvicorn, pytesseract (plus the system-level Tesseract binary installed separately), supabase-py, requests (for Ollama HTTP calls)
Ollama installed with ollama pull gemma3:4b run and verified (ollama run gemma3:4b "hello" should return text) before any app code is written
A Supabase project created in advance (during setup/prep time, not counted against your 8 hacking hours — project creation itself isn't "hacking," it's tooling prep, same logic as initializing a repo)
Flutter SDK installed, supabase_flutter, fl_chart, image_picker, http (or dio), and speech_to_text (if attempting the voice bonus) added to pubspec.yaml
Both the FastAPI server and the Flutter app need to reach each other over the local network during a live demo — decide in advance whether you're running the Flutter app on an emulator (can use 10.0.2.2 to reach localhost) or a physical phone (needs your laptop's LAN IP) and test this connection path early, since it's a common last-minute demo blocker
6. Non-Functional Requirements
Offline resilience for the AI layer: Gemma inference must work with zero internet connection — this is a deliberate design choice and worth stating explicitly in your pitch. (Supabase itself does require network connectivity, which is the one place true full-offline isn't achieved — be upfront about this rather than overclaiming.)
No faked AI: every Gemma-labeled feature must make a live model call at demo time, always, including rehearsals — per the hackathon's explicit disqualification rule against hardcoding the AI component.
Graceful degradation everywhere: OCR, network calls, and the LLM must all have a visible, honest fallback state in the UI rather than a crash or silent failure.
Response latency: Gemma 3 4B running locally on a laptop CPU may take a few seconds per response — design the UI (loading indicators, typing-dots animation) around this reality rather than assuming instant replies.
