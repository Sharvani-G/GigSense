import requests

def ask_gemma(prompt: str, system_prompt: str = "") -> str:
    url = "http://localhost:11434/api/generate"
    payload = {
        "model": "gemma3:4b",
        "prompt": f"{system_prompt}\n\nUser: {prompt}" if system_prompt else prompt,
        "stream": False
    }
    try:
        response = requests.post(url, json=payload, timeout=20)
        response.raise_for_status()
        return response.json().get("response", "")
    except Exception as e:
        print(f"Ollama connection or processing error: {e}")
        return "OLLAMA_UNREACHABLE_ERROR"

def generate_chat_response(prompt: str) -> str:
    return ask_gemma(prompt)

def generate_weekly_insight(data: dict) -> str:
    # Placeholder for Weekly Insight generation
    pass
