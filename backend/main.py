from fastapi import FastAPI, UploadFile, File, status
from fastapi.responses import JSONResponse
from dotenv import load_dotenv
import os
import json
from ocr import extract_job_data
from llm import ask_gemma
from schemas import JobScanResponse, ChatRequest
from firebase_client import db

# Load environment variables
load_dotenv()

app = FastAPI(title="GigShield API")

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.post("/jobs/scan")
async def scan_job_screenshot(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()
        extracted_data = extract_job_data(image_bytes)
        return JSONResponse(status_code=status.HTTP_200_OK, content=extracted_data)
    except Exception as e:
        print(f"Error processing image: {e}")
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content={"error": "Could not process image"}
        )

def get_recent_jobs(user_id: str) -> list:
    if db is None:
        return []
    try:
        jobs_ref = db.collection("jobs")
        # Index-free query to query by user_id and sort in-memory
        docs = jobs_ref.where("user_id", "==", user_id).stream()
        jobs = []
        for doc in docs:
            data = doc.to_dict()
            # Convert timestamp fields to strings to avoid json serialization issues
            for k, v in list(data.items()):
                if hasattr(v, "isoformat"):
                    data[k] = v.isoformat()
            data["id"] = doc.id
            jobs.append(data)
        
        # Sort in memory descending
        def get_time_key(job):
            t = job.get("created_at") or job.get("job_timestamp")
            return str(t) if t is not None else ""
            
        jobs.sort(key=get_time_key, reverse=True)
        return jobs[:5]
    except Exception as e:
        print(f"Error fetching recent jobs: {e}")
        return []

@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    recent_jobs = get_recent_jobs(request.user_id)
    recent_jobs_json = json.dumps(recent_jobs)

    system_prompt = f"""You are a friendly, practical assistant helping gig workers (delivery riders, cab drivers) in India understand their pay and rights. Explain things simply, avoid legal jargon, be warm but honest — you are on the worker's side. Here is the worker's recent job data for context: {recent_jobs_json}. If asked whether a fare is fair, refer to this specific data rather than speaking generically. If asked about rights or how to raise a complaint, give practical general guidance appropriate to gig work in India, and make clear this is general informational guidance, not legal advice.

    Structure your responses cleanly for a mobile screen: use short paragraphs, bold text for key numbers/terms, and bullet points for lists to make details easy to scan."""

    response_text = ask_gemma(request.message, system_prompt)

    if response_text == "OLLAMA_UNREACHABLE_ERROR":
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"error": "Assistant is temporarily unavailable — please try again in a moment."}
        )

    return {"response": response_text}

@app.get("/weekly-insight")
async def weekly_insight(user_id: str):
    aggregates = get_weekly_aggregates(user_id)
    
    if aggregates["total_jobs"] == 0:
        return {
            "insight_text": "Log a few jobs and I'll have your first weekly insight ready.",
            "stats_used": None
        }
        
    prompt = f"""Here is a gig worker's earnings data for this week, in JSON:
    {json.dumps(aggregates)}. Write a short, warm, honest 2-3 sentence summary as
    if you are a supportive coach speaking directly to them. If there isn't
    enough history to meaningfully compare against a typical week, just speak
    honestly about this week's numbers as they stand. Call out anything
    genuinely worth flagging — for example if underpayment concentrated on a
    particular platform, or if a noticeable share of the week's flagged jobs
    share something in common based on the data given. End with one small,
    practical, encouraging next step. Do not be falsely positive if the data
    shows a real problem — be honest, but always supportive in tone, never
    scolding."""

    insight_text = ask_gemma(prompt)
    
    if insight_text == "OLLAMA_UNREACHABLE_ERROR":
        insight_text = "I'm having trouble generating your weekly summary right now. Your logged stats below are safe and up to date."
        
    return {
        "insight_text": insight_text,
        "stats_used": aggregates
    }
