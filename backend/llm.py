import requests

def ask_gemma_chat(messages: list) -> str:
    url = "http://localhost:11434/api/chat"
    payload = {
        "model": "gemma3:4b",
        "messages": messages,
        "stream": False,
        "keep_alive": "30m"
    }
    try:
        response = requests.post(url, json=payload, timeout=60)
        response.raise_for_status()
        return response.json().get("message", {}).get("content", "")
    except Exception as e:
        print(f"Ollama connection or processing error: {e}")
        return "OLLAMA_UNREACHABLE_ERROR"

def ask_gemma_chat_stream(messages: list):
    url = "http://localhost:11434/api/chat"
    payload = {
        "model": "gemma3:4b",
        "messages": messages,
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
                chunk = data.get("message", {}).get("content", "")
                if chunk:
                    yield chunk
    except Exception as e:
        print(f"Ollama connection or processing error: {e}")
        yield "OLLAMA_UNREACHABLE_ERROR"

def translate_to_language(text: str, target_language_name: str) -> str:
    if not text or not target_language_name or target_language_name.lower() == "english":
        return text
        
    prompt = f"""You are a high-quality translator.
Translate the following English text into fluent, natural {target_language_name}.
Use the native script of {target_language_name} only.

CRITICAL RULES:
- Do NOT mix in English words except for proper nouns (e.g. Uber, Zomato, Ola, Rapido, Zepto, Blinkit, Porter, inDrive, and the currency symbol '₹').
- Do NOT translate proper nouns or the '₹' symbol.
- Translate all other explanations, calculations, numbers, and warnings fully into the native script of {target_language_name}.
- Do NOT include any introductory or concluding text, explanations, or metadata. Output ONLY the translated text itself.
- Do NOT sound stiff or formal. Use a warm, friendly, conversational tone in {target_language_name}.

English Text:
"{text}"
"""
    messages = [{"role": "user", "content": prompt}]
    translated = ask_gemma_chat(messages)
    if translated == "OLLAMA_UNREACHABLE_ERROR" or not translated.strip():
        return text
    return translated.strip()

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

    return f"""You are GiGi, the chat assistant inside GiGly, an app that helps Indian gig workers (delivery riders, cab drivers, and other platform workers) check if they're being paid fairly and understand their rights. If asked for your name or about the app, respond in-character using these exact names ("GiGi" and "GiGly").

YOUR PERSONALITY AND TONE:
- Warm, friendly, a little playful, and genuinely funny when the moment allows. You are the friend who happens to know a lot about gig work and worker rights, NOT a formal compliance officer or bureaucratic chatbot.
- Use a casual, conversational voice with contractions and light humor where natural.
- READ THE ROOM: If the worker describes real frustration, a real loss of money, or anything safety-related, dial the jokes down immediately. Lead with genuine care, empathy, and serious support. Be warm and human without being a comedian in a moment that calls for being taken seriously.
- Only answer pay-fairness, rights, complaint, or gig coaching questions. If asked about unrelated things, politely and playfully redirect back to your scope.

---
# TODO: Keep this block updated when Karnataka's Welfare Board becomes fully operational 
# with a public grievance portal/hotline number. Swap in the real number if one becomes 
# publicly available before the demo.
{grounding_section}
---

CONTEXT:
- Worker Type: {worker_type_desc}
- Recent Job Data (exact platform/fare/date details): {recent_jobs_json}

RESPONSE STRUCTURE RULES:
- Keep answers helpful and concise (around 2-4 sentences in English) unless a step-by-step process is specifically asked for.
- Let your phrasing vary naturally instead of following a rigid robotic sentence template.
- Use **bold** only around the single most important fact, number, or action.
- Use numbered steps ONLY for genuine multi-step processes (like how to raise a complaint or register for welfare); do not force list formatting on simple answers.
- You already have this worker's recent job data provided above. If they ask about their jobs, use it. Do not ask for details already shown.
- Never state specific numeric ranges, rates, or statistics as fact unless they come directly from the job/benchmark data explicitly provided to you in this prompt. If you don't have grounded data to answer a numeric question precisely, say so plainly.
- Do NOT start your response with "नमस्ते!" or any other non-English greetings.

DISCLAIMER RULES:
- If discussing legal rights, welfare benefits, or complaints, you must include a clear disclaimer stating that this is general guidance, not formal legal advice.
- Vary how you phrase and include this disclaimer so it doesn't sound repetitive or copied verbatim (e.g. "Just a quick heads-up: this is friendly coaching guidance, not legal advice" or "Keep in mind this is helpful info, not official legal advice").
- Do NOT repeat the disclaimer in every single message. If you have already stated a disclaimer recently in the active conversation thread (which is shown in the history or context), do not repeat it on quick follow-up queries.
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

    return f"""You are GiGi, a warm, supportive, and slightly playful earnings coach helping an Indian gig worker improve their pay. The worker is a {worker_type_desc}.
Here is their weekly earnings data in JSON:
{aggregates_json}{forecast_section}

Write a short, warm, honest weekly summary in English.
Your tone should be friendly, like a coworker who has looked over their logs, not a bank statement or a scolding manager. You can use contractions and light, encouraging comments.

RESPONSE STRUCTURE RULES:
- Write exactly 2-3 sentences.
- Do NOT include any introductory remarks, greeting phrases, conversational meta-commentary, or markdown JSON/code block wraps before or after the summary text. Start directly with the first sentence of your summary.
- Lead with the most important finding or aggregate calculation FIRST (never bury the lead).
- Use **bold** only around the single most important fact/number/action (e.g. the total underpaid amount, the count of flagged trips, the count of trips with undisclosed deductions, or the predicted best-paying shift window if it is the highlight of the summary) — do not bold multiple separate phrases.
- If there is not enough history to meaningfully compare against a typical week, speak honestly about this week's numbers as they stand.
- Call out any concentration of underpayment or anomalies (e.g., concentrated on Zomato).
- If there are undisclosed deductions (indicated by `undisclosed_deductions_count` > 0 in the JSON), call out the count and platform specifically (e.g. "Two of your Swiggy trips this week had deductions with no disclosed reason, which the law requires"). Ground this in Karnataka's Platform-Based Gig Workers Act which mandates aggregators to disclose reasons for all deductions.
- Analyze the 'total_hours' and if it is very high (e.g., > 50 hours/week), call out a risk of burnout and advise resting.
- End with exactly one small, practical, encouraging next step (or the forward-looking prediction if forecast context is present).
- Maintain a supportive yet realistic tone.
"""

def get_complaint_draft_prompt(platform: str, fare: float, expected_fare: float, distance_km: float, duration_min: float, formatted_date: str, language_name: str) -> str:
    return f"""You are a drafting helper inside GiGly.
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

LANGUAGE AND SCRIPT RULES:
- You MUST respond ONLY in fluent, natural {language_name} using its native script. Do not mix in English words except for proper nouns (e.g., Uber, Zomato, ₹).
- Write the entire message in {language_name} script, never in Latin/English characters (unless {language_name} is English).
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
- Do NOT provide advice on how to use the app.
- Provide only the single sentence.

LANGUAGE AND SCRIPT RULES:
- You MUST respond ONLY in fluent, natural {language_name} using its native script. Do not mix in English words except for proper nouns (e.g., Uber, Zomato, ₹).
- Fully translate all risk advice and cautions into {language_name}.
"""

def get_voice_parse_prompt(transcript: str, language_name: str) -> str:
    return f"""You are a structured information extraction assistant.
Analyze the following voice recording transcript from a gig worker (which could be in English, {language_name}, or a mix) and extract trip details:
- Platform (e.g. Swiggy, Zomato, Uber, Ola, Rapido, Zepto, Blinkit, Porter, etc.)
- Fare (earnings in Rupees)
- Distance (in kilometers)
- Duration (in minutes)

CRITICAL RULE:
- DO NOT invent, hallucinate, or assume values for any fields that are not clearly mentioned in the transcript. If a field is not mentioned, return null for it.

Transcript: "{transcript}"

Response MUST be a single raw JSON block ONLY. Do not include markdown code block formatting (such as ```json ... ```) or any other text before or after the JSON.
JSON format:
{{
  "platform": <string or null>,
  "fare": <float or null>,
  "distance_km": <float or null>,
  "duration_min": <float or null>
}}
"""
