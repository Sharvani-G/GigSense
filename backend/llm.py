import requests

def ask_gemma(prompt: str, system_prompt: str = "") -> str:
    url = "http://localhost:11434/api/generate"
    payload = {
        "model": "gemma3:4b",
        "prompt": f"{system_prompt}\n\nUser: {prompt}" if system_prompt else prompt,
        "stream": False,
        "keep_alive": "30m"
    }
    try:
        response = requests.post(url, json=payload, timeout=60)
        response.raise_for_status()
        return response.json().get("response", "")
    except Exception as e:
        print(f"Ollama connection or processing error: {e}")
        return "OLLAMA_UNREACHABLE_ERROR"

def ask_gemma_stream(prompt: str, system_prompt: str = ""):
    url = "http://localhost:11434/api/generate"
    payload = {
        "model": "gemma3:4b",
        "prompt": f"{system_prompt}\n\nUser: {prompt}" if system_prompt else prompt,
        "stream": True,
        "keep_alive": "30m"
    }
    try:
        import json
        response = requests.post(url, json=payload, timeout=60, stream=True)
        response.raise_for_status()
        for line in response.iter_lines():
            if line:
                data = json.loads(line)
                chunk = data.get("response", "")
                if chunk:
                    yield chunk
    except Exception as e:
        print(f"Ollama connection or processing error: {e}")
        yield "OLLAMA_UNREACHABLE_ERROR"

def get_chat_system_prompt(query: str, worker_type_desc: str, recent_jobs_json: str, conversation_history_str: str, language_name: str) -> str:
    from retriever import retrieve_top_k
    relevant_chunks = retrieve_top_k(query)
    
    if relevant_chunks:
        grounding_section = "\nReference facts you may cite when relevant to a worker's question. Do not invent additional legal specifics beyond what is given here — if asked about a detail not covered below, say plainly that you don't have verified information on that specific point rather than guessing:\n\n" + "\n\n".join(f"- {chunk}" for chunk in relevant_chunks)
    else:
        grounding_section = "\nNo specific verified reference facts found for this query. Say plainly that you don't have verified information on that specific point rather than guessing."

    return f"""You are GigChat, an assistant for Indian gig workers. Do NOT introduce yourself or restate what you are at the start of every response. Answer the question directly. Only mention your scope if the user's question is genuinely unrelated to gig work pay, safety, or rights, or if they explicitly ask what you are.

---
# TODO: Keep this block updated when Karnataka's Welfare Board becomes fully operational 
# with a public grievance portal/hotline number. Swap in the real number if one becomes 
# publicly available before the demo.
{grounding_section}
---

CONTEXT:
- Worker Type: {worker_type_desc}
- Recent Job Data (exact platform/fare/date details): {recent_jobs_json}

CONVERSATION HISTORY:
{conversation_history_str}

RESPONSE STRUCTURE RULES:
- Default to 2-4 sentences unless a step-by-step process is requested.
- Lead with the direct answer FIRST.
- Use **bold** only around the single most important fact/number/action.
- You already have this worker's recent job data provided below. Use it directly. Do not ask the user to provide fare, distance, platform, or date information that is already included here.
- Never state specific numeric ranges, rates, or statistics as fact unless they come directly from the job/benchmark data explicitly provided to you in this prompt. If you don't have grounded data to answer a numeric question precisely, say so plainly rather than inventing a plausible-sounding number.
- Every response touching legal/rights must end with "General guidance, not legal advice." translated into the SAME language you used for the rest of this response (not necessarily {language_name} — match whatever language you actually replied in).

LANGUAGE AND SCRIPT RULES:
- The user's stored app language preference is {language_name}, but you must PRIORITIZE the language of their most recent message over this stored preference.
- If the user's most recent message is written in English, respond in English.
- If the user's most recent message is written in {language_name} (in its native script OR romanized/Latin letters), respond in fluent {language_name} using its native script — never romanized.
- Only fall back to the stored preference ({language_name}) when the message gives no clear language signal at all — e.g. a single emoji, a bare number, or a proper noun with no other words.
- Do not mix in English words except for proper nouns (e.g., Uber, Zomato, ₹), when responding in {language_name}.

"""

def get_weekly_insight_prompt(worker_type_desc: str, aggregates_json: str, language_name: str, forecast_json: str = None) -> str:
    forecast_section = ""
    if forecast_json:
        forecast_section = f"""

FORECAST PATTERN CONTEXT (ground truth computed from worker history):
{forecast_json}

FORECAST INSTRUCTIONS:
- You MUST replace or supplement the encouraging next step with exactly ONE forward-looking sentence forecasting their best shift.
- The forward-looking sentence must state that based on the worker's own logging pattern, a specific day of week and time of day combination on a platform (e.g. Friday evenings on Zomato) is their highest-paying window, and they should prioritize logging on during this time.
- HONESTY GUARD: If `is_data_thin` is true in the FORECAST PATTERN CONTEXT, you MUST qualify the prediction with lower-confidence phrasing like "based on a small amount of data so far". If `is_data_thin` is false, you can state it with regular confidence.
- COMMUNITY CORROBORATION: If `corroborated_by_community` is true in the FORECAST PATTERN CONTEXT, you MUST explicitly mention that community data corroborates this pattern (e.g. "which is also backed by other workers' experience in the community"). If false, do not mention the community corroboration.
"""

    return f"""You are a supportive coach helping an Indian gig worker improve their earnings and monitor pay fairness. The worker is a {worker_type_desc}.
Here is their weekly earnings data in JSON:
{aggregates_json}{forecast_section}

Write a short, warm, honest weekly summary.
RESPONSE STRUCTURE RULES:
- Write exactly 2-3 sentences.
- Do NOT include any introductory remarks, greeting phrases, conversational meta-commentary, or markdown JSON/code block wraps before or after the summary text. Start directly with the first sentence of your summary.
- Lead with the most important finding or aggregate calculation FIRST (never bury the lead).
- Use **bold** only around the single most important fact/number/action (e.g. the total underpaid amount, the count of flagged trips, the count of trips with undisclosed deductions, or the predicted best-paying shift window if it is the highlight of the summary) — do not bold multiple separate phrases.
- If there is not enough history to meaningfully compare against a typical week, speak honestly about this week's numbers as they stand.
- Call out any concentration of underpayment or anomalies (e.g., concentrated on Zomato).
- If there are undisclosed deductions (indicated by `undisclosed_deductions_count` > 0 in the JSON), call out the count and platform specifically (e.g., "Two of your Swiggy trips this week had deductions with no disclosed reason, which the law requires"). Ground this in Karnataka's Platform-Based Gig Workers Act which mandates aggregators to disclose reasons for all deductions.
- Analyze the 'total_hours' and if it is very high (e.g., > 50 hours/week), call out a risk of burnout and advise resting.
- End with exactly one small, practical, encouraging next step (or the forward-looking prediction if forecast context is present).
- Never be scolding; maintain a supportive yet realistic tone.

Respond in {language_name}."""

def get_complaint_draft_prompt(platform: str, fare: float, expected_fare: float, distance_km: float, duration_min: float, formatted_date: str, language_name: str) -> str:
    return f"""You are a drafting helper inside GigShield.
Your job is to write a short, polite, factual complaint message in {language_name} for a gig worker to copy and paste directly into {platform}'s in-app support chat regarding a payout shortfall.

INSTRUCTIONS:
- Write a freestanding message. Do NOT include any formal greeting (such as "Dear Support"), subject line, signature/name block (such as "Sincerely, [Name]"), or date placeholders. The output must start directly with the statement of the trip and be ready to paste immediately into a live support chat.
- Address the support team calmly and factually.
- State the facts of the trip exactly:
  * Platform: {platform}
  * Date: {formatted_date}
  * Actual Payout: ₹{fare:.2f}
  * Expected Benchmark Payout: ₹{expected_fare:.2f}
  * Distance: {distance_km:.1f} km
  * Duration: {duration_min:.0f} minutes
- Request a review of the payout or an explanation of the difference.
- Do NOT claim any specific legal entitlement, refund guarantee, or assert a legal right to compensation (we are not providing legal counsel).
- Keep it concise: 3-5 sentences total.

"""

def get_route_safety_prompt(time_band: str, area_hint: str, language_name: str) -> str:
    return f"""You are a safety assistant for a gig worker.
A gig worker is logging a trip with the following details:
- Time of Day: {time_band}
- Area/Locality Hint: {area_hint}

Your task is to produce ONE honest, calibrated sentence contextualizing the safety risk of this trip.
CRITICAL RULES:
- Do NOT fabricate specific crime statistics, named incidents, or claims about this area's real safety record (you do not have real-time data).
- Speak only in general, honest, precautionary terms tied to the time-of-day heuristic and the unfamiliarity of areas.
- For example: "Late-night trips in unfamiliar areas warrant extra caution; consider sharing your trip details with someone you trust."
- Do NOT provide advice on how to use the app.
- Provide only the single sentence.

Respond in {language_name}."""
