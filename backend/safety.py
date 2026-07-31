import datetime
from typing import Tuple
from llm import ask_gemma, get_route_safety_prompt

def compute_route_safety_score(job_timestamp: str, area_hint: str = None, language_name: str = "English") -> Tuple[str, str]:
    \"\"\"
    Returns a tuple of (score, message).
    score is one of: "low", "moderate", "higher"
    \"\"\"
    try:
        # Parse timestamp string to datetime object
        if hasattr(job_timestamp, "isoformat"):
            dt = job_timestamp
        else:
            clean_ts = str(job_timestamp).replace("Z", "+00:00")
            dt = datetime.datetime.fromisoformat(clean_ts)
            
        # Convert to IST context (assuming jobs are logged locally in India usually, 
        # but let's just use the hour of the provided timestamp assuming it's localized or we just check the hour)
        # Assuming job_timestamp from Flutter is in local time iso8601
        hour = dt.hour
    except Exception:
        # Fallback to current local hour if parsing fails
        hour = datetime.datetime.now().hour

    # Time bands based on prompt specs:
    # Daytime (05:00-20:59): low risk
    # Evening (21:00-22:59): moderate risk
    # Late-night (23:00-4:59): higher risk

    if 5 <= hour < 21:
        time_band = "Daytime"
        score = "low"
    elif 21 <= hour < 23:
        time_band = "Evening"
        score = "moderate"
    else:
        time_band = "Late-night"
        score = "higher"

    # Only generate a message for moderate/higher risk, or if area hint is provided?
    # The spec says: "If an area_hint is provided... pass this along with the time band to Gemma"
    # Wait, the spec says "Do NOT show this indicator at all for daytime jobs" 
    # So we don't need a message for low risk.
    if score == "low":
        return score, ""
        
    hint = area_hint if area_hint and area_hint.strip() else "Unknown area"

    prompt = get_route_safety_prompt(time_band, hint, language_name)
    message = ask_gemma(prompt)
    
    if message == "OLLAMA_UNREACHABLE_ERROR":
        message = f"{time_band} trips warrant extra caution; consider sharing your trip details with someone you trust."
        
    return score, message
