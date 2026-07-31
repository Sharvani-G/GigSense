from fastapi import FastAPI, UploadFile, File, status
from fastapi.responses import JSONResponse
from dotenv import load_dotenv
import os

# Load environment variables FIRST before importing other modules
load_dotenv()

import json
import datetime
from ocr import extract_job_data
from llm import ask_gemma
from schemas import JobScanResponse, ChatRequest, ComplaintRequest
from firebase_client import db
from firebase_admin import firestore

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

# Map language codes to full names that Gemma follows reliably
LANGUAGE_NAMES = {
    'en': 'English',
    'hi': 'Hindi',
    'kn': 'Kannada',
    'ta': 'Tamil',
    'te': 'Telugu',
}

def get_user_profile(user_id: str) -> dict:
    """Fetch the user's profile from Firestore. Returns defaults on error."""
    if db is None or not user_id or user_id == 'anonymous_user':
        return {'preferredLanguage': 'en', 'workerType': 'other_gig_worker'}
    try:
        doc = db.collection('users').document(user_id).get()
        if doc.exists:
            data = doc.to_dict()
            return {
                'preferredLanguage': data.get('preferredLanguage', 'en') or 'en',
                'workerType': data.get('workerType', 'other_gig_worker') or 'other_gig_worker'
            }
    except Exception as e:
        print(f"Error fetching user profile: {e}")
    return {'preferredLanguage': 'en', 'workerType': 'other_gig_worker'}

WORKER_TYPE_DESCRIPTIONS = {
    'cab_driver': 'cab driver (focusing on fare optimization, fuel/commission costs, and longer trips)',
    'delivery_rider': 'delivery rider (focusing on rapid multi-stop deliveries, route delays, delivery incentives, and weather hazards)',
    'other_gig_worker': 'gig worker'
}

def get_user_language(user_id: str) -> str:
    """Fetch the user's preferredLanguage from Firestore. Returns 'en' on any error."""
    return get_user_profile(user_id).get('preferredLanguage', 'en')

@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    recent_jobs = get_recent_jobs(request.user_id)
    recent_jobs_json = json.dumps(recent_jobs)

    conversation_history_str = ""
    messages_ref = None
    if db is not None:
        try:
            messages_ref = (
                db.collection("users")
                .document(request.user_id)
                .collection("chatSessions")
                .document(request.session_id)
                .collection("messages")
            )
            # Fetch last 10 messages from session to build chat history
            docs = messages_ref.order_by("timestamp", direction=firestore.Query.DESCENDING).limit(10).get()
            history = [doc.to_dict() for doc in docs]
            history.reverse()  # reverse to chronological order
            
            for msg in history:
                role = msg.get("role", "user")
                content = msg.get("content", "")
                role_label = "Worker" if role == "user" else "Assistant"
                conversation_history_str += f"{role_label}: {content}\n"
        except Exception as e:
            print(f"Error fetching chat history: {e}")

    profile = get_user_profile(request.user_id)
    lang_code = profile.get('preferredLanguage', 'en')
    worker_type = profile.get('workerType', 'other_gig_worker')
    worker_type_desc = WORKER_TYPE_DESCRIPTIONS.get(worker_type, 'gig worker')

    system_prompt = f"""You are a friendly, practical assistant helping gig workers in India understand their pay and rights. The worker is a {worker_type_desc}. Tailor your advice and tone specifically to their gig type (e.g. optimizing trips, incentives, platform differences). Explain things simply, avoid legal jargon, be warm but honest — you are on the worker's side. Here is the worker's recent job data for context: {recent_jobs_json}. If asked whether a fare is fair, refer to this specific data rather than speaking generically. If asked about rights or how to raise a complaint, give practical general guidance appropriate to gig work in India, and make clear this is general informational guidance, not legal advice.

Here is the conversation history for context:
{conversation_history_str}

    Structure your responses cleanly for a mobile screen: use short paragraphs, bold text for key numbers/terms, and bullet points for lists to make details easy to scan. Respond in {LANGUAGE_NAMES.get(lang_code, 'English')}."""

    response_text = ask_gemma(request.message, system_prompt)

    if response_text == "OLLAMA_UNREACHABLE_ERROR":
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"error": "Assistant is temporarily unavailable — please try again in a moment."}
        )

    # Save user message and assistant reply to Firestore server-side
    if messages_ref is not None:
        try:
            messages_ref.add({
                "role": "user",
                "content": request.message,
                "timestamp": firestore.SERVER_TIMESTAMP
            })
            messages_ref.add({
                "role": "assistant",
                "content": response_text,
                "timestamp": firestore.SERVER_TIMESTAMP
            })
            
            session_ref = (
                db.collection("users")
                .document(request.user_id)
                .collection("chatSessions")
                .document(request.session_id)
            )
            session_ref.set({
                "updatedAt": firestore.SERVER_TIMESTAMP
            }, merge=True)
        except Exception as e:
            print(f"Error saving chat to Firestore: {e}")

    return {"response": response_text}

def get_weekly_aggregates(user_id: str) -> dict:
    if db is None:
        return {
            "total_earnings": 0.0,
            "total_hours": 0.0,
            "flagged_count": 0,
            "total_jobs": 0,
            "platforms": {}
        }
    try:
        now = datetime.datetime.now(datetime.timezone.utc)
        seven_days_ago = now - datetime.timedelta(days=7)
        
        jobs_ref = db.collection("jobs")
        docs = jobs_ref.where("user_id", "==", user_id).stream()
        
        total_earnings = 0.0
        total_minutes = 0.0
        flagged_count = 0
        total_jobs = 0
        platforms = {}
        
        for doc in docs:
            job = doc.to_dict()
            # check timestamp
            ts_str = job.get("created_at") or job.get("job_timestamp")
            if not ts_str:
                continue
            
            # parse ISO format string or use datetime object directly
            try:
                if hasattr(ts_str, "isoformat"):
                    dt = ts_str
                else:
                    clean_ts = str(ts_str).replace("Z", "+00:00")
                    dt = datetime.datetime.fromisoformat(clean_ts)
            except Exception:
                continue
                
            if dt < seven_days_ago:
                continue
                
            total_jobs += 1
            fare = float(job.get("fare") or 0.0)
            duration = float(job.get("duration_min") or 0.0)
            is_underpaid = job.get("is_underpaid") == True
            platform = job.get("platform") or "other"
            
            total_earnings += fare
            total_minutes += duration
            if is_underpaid:
                flagged_count += 1
                
            platforms[platform] = platforms.get(platform, 0.0) + fare
            
        return {
            "total_earnings": round(total_earnings, 2),
            "total_hours": round(total_minutes / 60.0, 1),
            "flagged_count": flagged_count,
            "total_jobs": total_jobs,
            "platforms": platforms
        }
    except Exception as e:
        print(f"Error calculating weekly aggregates: {e}")
        return {
            "total_earnings": 0.0,
            "total_hours": 0.0,
            "flagged_count": 0,
            "total_jobs": 0,
            "platforms": {}
        }

@app.get("/weekly-insight")
async def weekly_insight(user_id: str):
    aggregates = get_weekly_aggregates(user_id)
    
    if aggregates["total_jobs"] == 0:
        return {
            "insight_text": "Log a few jobs and I'll have your first weekly insight ready.",
            "stats_used": None
        }
        
    profile = get_user_profile(user_id)
    lang_code = profile.get('preferredLanguage', 'en')
    worker_type = profile.get('workerType', 'other_gig_worker')
    worker_type_desc = WORKER_TYPE_DESCRIPTIONS.get(worker_type, 'gig worker')

    prompt = f"""Here is a {worker_type_desc}'s earnings data for this week, in JSON:
    {json.dumps(aggregates)}. Write a short, warm, honest 2-3 sentence summary as
    if you are a supportive coach speaking directly to them. Tailor your coaching insights specifically to their type of gig work. If there isn't
    enough history to meaningfully compare against a typical week, just speak
    honestly about this week's numbers as they stand. Call out anything
    genuinely worth flagging — for example if underpayment concentrated on a
    particular platform, or if a noticeable share of the week's flagged jobs
    share something in common based on the data given. End with one small,
    practical, encouraging next step. Do not be falsely positive if the data
    shows a real problem — be honest, but always supportive in tone, never
    scolding. Respond in {LANGUAGE_NAMES.get(lang_code, 'English')}."""

    insight_text = ask_gemma(prompt)
    
    if insight_text == "OLLAMA_UNREACHABLE_ERROR":
        insight_text = "I'm having trouble generating your weekly summary right now. Your logged stats below are safe and up to date."
        
    return {
        "insight_text": insight_text,
        "stats_used": aggregates
    }

@app.post("/jobs/draft-complaint")
async def draft_complaint_endpoint(request: ComplaintRequest):
    profile = get_user_profile(request.user_id)
    lang_code = profile.get('preferredLanguage', 'en')
    language_name = LANGUAGE_NAMES.get(lang_code, 'English')
    underpaid_diff = max(0.0, request.expected_fare - request.fare)
    
    prompt = f"""You are writing a short, polite, factual complaint message for a gig worker in India to copy-paste into the platform's support chat. The platform is {request.platform}. The trip parameters were: Actual fare earned was ₹{request.fare:.2f}, distance was {request.distance_km:.1f} km, duration was {request.duration_min:.0f} minutes. The standard benchmark fare for this trip should have been ₹{request.expected_fare:.2f}, meaning the worker was underpaid by ₹{underpaid_diff:.2f}.
    Write a polite, direct 2-3 sentence request in {language_name} for support to review this specific payout. Do not include any greeting placeholders, user name placeholders, or date placeholders - write it so it is ready to copy and paste directly as a chat message."""

    draft_text = ask_gemma(prompt)
    if draft_text == "OLLAMA_UNREACHABLE_ERROR":
        # Return offline fallback complaint template in correct language
        fallbacks = {
            'en': f"Hello support. I am writing regarding my ride on {request.platform}. I was paid ₹{request.fare:.2f} for a trip of {request.distance_km:.1f} km and {request.duration_min:.0f} mins. Based on benchmark rates, the expected fare is ₹{request.expected_fare:.2f}. Please review this calculation and adjust my payout. Thank you.",
            'hi': f"नमस्ते सहायता टीम। मैं {request.platform} पर अपनी सवारी के संबंध में लिख रहा हूँ। मुझे {request.distance_km:.1f} किमी और {request.duration_min:.0f} मिनट की यात्रा के लिए ₹{request.fare:.2f} का भुगतान किया गया था। बेंचमार्क दरों के आधार पर, अपेक्षित किराया ₹{request.expected_fare:.2f} होना चाहिए। कृपया इस भुगतान की समीक्षा करें। धन्यवाद।",
            'kn': f"ನಮಸ್ಕಾರ ಸಹಾಯ ಕೇಂದ್ರ. {request.platform} ನಲ್ಲಿ ನನ್ನ ಪಯಣದ ಕುರಿತು ನಾನು ಬರೆಯುತ್ತಿದ್ದೇನೆ. {request.distance_km:.1f} ಕಿಮೀ ಮತ್ತು {request.duration_min:.0f} ನಿಮಿಷಗಳ ಪ್ರಯಾಣಕ್ಕೆ ನನಗೆ ₹{request.fare:.2f} ಪಾವತಿಸಲಾಗಿದೆ. ದರಗಳ ಪ್ರಕಾರ, ನಿರೀಕ್ಷಿತ ದರ ₹{request.expected_fare:.2f} ಇರಬೇಕು. ದಯವಿಟ್ಟು ಇದನ್ನು ಪರಿಶೀಲಿಸಿ ನನ್ನ ಪಾವತಿಯನ್ನು ಸರಿಪಡಿಸಿ. ಧನ್ಯವಾದಗಳು.",
            'ta': f"வணக்கம் உதவி மையம். {request.platform} இல் எனது பயணம் குறித்து நான் எழுதுகிறேன். {request.distance_km:.1f} கிமீ மற்றும் {request.duration_min:.0f} நிமிட பயணத்திற்கு எனக்கு ₹{request.fare:.2f} வழங்கப்பட்டது. தரநிலைகளின்படி, எதிர்பார்க்கப்படும் கட்டணம் ₹{request.expected_fare:.2f} ஆகும். தயவுசெய்து இதை மறுபரிசீலனை செய்து சரிசெய்யவும். நன்றி.",
            'te': f"నమస్కారం సహాయ కేంద్రం. {request.platform} లో నా ప్రయాణానికి సంబంధించి నేను వ్రాస్తున్నాను. {request.distance_km:.1f} కిమీ మరియు {request.duration_min:.0f} నిమిషాల ప్రయాణానికి నాకు ₹{request.fare:.2f} చెల్లించబడింది. ప్రామాణిక రేట్ల ప్రకారం, ఆశించిన ఛార్జీ ₹{request.expected_fare:.2f} ఉండాలి. దయస చేసి దీనిని సమీక్షించండి. ధన్యవాదాలు."
        }
        draft_text = fallbacks.get(lang_code, fallbacks['en'])
        
    return {"complaint_draft": draft_text}
