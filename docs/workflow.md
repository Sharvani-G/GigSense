# GiGly — Workflow & User Flow Specification

---

## 1. App Structure

**Bottom navigation, 3 tabs**: Home · Log Job · Chat

This is deliberately minimal — three tabs, no hidden hamburger menu, no settings screen unless time allows. Every screen must be reachable in one tap from anywhere.

---

## 2. Screen-by-Screen Detail

### 2.1 Home / Dashboard

**Purpose**: the worker's "at a glance" answer to "how's my week going, honestly?"

**Layout, top to bottom**:
1. Header: greeting text + current week's date range (e.g. "This week · 27 Jul – 2 Aug")
2. **AI Weekly Insight card** (full width, prominent, amber-tinted) — see UI/UX doc for exact styling
3. Three stat cards in a row (stack vertically on narrow screens): This Week's Earnings, Hours Worked, Flagged Jobs
4. Bar chart: daily earnings, last 7 days
5. Platform breakdown: small pill tags, one per platform, showing total earnings + job count
6. Floating action button (bottom-right): "+ Log a Job" — jumps to the Log Job tab

**States**:
- **Loading**: skeleton placeholders for stat cards and chart while data fetches — do not show a blank white screen
- **Empty (zero jobs logged)**: replace the stat row and chart with a single friendly empty-state block: "No jobs logged yet — tap below and let's check your first payout," plus the FAB. The Weekly Insight card should also not attempt to call Gemma with zero data — show a simple "Log a few jobs and I'll have your first weekly insight ready" placeholder instead, not an AI-generated sentence about nothing.
- **Error (Supabase/network unreachable)**: show a retry-able error banner at the top, do not block the rest of the cached UI if data was previously loaded
- **Populated**: full layout as described above, refreshes on pull-to-refresh and automatically whenever a new job is logged (if using Supabase realtime — otherwise refetch on navigation back to this tab)

---

### 2.2 Log Job

**Purpose**: capture a job as fast and low-friction as possible, then immediately answer "was that fair?"

**Top of screen**: a two-option pill toggle — **Manual Entry** / **Scan Screenshot** — defaults to whichever the worker used last time (persisted locally), since most workers will consistently prefer one method.

#### 2.2.1 Manual Entry sub-flow
1. Platform dropdown: Uber / Rapido / Zomato / Swiggy / Other
2. Fare input (₹), numeric keyboard
3. Distance input (km), numeric keyboard, decimal allowed
4. Duration input (min), numeric keyboard
5. "Log Job" button (primary, full width)
6. On submit → **Fairness Result screen** (2.2.3)

**Validation**: all four fields required before the button is enabled (don't let the button submit and then error — disable it proactively and show which field is missing if tapped anyway). Fare/distance/duration must be positive numbers.

#### 2.2.2 Scan Screenshot sub-flow
1. "Choose from gallery" / "Take photo" buttons (image_picker)
2. On image selected → loading state (brief, calm — not the app's bounce moment) while `/jobs/scan` processes
3. Result: the **same form as manual entry**, but pre-filled with whatever was extracted, with any unreadable field left blank
4. If confidence_note indicates a problem, show a small, calm inline note: "Couldn't read the distance clearly — go ahead and fill it in." Never an alarming error state for an OCR partial-miss — this is expected, normal behavior, not a failure.
5. Worker edits/confirms all fields (all fields remain fully editable even if extracted)
6. "Confirm & Log Job" button → same **Fairness Result screen** (2.2.3)

#### 2.2.3 Fairness Result (shown after either sub-flow submits)
- This is the single most important screen in the app emotionally — the payoff moment
- Large badge: "✅ Fair Pay" (mint) or "⚠️ Possibly Underpaid" (pink), with pop/bounce entrance
- Below it: expected fare vs actual fare shown side by side, plainly labeled
- A short one-line plain-language explanation, e.g. "This is about what's typical for a 4.2km Zomato trip." or "This came in noticeably below what's typical for this distance and platform."
- Two actions: "Log Another Job" (returns to 2.2 blank) and "Ask About This" (jumps to Chat, pre-filling the question "Is this fare fair?" with this specific job as context)

---

### 2.3 Chat

**Purpose**: a real conversation partner for fairness/rights questions, grounded in the worker's actual data.

**Layout**:
1. Scrolling message list (user messages right-aligned violet bubbles, Gemma replies left-aligned with avatar)
2. Three suggested quick-reply chips above the input, always visible when the chat is empty or after a reply completes: "Is this fair?" / "What are my rights?" / "How do I complain?"
3. Text input + send button at the bottom
4. Mic button next to the input (bonus feature — voice input)
5. Small persistent disclaimer text under the input: "General guidance, not legal advice."

**States**:
- **Empty (first open)**: a short friendly intro message from GiGly itself (not from Gemma — a static first message is fine and expected for a fresh chat), e.g. "Hey — ask me anything about your pay, your rights, or how to raise a complaint. I'll look at your recent jobs if it's relevant."
- **Waiting for response**: three bouncing dots (typing indicator) in a reply-shaped bubble
- **Response received**: bubble renders normally, quick-reply chips reappear
- **Error (Gemma unreachable)**: a plain-styled system message in the chat itself, e.g. "I'm having trouble responding right now — try again in a moment," rather than a modal/alert popup that interrupts the flow

---

## 3. Cross-Cutting Interaction Rules

- **Every AI-generated response** (chat replies, weekly insight) should visually indicate it's AI-generated (small "AI" tag/badge) so the worker always knows the difference between a static app message and a generated one — this is both good UX honesty and a subtle way to keep reinforcing your AI-integration story to judges watching the demo.
- **Every number the app claims** (expected fare, weekly totals) should be traceable back to a value the worker can see elsewhere — never show a stat without the underlying data being inspectable somewhere in the app. This is what makes the "fairness" framing credible rather than a black box.
- **No dead ends**: every screen has a clear next action. The Fairness Result screen always offers "log another" and "ask about this." The empty dashboard always offers a way to log the first job.

---

## 4. Full Happy-Path Walkthrough (for your demo video script)

1. Open app → Home shows empty state (fresh demo account) → tap "+ Log a Job"
2. Manual Entry: log a Zomato trip, fare ₹60, distance 6km, duration 25min (deliberately underpaid vs benchmark) → submit → see "⚠️ Possibly Underpaid" badge with the expected vs actual comparison
3. Tap "Log Another Job" → switch to Scan Screenshot → pick a pre-prepared trip-summary screenshot → OCR extracts most fields → confirm/correct → submit → see fairness badge again (aim for this one to read "Fair," for narrative contrast)
4. Navigate to Home → dashboard now shows both jobs: earnings total, hours, 1 flagged job, chart with today's bar, platform breakdown showing Zomato
5. Navigate to Chat → tap "Is this fair?" quick-reply chip → Gemma responds referencing the flagged Zomato job specifically
6. Back on Home, point out the Weekly Insight card and read its generated text aloud, calling out that it correctly identifies the underpayment pattern
7. (If built) Chat → tap mic, speak a question, show transcription populate the input

This exact sequence is what Phase 7 of the build prompt (see the Master Prompt doc) tells you to record.
