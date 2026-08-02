GiGly — Product Requirements Document (PRD)
1. Executive Summary

GiGly is an AI-powered companion app for gig workers — delivery riders, cab drivers, food-delivery couriers — that answers one question they have no easy way to answer today: "Was I actually paid fairly for that job?" It goes further than a spreadsheet or earnings tracker by combining a rule-based fairness check with an AI chatbot that explains rights and options in plain language, and a weekly AI-generated summary that reads like a coach's note rather than a bank statement.

Built for an 8-hour hackathon (Synaptrix, BMSCE IEEE Computer Society × Protocol, 31st July 2026), under the "Gig Economy & Informal Sector Tech" track.

2. Problem Statement (restated from brief)

Delivery riders, cab drivers, and other gig workers rarely have tools built for them. Most apps in this space are built for the platforms (Uber, Zomato, Rapido), not for the people doing the work. Underpayment, unsafe conditions, and a total absence of institutional support are everyday realities. There is almost no accessible technology addressing this from the worker's side.

3. Why this matters (the human case, not just the brief)

A gig worker today has no independent way to check whether a payout matches the distance and time it actually took. They have no unified view when they work across multiple platforms in the same week. And when something does feel wrong, they have nowhere to ask "is this normal?" without navigating opaque in-app support flows that are built to protect the platform, not the worker. GiGly's job is to sit on the worker's side of the relationship — this framing should shape every product decision, not just the pitch.

4. Target Users & Personas
Persona 1 — Arjun, 27, food delivery rider

Works Zomato weekdays, Swiggy on weekends for extra income. Owns a basic Android smartphone, moderate data literacy, comfortable typing short messages but not filling long forms while riding. Wants: a fast way to log a trip between deliveries, and reassurance (or a red flag) about whether today's earnings are normal.

Persona 2 — Fathima, 34, cab driver

Drives Uber and Rapido full-time. More financially literate than Arjun, wants the weekly view and trend data more than the per-trip check — she's optimizing across a whole week, not one ride. Cares about the multi-platform aggregation most.

Persona 3 — Deepak, 45, occasional gig worker

Lower digital literacy, prefers speaking over typing where possible. Represents the case for the voice-input bonus feature and for keeping every core flow usable without dense text.

Design implication: the app must work well for a fast, low-friction single job log (Arjun), a weekly trend view (Fathima), and a low-typing-effort flow (Deepak) — none of these personas should feel like an afterthought in the core requirements.

5. Product Goals
Goal	How it's measured for this hackathon
Worker can tell instantly if a payout was fair	Fairness badge appears within ~1 second of logging a job
Worker can log jobs from multiple platforms without friction	Platform selector + OCR both feed the same unified job table
Worker gets real answers, not generic FAQ text	Chatbot responses are grounded in the worker's actual logged job data
Worker gets an honest weekly picture	Weekly insight is generated fresh from real aggregated data each time, not a template
The whole thing feels trustworthy, not clinical	Visual design (Playful Geometric) reinforces warmth and "someone's on your side," not a cold banking-app aesthetic
6. Core Requirements (must all be demoed — from the official brief)
Job logging — manual entry (fare, distance, time, platform) OR screenshot scan with OCR auto-extraction.
Fairness-check model — flags a job as "possible underpayment" by comparing actual payout to an expected fair-rate benchmark for that distance/time. A small reference dataset (not a scraped/official one) is explicitly sufficient per the brief.
AI chatbot — answers things like "is this fare fair?", "what are my rights?", "how do I raise a complaint?" in simple language, via an LLM (Gemma 3 4B, local).
Dashboard — summarizes weekly earnings, flagged underpayments, and total hours worked.
Multi-platform earnings aggregator — jobs from more than one gig app appear unified in a single dashboard.
AI-generated weekly insight summary — goes beyond raw numbers, e.g. explains where underpayment concentrated (platform, time of day, etc.), not just that it happened.
7. Bonus Requirements (attempt at most 1–2, only if core is solid)

Ranked by effort-to-impact ratio for an 8-hour build:

Bonus feature	Effort	Recommendation
Voice-based interaction (speech-to-text)	Low	Do this one — frontend-only, reuses existing chat/form flow, high demo impact
AI-generated complaint draft	Low–Medium	Good second choice — one more Gemma prompt template, no new UI paradigm
Multilingual support	Medium	Skip unless far ahead — needs a translation layer across every screen
Route safety score	Medium	Skip — needs believable proxy data you'd have to fabricate carefully
"I feel unsafe" trigger	Medium	Skip unless there's a clear team member free — real value but needs careful, non-flippant handling of a safety feature in a short build
Fatigue/burnout detector	Medium	Skip — needs enough logged history across a session to be meaningfully demoable
Savings goal tracker	Medium	Skip — nice but not core to the "fairness" narrative
Community fairness benchmark	Low–Medium	Only if voice + complaint draft are both done early — otherwise skip
8. Explicitly Out of Scope
Auto-detecting which platforms a phone number is logged into. No public API for this exists across Uber/Rapido/Ola; this data lives entirely inside each platform's private backend and isn't something a third-party app can query.
Android overlay/accessibility-service reading of other apps' screens. Technically possible in principle, but requires scary-sounding permissions, is fragile against UI changes, is a genuine privacy red flag to demo live, and is a multi-day build, not an 8-hour one.
Real SMS/Twilio sending, real payment integration. Mock or log these actions instead of wiring real third-party services — not worth the API-key setup risk during a timed build.
Full authentication system (OTP, password reset, etc.) A simple mock login (name field, or Supabase's built-in email/anonymous auth) is sufficient — this is a prototype for a demo, not a production login system.
Legal advice. The chatbot gives general, practical, informational guidance about rights and complaint processes — it must never present itself as authoritative legal counsel. State this explicitly in the chatbot's system prompt and, ideally, once in the UI copy (e.g. small text under the chat input: "General guidance, not legal advice").
9. Success Criteria for the Hackathon Demo Specifically

A 2–3 minute video, without narration gaps, glitches, or visible crashes, showing in this order:

A job logged manually → fairness badge appears
A screenshot scanned → OCR pre-fills → user confirms → fairness badge appears
Chatbot asked "is this fare fair?" on a flagged job → grounded, sensible, real-time Gemma response
Dashboard shown: weekly earnings, hours, flagged count, platform breakdown, chart
Weekly insight card shown and read aloud/highlighted, demonstrating it reasons over real data (not a canned sentence)
(If built) Voice input demoed briefly
10. Risks & Mitigations
Risk	Mitigation
OCR misreads a screenshot live during demo	Always show an editable confirm screen before saving — never trust OCR output blindly, and rehearse with a screenshot you know parses reasonably well as your primary demo shot
Ollama/Gemma not responding (server not running, port conflict)	Test the Ollama connection first thing in the morning before building anything else; have a curl test ready to sanity check localhost:11434 independently of your app
Supabase network dependency during a live/offline demo environment	Confirm venue wifi will support it during setup; have SQLite as a documented fallback path if network is unreliable on demo day (see TRD for both)
Running out of time before bonus features	Bonus features are explicitly deprioritized in this PRD — core requirements come first, always, no exceptions
Judges suspecting a "faked" AI component	Chatbot and weekly insight must be live Gemma calls at all times, including during rehearsal — never hardcode a response "just for the demo," since hackathon rules explicitly disqualify this
11. Out-of-the-box differentiators to mention in your pitch
Fully local LLM inference (Gemma 3 4B via Ollama) — worker's financial and job data never has to leave the device/laptop running the model, unlike most competitors that would round-trip through a cloud LLM API. This is a genuine, defensible privacy story for a product handling gig workers' income data.
Graceful OCR — the app never blindly trusts extracted data; every scan is human-confirmed before it's treated as fact, which is both more honest and more robust than presenting OCR as magic.
Grounded AI, not generic AI — both the chatbot and the weekly insight are explicitly fed the worker's own real data as context, so responses are specific to them, not boilerplate FAQ answers copy-pasted from a template.
