from fastapi import FastAPI, UploadFile, File, Form, status
from fastapi.responses import JSONResponse, StreamingResponse
from dotenv import load_dotenv
from typing import Optional

# Load environment variables first
load_dotenv()

import os

# Load environment variables FIRST before importing other modules
load_dotenv()

import json
import datetime
from ocr import extract_job_data
from stt import transcribe_audio
from llm import ask_gemma, ask_gemma_stream, get_chat_system_prompt, get_weekly_insight_prompt, get_complaint_draft_prompt, ask_gemma_chat, ask_gemma_chat_stream, translate_to_language
from schemas import JobScanResponse, ChatRequest, ChatResponse, ComplaintRequest, DraftRequest, FatigueRequest, SOSRequest, RouteSafetyRequest, RouteSafetyResponse, VoiceParseRequest
from firebase_client import db
from firebase_admin import firestore

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="GiGly API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

import asyncio

@app.on_event("startup")
async def startup_event():
    # Run recalculate benchmarks in the background
    asyncio.create_task(recalculate_benchmarks())


@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.post("/jobs/scan")
async def scan_job_screenshot(file: UploadFile = File(...)):
    # STAGE 1 LOGGING: Log file details unconditionally
    content_type = file.content_type
    filename = file.filename
    print(f"[OCR] Received file: name='{filename}', content_type='{content_type}'")
    try:
        image_bytes = await file.read()
        byte_size = len(image_bytes)
        print(f"[OCR] File byte size: {byte_size} bytes")
        
        # Extract data
        extracted_data = extract_job_data(image_bytes)
        
        # STAGE 2 LOGGING: Log raw OCR text unconditionally
        raw_text = extracted_data.get("raw_text", "")
        print(f"[OCR] Raw OCR output text:\n--------------------------\n{raw_text}\n--------------------------")
        
        return JSONResponse(status_code=status.HTTP_200_OK, content=extracted_data)
    except Exception as e:
        print(f"[OCR] Error processing image: {e}")
        import traceback
        traceback.print_exc()
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content={"error": f"Could not process image: {str(e)}"}
        )

@app.post("/stt")
async def speech_to_text_endpoint(
    audio: UploadFile = File(...),
    language: str = Form(...)
):
    # 1. Input Validation
    supported_langs = {'en', 'hi', 'kn', 'te', 'ta', 'ml'}
    if not language or language.lower() not in supported_langs:
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content={"error": f"Unsupported or missing language: '{language}'"}
        )
        
    if not audio or not audio.filename:
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content={"error": "Audio file is missing or invalid"}
        )

    try:
        import tempfile
        suffix = os.path.splitext(audio.filename)[1] if audio.filename else ".m4a"
        
        content = await audio.read()
        if not content:
            return JSONResponse(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                content={"error": "Uploaded audio file is empty"}
            )

        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_audio:
            temp_audio.write(content)
            temp_audio_path = temp_audio.name

        try:
            transcript = transcribe_audio(temp_audio_path, language_code=language.lower())
            return {"transcript": transcript}
        finally:
            if os.path.exists(temp_audio_path):
                os.remove(temp_audio_path)
    except Exception as e:
        print(f"Error in speech_to_text: {e}")
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"error": f"Could not transcribe audio: {str(e)}"}
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
    'ml': 'Malayalam',
}

NO_FARE_RESPONSES = {
    'en': "I don't see anything related to your gig work in this image — can you describe what you'd like help with?",
    'hi': "मुझे इस छवि में आपके गिग काम से संबंधित कुछ भी नहीं दिख रहा है — क्या आप बता सकते हैं कि आपको किस प्रकार की सहायता चाहिए?",
    'kn': "ಈ ಚಿತ್ರದಲ್ಲಿ ನಿಮ್ಮ ಗಿಗ್ ಕೆಲಸಕ್ಕೆ ಸಂಬಂಧಿಸಿದ ಯಾವುದೇ ವಿವರ ನನಗೆ ಕಾಣಿಸುತ್ತಿಲ್ಲ — ನಿಮಗೆ ಯಾವ ರೀತಿಯ ಸಹಾಯ ಬೇಕು ಎಂದು ವಿவರಿಸಬಹುದೇ?",
    'ta': "இந்தப் படத்தில் உங்கள் கிக் வேலை தொடர்பான எதுவும் எனக்குத் தெரியவில்லை — உங்களுக்கு என்ன உதவி வேண்டும் என்று விவரிக்க முடியுமா?",
    'te': "ఈ చిత్రంలో మీ గిగ్ పనికి సంబంధించినది ఏదీ నాకు కనిపించడం లేదు — మీకు ఎలాంటి సహాయం కావాలో వివరించగలరా?",
    'ml': "ഈ ചിത്രത്തിൽ നിങ്ങളുടെ ഗിഗ് ജോലിയുമായി ബന്ധപ്പെട്ട ഒന്നും എനിക്ക് കാണാൻ കഴിയുന്നില്ല — നിങ്ങൾക്ക് എന്ത് സഹായമാണ് വേണ്ടതെന്ന് വിവരിക്കാമോ?"
}

REPEATED_IRRELEVANT_RESPONSES = {
    'en': "Please upload a relevant gig work screenshot, receipt, or platform message so I can help you analyze it.",
    'hi': "कृपया एक प्रासंगिक गिग काम का स्क्रीनशॉट, रसीद या प्लेटफॉर्म संदेश अपलोड करें ताकि मैं इसका विश्लेषण करने में आपकी मदद कर सकूं।",
    'kn': "ದಯವಿಟ್ಟು ಸಂಬಂಧಿತ ಗಿಗ್ ಕೆಲಸದ ಸ್ಕ್ರೀನ್‌ಶಾಟ್, ರಶೀದಿ ಅಥವಾ ಪ್ಲಾಟ್‌ಫಾರ್ಮ್ ಸಂದೇಶವನ್ನು ಅಪ್‌ಲೋಡ್ ಮಾಡಿ ಇದರಿಂದ ನಾನು ಅದನ್ನು ವಿಶ್ಲೇಷಿಸಲು ನಿಮಗೆ ಸಹಾಯ ಮಾಡಬಹುದು.",
    'ta': "தொடர்புடைய கிக் வேலை ஸ்கிரێنیஷாட், ரசீது அல்லது பிளாட்ஃபார்ம் செய்தியைப் பதிவேற்றவும், இதனால் அதை பகுப்பாய்வு செய்ய நான் உங்களுக்கு உதவ முடியும்.",
    'te': "దయచేసి సంబంధಿತ గిగ్ వర్క్ స్క్రీన్‌షాట్, రసీదు లేదా ప్లాట్‌ఫారమ్ సందೇಶాన్ని అప్‌లోഡ് చేయండి, తద్വారా నేను దానిని విಶ್ಲೇషించడంలో మీకు సహాయపడగలను.",
    'ml': "ദയവായി പ്രസക്തമായ ഒരു ഗിഗ് വർക്ക് സ്ക്രീൻഷോട്ട്, രസീത് അല്ലെങ്കിൽ പ്ലാറ്റ്ഫോം സന്ദേശം അപ്‌ലോഡ് ചെയ്യുക, അതുവഴി അത് വിശകലനം ചെയ്യാൻ എനിക്ക് നിങ്ങളെ സഹായിക്കാനാകും."
}

def get_user_profile(user_id: str) -> dict:
    """Fetch the user's profile from Firestore. Returns defaults on error."""
    if db is None or not user_id or user_id == 'anonymous_user':
        return {'preferredLanguage': 'en', 'workerType': 'other_gig_worker'}
    try:
        doc = db.collection('users').document(user_id).get()
        if doc.exists:
            data = doc.to_dict()
            res = dict(data)
            res['preferredLanguage'] = data.get('preferredLanguage', 'en') or 'en'
            res['workerType'] = data.get('workerType', 'other_gig_worker') or 'other_gig_worker'
            return res
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
    recent_jobs = get_recent_jobs(request.user_id)[:5]
    recent_jobs_json = json.dumps(recent_jobs)

    history = []
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
    worker_types = profile.get('workerTypes')
    if not isinstance(worker_types, list):
        worker_types = [worker_type]
    
    working_platforms = profile.get('workingPlatforms')
    if not isinstance(working_platforms, list):
        working_platforms = []
        
    experience_years = profile.get('experienceYears', 0)
    experience_months = profile.get('experienceMonths', 0)
    bio = profile.get('bio', '')
    
    worker_type_descs = [WORKER_TYPE_DESCRIPTIONS.get(wt, 'gig worker') for wt in worker_types]
    worker_type_desc = " and ".join(worker_type_descs)
    
    extra_details = []
    if working_platforms:
        extra_details.append(f"works on: {', '.join(working_platforms)}")
    if experience_years > 0 or experience_months > 0:
        extra_details.append(f"experience: {experience_years} years, {experience_months} months")
    if bio:
        extra_details.append(f"bio/notes: {bio}")
        
    if extra_details:
        worker_type_desc += " (" + "; ".join(extra_details) + ")"
        
    language_name = LANGUAGE_NAMES.get(lang_code, 'English')

    system_prompt = get_chat_system_prompt(
        query=request.message,
        worker_type_desc=worker_type_desc,
        recent_jobs_json=recent_jobs_json,
        conversation_history_str=conversation_history_str,
        language_name=language_name
    )

    async def event_generator():
        nonlocal language_name
        full_response = ""
        if request.message.startswith("[IMAGE NO FARE]:"):
            has_previous_irrelevant = any(msg.get("role") == "user" and msg.get("content", "").startswith("[IMAGE NO FARE]:") for msg in history)
            if has_previous_irrelevant:
                static_res = REPEATED_IRRELEVANT_RESPONSES.get(lang_code, REPEATED_IRRELEVANT_RESPONSES['en'])
            else:
                static_res = NO_FARE_RESPONSES.get(lang_code, NO_FARE_RESPONSES['en'])
                
            # Stream static response chunk by chunk to simulate typing
            words = static_res.split(" ")
            for i, word in enumerate(words):
                chunk = word + (" " if i < len(words) - 1 else "")
                full_response += chunk
                yield json.dumps({"chunk": chunk}) + "\n"
                await asyncio.sleep(0.02)
        else:
            # Construct message history list for Ollama's Chat API
            chat_messages = []
            
            # System instruction
            chat_messages.append({
                "role": "system",
                "content": system_prompt
            })
            
            # Append preceding conversation history
            for msg in history:
                role = msg.get("role", "user")
                content = msg.get("content", "")
                chat_messages.append({
                    "role": "user" if role == "user" else "assistant",
                    "content": content
                })
                
            # Append current user query
            chat_messages.append({
                "role": "user",
                "content": request.message
            })

            is_english = language_name.lower() == "english"
            
            if is_english:
                # Stream directly
                for chunk in ask_gemma_chat_stream(chat_messages):
                    if chunk == "OLLAMA_UNREACHABLE_ERROR":
                        yield json.dumps({"error": "Assistant is temporarily unavailable — please try again in a moment."}) + "\n"
                        return
                    full_response += chunk
                    yield json.dumps({"chunk": chunk}) + "\n"
                    await asyncio.sleep(0.001)
            else:
                # Generate full English response first
                english_response = ""
                for chunk in ask_gemma_chat_stream(chat_messages):
                    if chunk == "OLLAMA_UNREACHABLE_ERROR":
                        yield json.dumps({"error": "Assistant is temporarily unavailable — please try again in a moment."}) + "\n"
                        return
                    english_response += chunk
                    await asyncio.sleep(0.001)
                
                # Perform the second stage translation to target language
                translated_response = translate_to_language(english_response, language_name)
                full_response = translated_response
                
                # Stream the translation chunks to the client
                words = translated_response.split(" ")
                for i, word in enumerate(words):
                    chunk = word + (" " if i < len(words) - 1 else "")
                    yield json.dumps({"chunk": chunk}) + "\n"
                    await asyncio.sleep(0.01)

        # Save user message and assistant reply to Firestore server-side
        if messages_ref is not None and full_response:
            try:
                messages_ref.add({
                    "role": "user",
                    "content": request.message,
                    "timestamp": firestore.SERVER_TIMESTAMP
                })
                messages_ref.add({
                    "role": "assistant",
                    "content": full_response,
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

    return StreamingResponse(event_generator(), media_type="application/x-ndjson")

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
        undisclosed_deductions_count = 0
        undisclosed_deductions_by_platform = {}
        
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
            
            # check for undisclosed deduction
            deduction = job.get("deduction_amount")
            deduction_amount = float(deduction) if deduction is not None else 0.0
            reason_stated = job.get("deduction_reason_stated") == True
            is_undisclosed = deduction_amount > 0.0 and not reason_stated
            
            total_earnings += fare
            total_minutes += duration
            if is_underpaid:
                flagged_count += 1
            if is_undisclosed:
                undisclosed_deductions_count += 1
                undisclosed_deductions_by_platform[platform] = undisclosed_deductions_by_platform.get(platform, 0) + 1
                
            platforms[platform] = platforms.get(platform, 0.0) + fare
            
        return {
            "total_earnings": round(total_earnings, 2),
            "total_hours": round(total_minutes / 60.0, 1),
            "flagged_count": flagged_count,
            "total_jobs": total_jobs,
            "platforms": platforms,
            "undisclosed_deductions_count": undisclosed_deductions_count,
            "undisclosed_deductions_by_platform": undisclosed_deductions_by_platform
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

def compute_weekly_forecast(user_id: str) -> dict | None:
    if db is None:
        return None
    try:
        # Fetch all historical jobs for the user
        jobs_ref = db.collection("jobs")
        docs = jobs_ref.where("user_id", "==", user_id).stream()
        
        user_jobs = []
        for doc in docs:
            user_jobs.append(doc.to_dict())
            
        # Filter for valid jobs
        valid_user_jobs = []
        for job in user_jobs:
            fare = job.get("fare")
            duration = job.get("duration_min")
            ts = job.get("created_at") or job.get("job_timestamp")
            platform = job.get("platform")
            if fare is not None and duration is not None and duration > 0 and ts and platform:
                valid_user_jobs.append(job)
                
        # Must have at least 10 jobs to trigger a prediction
        if len(valid_user_jobs) < 10:
            return None
            
        # Group user jobs by (day_of_week, time_of_day, platform)
        day_names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        
        groups = {}
        for job in valid_user_jobs:
            ts = job.get("created_at") or job.get("job_timestamp")
            try:
                if hasattr(ts, "isoformat"):
                    dt = ts
                else:
                    clean_ts = str(ts).replace("Z", "+00:00")
                    dt = datetime.datetime.fromisoformat(clean_ts)
            except Exception:
                continue
                
            # Compute day name and time band
            day_name = day_names[dt.weekday()]
            hour = dt.hour
            if 6 <= hour < 12:
                time_band = "morning"
            elif 12 <= hour < 16:
                time_band = "afternoon"
            elif 16 <= hour < 21:
                time_band = "evening"
            else:
                time_band = "late-night"
                
            platform = str(job.get("platform")).lower().strip()
            
            key = (day_name, time_band, platform)
            if key not in groups:
                groups[key] = []
            groups[key].append(job)
            
        if not groups:
            return None
            
        # Find combination with highest average earnings per hour (EPH)
        best_key = None
        best_avg_eph = -1.0
        
        for key, group in groups.items():
            ephs = []
            for j in group:
                fare = float(j.get("fare") or 0.0)
                dur = float(j.get("duration_min") or 1.0)
                ephs.append((fare / dur) * 60.0)
            avg_eph = sum(ephs) / len(ephs)
            if avg_eph > best_avg_eph:
                best_avg_eph = avg_eph
                best_key = key
                
        if best_key is None:
            return None
            
        best_day, best_time, best_platform = best_key
        
        # Get platform display name
        platform_display = best_platform.capitalize()
        # Look up in Firestore benchmarks or static dict
        static_names = {
            'uber': 'Uber',
            'rapido': 'Rapido',
            'ola': 'Ola',
            'indrive': 'InDrive',
            'zomato': 'Zomato',
            'swiggy': 'Swiggy',
            'dunzo': 'Dunzo',
            'blinkit': 'Blinkit',
            'zepto': 'Zepto',
            'bigbasket': 'BigBasket',
            'amazon_flex': 'Amazon Flex',
            'urban_company': 'Urban Company',
            'porter': 'Porter',
            'housejoy': 'Housejoy',
            'other': 'Other'
        }
        if best_platform in static_names:
            platform_display = static_names[best_platform]
        else:
            try:
                bench_doc = db.collection("benchmarks").document(best_platform).get()
                if bench_doc.exists:
                    platform_display = bench_doc.to_dict().get("displayName", platform_display)
            except Exception:
                pass
                
        # Community Corroboration Check
        # Query community jobs for the same platform
        all_docs = db.collection("jobs").stream()
        community_jobs = []
        for doc in all_docs:
            j = doc.to_dict()
            if str(j.get("platform")).lower().strip() == best_platform:
                fare = j.get("fare")
                duration = j.get("duration_min")
                ts = j.get("created_at") or j.get("job_timestamp")
                if fare is not None and duration is not None and duration > 0 and ts:
                    community_jobs.append(j)
                    
        # Group community platform jobs by (day_of_week, time_of_day)
        community_platform_ephs = []
        community_window_ephs = []
        
        for j in community_jobs:
            ts = j.get("created_at") or j.get("job_timestamp")
            try:
                if hasattr(ts, "isoformat"):
                    dt = ts
                else:
                    clean_ts = str(ts).replace("Z", "+00:00")
                    dt = datetime.datetime.fromisoformat(clean_ts)
            except Exception:
                continue
                
            fare = float(j.get("fare") or 0.0)
            dur = float(j.get("duration_min") or 1.0)
            eph = (fare / dur) * 60.0
            community_platform_ephs.append(eph)
            
            # Check if this job is in the best window (best_day, best_time)
            weekday = dt.weekday()
            day_name = day_names[weekday]
            hour = dt.hour
            if 6 <= hour < 12:
                time_band_check = "morning"
            elif 12 <= hour < 16:
                time_band_check = "afternoon"
            elif 16 <= hour < 21:
                time_band_check = "evening"
            else:
                time_band_check = "late-night"
                
            if day_name == best_day and time_band_check == best_time:
                community_window_ephs.append(eph)
                
        corroborated = False
        if len(community_window_ephs) >= 3 and len(community_platform_ephs) > 0:
            community_platform_avg = sum(community_platform_ephs) / len(community_platform_ephs)
            community_window_avg = sum(community_window_ephs) / len(community_window_ephs)
            if community_window_avg > community_platform_avg:
                corroborated = True
                
        is_data_thin = len(valid_user_jobs) < 20
        
        return {
            "best_day": best_day,
            "best_time_band": best_time,
            "platform": platform_display,
            "user_total_jobs": len(valid_user_jobs),
            "is_data_thin": is_data_thin,
            "corroborated_by_community": corroborated
        }
    except Exception as e:
        print(f"Error computing forecast pattern: {e}")
        return None

@app.get("/weekly-insight")
async def weekly_insight(user_id: str):
    aggregates = get_weekly_aggregates(user_id)
    profile = get_user_profile(user_id) if user_id and user_id != 'anonymous_user' else {}
    lang_code = profile.get('preferredLanguage', 'en') or 'en'
    
    placeholders = {
        'en': "Log a few jobs and I'll have your first weekly insight ready.",
        'hi': "कुछ काम दर्ज करें और मैं आपकी पहली साप्ताहिक जानकारी तैयार करूंगा।",
        'kn': "ಕೆಲವು ಕೆಲಸಗಳನ್ನು ಲಾಗ್ ಮಾಡಿ ಮತ್ತು ನಿಮ್ಮ ಮೊದಲ ಸಾಪ್ತಾಹಿಕ ಒಳനೋಟವನ್ನು ನಾನು ಸಿದ್ಧಪಡಿಸುತ್ತೇನೆ.",
        'ta': "ஒரு சில வேலைகளைப் பதிவுചെയ്യவும், உங்களுடைய முதல் வாரാந்திர நுண்ணறிவை ഞാൻ தயார் செய்வேன்.",
        'te': "కొన్ని పనులను నమోదు చేయండి మరియు నేను మీ మొదటి వారపు అంతర్దృష్టిని సిద్ధంగా ఉంచుతాను.",
        'ml': "കുറച്ച് ജോലികൾ ലോഗ് ചെയ്യുക, നിങ്ങളുടെ ആദ്യത്തെ പ്രതിവാര ഉൾക്കാഴ്ച ഞാൻ തയ്യാറാക്കും."
    }

    errors = {
        'en': "I'm having trouble generating your weekly summary right now. Your logged stats below are safe and up to date.",
        'hi': "मैं अभी आपकी साप्ताहिक जानकारी जनरेट नहीं कर पा रहा हूँ। आपके आंकड़े सुरक्षित हैं।",
        'kn': "ನಿಮ್ಮ ಸಾಪ್ತಾಹಿಕ ಸಾರಾಂಶವನ್ನು ರಚಿಸಲು ತೊಂದರೆಯಾಗುತ್ತಿದೆ. ನಿಮ್ಮ ಅಂಕಿಅಂಶಗಳು ಸುರಕ್ಷಿತವಾಗಿವೆ.",
        'ta': "உங்கள் வாரാந்திர சுരുക്കത്തെ உருவாக்குவதில் சிக்கல் உள்ளது. உங்கள் புள்ளிവിവരങ്ങൾ பாதுகாப்பாக உள்ளன.",
        'te': "మీ వారపు సారాంశాన్ని రూపొందించడంలో సమస్య ఉంది. మీ గణాంకాలు సురક્ષితంగా ఉన్నాయి.",
        'ml': "പ്രതിവാര സംഗ്രഹം തയ്യാറാക്കുന്നതിൽ പ്രശ്നമുണ്ട്. നിങ്ങളുടെ വിവരങ്ങൾ സുരക്ഷിതമാണ്."
    }

    if aggregates["total_jobs"] == 0:
        return {
            "insight_text": placeholders.get(lang_code, placeholders['en']),
            "stats_used": None
        }

    # Cache checking logic
    cached_text = profile.get("cachedInsightText")
    cached_gen_at = profile.get("cachedInsightGeneratedAt")
    cached_week_start = profile.get("cachedInsightWeekStart")
    
    now = datetime.datetime.now(datetime.timezone.utc)
    monday = now - datetime.timedelta(days=now.weekday())
    monday_start = datetime.datetime(monday.year, monday.month, monday.day, 0, 0, 0, tzinfo=datetime.timezone.utc)
    
    should_regenerate = True
    if cached_text and cached_gen_at and cached_week_start:
        # Check if week has shifted
        if isinstance(cached_week_start, str):
            try:
                cached_week_dt = datetime.datetime.fromisoformat(cached_week_start.replace("Z", "+00:00"))
            except:
                cached_week_dt = monday_start
        else:
            cached_week_dt = cached_week_start
            
        if cached_week_dt >= monday_start:
            # Same week. Now check for any new job logged since cached_gen_at
            should_regenerate = False
            try:
                if isinstance(cached_gen_at, str):
                    cached_gen_dt = datetime.datetime.fromisoformat(cached_gen_at.replace("Z", "+00:00"))
                else:
                    cached_gen_dt = cached_gen_at
                
                recent_jobs = db.collection("jobs").where("user_id", "==", user_id).order_by("created_at", direction=firestore.Query.DESCENDING).limit(1).get()
                if recent_jobs:
                    latest_job = recent_jobs[0].to_dict()
                    job_ts = latest_job.get("created_at") or latest_job.get("job_timestamp")
                    if job_ts:
                        if isinstance(job_ts, datetime.datetime):
                            job_dt = job_ts
                        elif isinstance(job_ts, str):
                            job_dt = datetime.datetime.fromisoformat(job_ts.replace("Z", "+00:00"))
                        else:
                            job_dt = job_ts
                        
                        if job_dt and job_dt > cached_gen_dt:
                            should_regenerate = True
            except Exception as e:
                print(f"Error checking recent jobs for insight regeneration: {e}")

    if not should_regenerate:
        print(f"Serving cached weekly insight for user {user_id}")
        return {
            "insight_text": cached_text,
            "stats_used": aggregates
        }

    # Otherwise, generate new insight
    worker_type = profile.get('workerType', 'other_gig_worker')
    worker_types = profile.get('workerTypes')
    if not isinstance(worker_types, list):
        worker_types = [worker_type]
    
    working_platforms = profile.get('workingPlatforms')
    if not isinstance(working_platforms, list):
        working_platforms = []
        
    experience_years = profile.get('experienceYears', 0)
    experience_months = profile.get('experienceMonths', 0)
    bio = profile.get('bio', '')
    
    worker_type_descs = [WORKER_TYPE_DESCRIPTIONS.get(wt, 'gig worker') for wt in worker_types]
    worker_type_desc = " and ".join(worker_type_descs)
    
    extra_details = []
    if working_platforms:
        extra_details.append(f"works on: {', '.join(working_platforms)}")
    if experience_years > 0 or experience_months > 0:
        extra_details.append(f"experience: {experience_years} years, {experience_months} months")
    if bio:
        extra_details.append(f"bio/notes: {bio}")
        
    if extra_details:
        worker_type_desc += " (" + "; ".join(extra_details) + ")"
        
    language_name = LANGUAGE_NAMES.get(lang_code, 'English')

    forecast = compute_weekly_forecast(user_id)

    prompt = get_weekly_insight_prompt(
        worker_type_desc=worker_type_desc,
        aggregates_json=json.dumps(aggregates),
        language_name="English",
        forecast_json=json.dumps(forecast) if forecast else None
    )

    insight_text = ask_gemma(prompt)
    
    if insight_text == "OLLAMA_UNREACHABLE_ERROR":
        insight_text = errors.get(lang_code, errors['en'])
    else:
        if language_name.lower() != "english":
            insight_text = translate_to_language(insight_text, language_name)
        
    # Write to Firestore user cache document
    if db is not None and user_id and user_id != 'anonymous_user':
        try:
            db.collection("users").document(user_id).set({
                "cachedInsightText": insight_text,
                "cachedInsightWeekStart": monday_start,
                "cachedInsightGeneratedAt": now
            }, merge=True)
            print(f"Successfully cached weekly insight for user {user_id}")
        except Exception as e:
            print(f"Error caching weekly insight to Firestore for user {user_id}: {e}")

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

@app.post("/admin/recalculate-benchmarks")
async def recalculate_benchmarks(platform: Optional[str] = None):
    if db is None:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"error": "Database is not initialized"}
        )
    
    summary = []
    try:
        # 1. Fetch cutoff date: 60 days ago
        cutoff_date = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=60)
        
        # 2. Fetch platforms/benchmarks (scoped if platform specified)
        benchmarks_ref = db.collection("benchmarks")
        if platform:
            platforms = [platform.lower().strip()]
        else:
            platforms = [doc.id for doc in benchmarks_ref.stream()]
        
        # 3. Fetch jobs (scoped if platform specified) to optimize DB reads
        all_jobs_ref = db.collection("jobs")
        if platform:
            all_jobs_docs = all_jobs_ref.where("platform", "==", platform.lower().strip()).stream()
        else:
            all_jobs_docs = all_jobs_ref.stream()
        
        # Group jobs by platform in-memory
        jobs_by_platform = {p: [] for p in platforms}
        for doc in all_jobs_docs:
            job = doc.to_dict()
            p_val = (job.get("platform") or "").lower().strip()
            if p_val in jobs_by_platform:
                jobs_by_platform[p_val].append(job)
        
        # Helper function for median
        def calculate_median(values):
            if not values:
                return 0.0
            sorted_vals = sorted(values)
            n = len(sorted_vals)
            if n % 2 == 1:
                return sorted_vals[n // 2]
            else:
                return (sorted_vals[n // 2 - 1] + sorted_vals[n // 2]) / 2.0

        for p_id in platforms:
            p_ref = benchmarks_ref.document(p_id)
            p_snap = p_ref.get()
            
            if not p_snap.exists:
                continue
                
            p_data = p_snap.to_dict()
            
            # Fetch existing seedRate or create it using legacy properties
            seed_rate = p_data.get("seedRate")
            if not seed_rate:
                seed_rate = {
                    "rate_per_km": p_data.get("rate_per_km", 10.0),
                    "rate_per_min": p_data.get("rate_per_min", 1.3)
                }
            
            # Filter jobs matching conditions
            platform_jobs = jobs_by_platform.get(p_id, [])
            clean_jobs = []
            
            for j in platform_jobs:
                # 1. Reject if explicitly underpaid
                if j.get("is_underpaid") is True:
                    continue
                    
                # 2. Require positive values
                dist = j.get("distance_km") or 0.0
                dur = j.get("duration_min") or 0.0
                fare = j.get("fare") or 0.0
                if dist <= 0.0 or dur <= 0.0 or fare <= 0.0:
                    continue
                    
                # 3. Within last 60 days
                job_time = j.get("created_at") or j.get("job_timestamp")
                if job_time is None:
                    continue
                
                is_recent = False
                if isinstance(job_time, str):
                    try:
                        if job_time.endswith('Z'):
                            job_time = job_time[:-1] + '+00:00'
                        dt = datetime.datetime.fromisoformat(job_time)
                        if dt >= cutoff_date:
                            is_recent = True
                    except Exception:
                        pass
                elif hasattr(job_time, "timestamp"):
                    if job_time.tzinfo is None:
                        job_time = job_time.replace(tzinfo=datetime.timezone.utc)
                    if job_time >= cutoff_date:
                        is_recent = True
                
                if not is_recent:
                    continue
                    
                # 4. Outlier filtering
                # Expected fare from seed rate
                expected_fare = (dist * seed_rate.get("rate_per_km", 10.0)) + (dur * seed_rate.get("rate_per_min", 1.3))
                if expected_fare <= 0.0:
                    continue
                    
                ratio = fare / expected_fare
                if ratio < 0.5 or ratio > 2.0:
                    continue # Statistical outlier
                
                # Derive implied rates
                implied_rate_per_km = seed_rate.get("rate_per_km", 10.0) * ratio
                implied_rate_per_min = seed_rate.get("rate_per_min", 1.3) * ratio
                
                clean_jobs.append({
                    "implied_rate_per_km": implied_rate_per_km,
                    "implied_rate_per_min": implied_rate_per_min
                })
            
            sample_size = len(clean_jobs)
            
            if sample_size >= 5:
                implied_kms = [j["implied_rate_per_km"] for j in clean_jobs]
                implied_mins = [j["implied_rate_per_min"] for j in clean_jobs]
                
                community_rate_per_km = round(calculate_median(implied_kms), 2)
                community_rate_per_min = round(calculate_median(implied_mins), 2)
                
                community_rate = {
                    "rate_per_km": community_rate_per_km,
                    "rate_per_min": community_rate_per_min
                }
            else:
                # Retain old communityRate if it exists, don't overwrite with None, but prompt says "leave it as-is (or unset) and leave sampleSize reflecting the small count"
                # To leave it as-is, we'll just pull the existing communityRate.
                community_rate = p_data.get("communityRate")
                
            # Perform update
            update_data = {
                "seedRate": seed_rate,
                "sampleSize": sample_size
            }
            if community_rate is not None:
                update_data["communityRate"] = community_rate
            
            # Record for JSON summary response
            old_community = p_data.get("communityRate") or seed_rate
            summary.append({
                "platform": p_id,
                "old_rate": old_community,
                "new_rate": community_rate or seed_rate,
                "sample_size": sample_size
            })
            
        return {"status": "success", "summary": summary}
        
    except Exception as e:
        print(f"Error recalculating benchmarks: {e}")
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"error": f"Failed to recalculate: {str(e)}"}
        )

@app.post("/admin/seed-demo-community-data")
async def seed_demo_community_data():
    if db is None:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"error": "Database is not initialized"}
        )
    
    # DEBUG-ONLY GUARD: Prevent running in production environments
    if os.getenv("ENV") == "production":
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={"error": "Not allowed in production environment"}
        )

    try:
        # 1. Clean up existing synthetic worker data to avoid duplicate pollution
        jobs_ref = db.collection("jobs")
        existing_docs = jobs_ref.where("user_id", ">=", "worker_demo_").where("user_id", "<=", "worker_demo_\uf8ff").stream()
        batch = db.batch()
        deleted_count = 0
        for doc in existing_docs:
            batch.delete(doc.reference)
            deleted_count += 1
            if deleted_count % 400 == 0:
                batch.commit()
                batch = db.batch()
        if deleted_count % 400 != 0:
            batch.commit()

        # 2. Setup platforms & benchmark rates for expected fare computation
        platforms = {
            'uber': {'rate_per_km': 16.00, 'rate_per_min': 1.50},
            'ola': {'rate_per_km': 15.50, 'rate_per_min': 1.40},
            'zomato': {'rate_per_km': 8.50, 'rate_per_min': 0.80},
            'swiggy': {'rate_per_km': 8.50, 'rate_per_min': 0.80},
            'blinkit': {'rate_per_km': 10.00, 'rate_per_min': 0.60},
            'zepto': {'rate_per_km': 9.50, 'rate_per_min': 0.50},
        }

        # 3. Setup localities and their underpaid skews
        localities = {
            'Koramangala, Bengaluru': {'skew': 'fair'},
            'Indiranagar, Bengaluru': {'skew': 'fair'},
            'HSR Layout, Bengaluru': {'skew': 'underpaid'},
            'Whitefield, Bengaluru': {'skew': 'mixed'},
            'Jayanagar, Bengaluru': {'skew': 'mixed'}
        }

        import random
        random.seed(42)  # Deterministic seed for reproducible demo data

        workers = [f"worker_demo_{i}" for i in range(1, 11)]  # 10 synthetic workers
        job_sources = ['manual', 'ocr', 'stt']

        seeded_jobs = []
        now = datetime.datetime.now(datetime.timezone.utc)

        # Generate 150 jobs
        total_to_generate = 150
        for i in range(total_to_generate):
            worker = random.choice(workers)
            platform = random.choice(list(platforms.keys()))
            rates = platforms[platform]
            
            # Select locality
            locality_name = random.choice(list(localities.keys()))
            locality_cfg = localities[locality_name]

            # Generate distance & duration
            dist = round(random.uniform(2.0, 15.0), 2)
            dur = round(dist * random.uniform(1.8, 2.5), 1)

            # Compute expected fare
            expected = round((rates['rate_per_km'] * dist) + (rates['rate_per_min'] * dur), 2)

            # Determine fairness based on locality skew
            skew = locality_cfg['skew']
            roll = random.random()
            if skew == 'fair':
                is_underpaid_target = roll < 0.10  # 10% underpaid
            elif skew == 'underpaid':
                is_underpaid_target = roll < 0.80  # 80% underpaid
            else:
                is_underpaid_target = roll < 0.30  # 30% underpaid

            if is_underpaid_target:
                fare = round(expected * random.uniform(0.65, 0.82), 2)
            else:
                fare = round(expected * random.uniform(0.88, 1.20), 2)

            is_underpaid = fare < (expected * 0.85)

            # Spread timestamps across last 40 days
            days_ago = random.uniform(0, 40)
            job_time = now - datetime.timedelta(days=days_ago)

            explanation = (
                "This came in noticeably below what's typical for this distance and platform."
                if is_underpaid else
                f"This is about what's typical for a {dist:.1f}km {platform.capitalize()} trip."
            )

            job_doc = {
                'user_id': worker,
                'platform': platform,
                'fare': fare,
                'distance_km': dist,
                'duration_min': dur,
                'expected_fare': expected,
                'is_underpaid': is_underpaid,
                'explanation': explanation,
                'source': random.choice(job_sources),
                'rate_source': 'community' if random.random() > 0.5 else 'seed',
                'sample_size': random.randint(10, 80),
                'area_hint': locality_name,
                'job_timestamp': job_time,
                'created_at': job_time,
                'base_fare': round(fare * 0.7, 2),
                'incentive_amount': 0.0 if random.random() > 0.2 else round(fare * 0.15, 2),
                'surge_amount': 0.0 if random.random() > 0.1 else round(fare * 0.1, 2),
                'deduction_amount': 0.0,
                'deduction_reason_stated': '',
                'is_demo_data': True
            }

            seeded_jobs.append(job_doc)

        # Write jobs in batches to Firestore
        batch = db.batch()
        written = 0
        for job in seeded_jobs:
            doc_ref = jobs_ref.document()
            batch.set(doc_ref, job)
            written += 1
            if written % 400 == 0:
                batch.commit()
                batch = db.batch()
        if written % 400 != 0:
            batch.commit()

        # Run recalculation once to sync platform medians
        await recalculate_benchmarks()

        return {
            "status": "success",
            "message": "Demo community data seeded successfully",
            "records_deleted": deleted_count,
            "records_created": len(seeded_jobs)
        }

    except Exception as e:
        print(f"Error seeding demo community data: {e}")
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"error": f"Failed to seed data: {str(e)}"}
        )

@app.post("/complaint-draft")
async def complaint_draft_endpoint(request: DraftRequest):
    if db is None:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"error": "Database is not initialized"}
        )
    
    try:
        # Fetch target job details from Firestore
        job_doc = db.collection("jobs").document(request.job_id).get()
        if not job_doc.exists:
            return JSONResponse(
                status_code=status.HTTP_44_NOT_FOUND,
                content={"error": f"Job {request.job_id} not found"}
            )
            
        job = job_doc.to_dict()
        
        # User profile to determine preferred language
        profile = get_user_profile(request.user_id)
        lang_code = profile.get('preferredLanguage', 'en') or 'en'
        language_name = LANGUAGE_NAMES.get(lang_code, 'English')
        
        platform = job.get("platform") or "Platform"
        fare = (job.get("fare") or 0.0)
        expected_fare = (job.get("expected_fare") or 0.0)
        distance_km = (job.get("distance_km") or 0.0)
        duration_min = (job.get("duration_min") or 0.0)
        
        # Format the trip timestamp
        formatted_date = "recently"
        raw_time = job.get("job_timestamp") or job.get("created_at")
        if raw_time:
            if isinstance(raw_time, str):
                try:
                    if raw_time.endswith('Z'):
                        raw_time = raw_time[:-1] + '+00:00'
                    dt = datetime.datetime.fromisoformat(raw_time)
                    formatted_date = dt.strftime("%B %d, %Y")
                except Exception:
                    pass
            elif hasattr(raw_time, "strftime"):
                formatted_date = raw_time.strftime("%B %d, %Y")
                
        # Ask Gemma for the draft
        prompt = get_complaint_draft_prompt(
            platform=platform.capitalize(),
            fare=fare,
            expected_fare=expected_fare,
            distance_km=distance_km,
            duration_min=duration_min,
            formatted_date=formatted_date,
            language_name=language_name
        )
        
        draft_text = ask_gemma(prompt)
        
        if draft_text == "OLLAMA_UNREACHABLE_ERROR":
            # Return specific formatted fallback template
            fallbacks = {
                'en': "Hello support. I am writing regarding my ride on {platform} on {date}. I was paid ₹{fare:.2f} for a trip of {distance_km:.1f} km and {duration_min:.0f} mins. Based on benchmark rates, the expected fare is ₹{expected_fare:.2f}. Please review this calculation and adjust my payout. Thank you.",
                'hi': "नमस्ते सहायता टीम। मैं {platform} पर {date} को अपनी सवारी के संबंध में लिख रहा हूँ। मुझे {distance_km:.1f} किमी और {duration_min:.0f} मिनट की यात्रा के लिए ₹{fare:.2f} का भुगतान किया गया था। बेंचमार्क दरों के आधार पर, अपेक्षित किराया ₹{expected_fare:.2f} होना चाहिए। कृपया इस भुगतान की समीक्षा करें। धन्यवाद।",
                'kn': "{platform} ನಲ್ಲಿ {date} ರಂದು ನನ್ನ ಪಯಣದ ಕುರಿತು ನಾನು ಬರೆಯುತ್ತಿದ್ದೇನೆ. {distance_km:.1f} ಕಿಮೀ ಮತ್ತು {duration_min:.0f} ನಿಮಿಷಗಳ ಪ್ರಯಾಣಕ್ಕೆ ನನಗೆ ₹{fare:.2f} ಪಾವತಿಸಲಾಗಿದೆ. ದರಗಳ ಪ್ರಕಾರ, ನಿರೀಕ್ಷಿತ ದರ ₹{expected_fare:.2f} ಇರಬೇಕು. ದಯವಿಟ್ಟು ಇದನ್ನು ಪರಿಶೀಲಿಸಿ ನನ್ನ ಪಾವತಿಯನ್ನು ಸರಿಪಡಿಸಿ. ಧನ್ಯವಾದಗಳು.",
                'ta': "{platform} இல் {date} அன்று எனது பயணம் குறித்து நான் எழுதுகிறேன். {distance_km:.1f} கிமீ மற்றும் {duration_min:.0f} நிமிட பயணத்திற்கு எனக்கு ₹{fare:.2f} வழங்கப்பட்டது. தரநிலைகளின்படி, எதிர்பார்க்கப்படும் கட்டணம் ₹{expected_fare:.2f} ஆகும். தயவுசெய்து ಇದನ್ನು மறுபரிசீலனை செய்து சரிசெய்யவும். நன்றி.",
                'te': "{platform} లో {date} న నా ప్రయాణానికి సంబంధించి నేను వ్రాస్తున్నాను. {distance_km:.1f} కిమీ మరియు {duration_min:.0f} నిమిషాల ప్రయాణానికి నాకు ₹{fare:.2f} చెల్లించబడింది. ప్రామాణిక రేట్ల ప్రకారం, ఆశించిన ఛార్జీ ₹{expected_fare:.2f} ఉండాలి. దయస చేసి దీనిని సమీక్షించండి. ಧನ್ಯವಾದಗಳು.",
                'ml': "{platform} ൽ {date} ലെ എന്റെ യാത്രയെക്കുറിച്ച് ഞാൻ എഴുതുന്നു. {distance_km:.1f} കിമീ, {duration_min:.0f} മിനിറ്റ് യാത്രയ്ക്ക് എനിക്ക് ₹{fare:.2f} ആണ് ലഭിച്ചത്. ബെഞ്ച്മാർക്ക് നിരക്കുകൾ അനുസരിച്ച് ₹{expected_fare:.2f} ലഭിക്കേണ്ടതായിരുന്നു. ദയവായി ഇത് പരിശോധിച്ച് തുക തിരുത്തുക. നന്ദി."
            }
            tmpl = fallbacks.get(lang_code, fallbacks['en'])
            draft_text = tmpl.format(
                platform=platform.capitalize(),
                date=formatted_date,
                fare=fare,
                distance_km=distance_km,
                duration_min=duration_min,
                expected_fare=expected_fare
            )
            
        return {"draft_text": draft_text.strip()}
        
    except Exception as e:
        print(f"Error drafting complaint: {e}")
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"error": f"Failed to draft complaint: {str(e)}"}
        )


@app.post("/fatigue-nudge")
async def fatigue_nudge_endpoint(request: FatigueRequest):
    profile = get_user_profile(request.user_id)
    lang_code = profile.get('preferredLanguage', 'en')
    language_name = LANGUAGE_NAMES.get(lang_code, 'English')
    
    if lang_code == 'en':
        prompt = (
            f"This gig worker has logged over {request.total_hours:.1f} hours of work in the last 24 hours. "
            f"Write one short, warm sentence in fluent, natural English gently checking in and suggesting they consider a break. "
            f"Respond ONLY in English."
        )
    else:
        prompt = (
            f"This gig worker has logged over {request.total_hours:.1f} hours of work in the last 24 hours. "
            f"Write one short, warm sentence in fluent, natural {language_name} using its native script gently checking in and suggesting they consider a break. "
            f"Do not mix in English words or script (except for numbers). Respond ONLY in {language_name} script."
        )
    
    msg = ask_gemma(prompt)
    if msg == "OLLAMA_UNREACHABLE_ERROR":
        fallbacks = {
            'en': "You've been working hard — over 10 hours today! Remember to take a quick break to stretch and rest.",
            'hi': "आपने आज 10 घंटे से अधिक काम किया है! आराम करने और तरोताजा होने के लिए छोटा सा ब्रेक लें।",
            'kn': "ನೀವು ಇಂದು 10 ಗಂಟೆಗಳಿಗಿಂತ ಹೆಚ್ಚು ಕೆಲಸ ಮಾಡಿದ್ದೀರಿ! ಸ್ವಲ್ಪ ವಿಶ್ರಾಂತಿ ತೆಗೆದುಕೊಳ್ಳಿ.",
            'ta': "நீங்கள் இன்று 10 மணி நேரத்திற்கும் மேலாக உழைத்துள்ளீர்கள்! சிறிது ஓய்வு எடுக்கவும்.",
            'te': "మీరు ఈ రోజు 10 గంటలకంటే ఎక్కువ పనిచేశారు! కాస్త విశ్రాంతి తీసుకోండి.",
            'ml': "നിങ്ങൾ ഇന്ന് 10 മണിക്കൂറിലധികം ജോലി ചെയ്തു! കുറച്ചുനേരം വിശ്രമിക്കുക."
        }
        msg = fallbacks.get(lang_code, fallbacks['en'])
        
    return {"message": msg.strip(' "')}


@app.post("/sos-message")
async def sos_message_endpoint(request: SOSRequest):
    profile = get_user_profile(request.user_id)
    lang_code = profile.get('preferredLanguage', 'en')
    language_name = LANGUAGE_NAMES.get(lang_code, 'English')
    
    prompt = (
        f"Draft a short, clear, calm safety alert message a gig worker can send to emergency contacts if they feel unsafe during a job. "
        f"Include placeholders for [current approximate location] and [platform/trip details]. Keep it under 3 sentences, direct and actionable, not panicked in tone. "
        f"Write it strictly in fluent, natural {language_name} using its native script. Do not mix in English words or script."
    )
    
    msg = ask_gemma(prompt)
    if msg == "OLLAMA_UNREACHABLE_ERROR":
        fallbacks = {
            'en': "I am feeling unsafe during my current gig work trip. My approximate location is [location] and I am on a [platform] trip. Please check in on me or be ready to help.",
            'hi': "मुझे अपनी वर्तमान ट्रिप के दौरान असुरक्षित महसूस हो रहा है। मेरा स्थान [location] है। कृपया मुझ पर नज़र रखें।",
            'kn': "ನಾನು ಪ್ರಸ್ತುತ ಟ್ರಿಪ್‌ನಲ್ಲಿ ಅಸುರಕ್ಷಿತ ಎಂದು ಭಾವಿಸುತ್ತಿದ್ದೇನೆ. ನನ್ನ ಸ್ಥಳ [location]. ದಯವಿಟ್ಟು ಗಮನಿಸಿ.",
            'ta': "தற்போதைய பயணத்தில் எனக்கு பாதுகாப்பற்றதாக உணர்கிறேன். எனது இடம் [location]. தயவுசெய்து கவனிக்கவும்.",
            'te': "ప్రస్తుత ట్రిప్‌లో నేను అసురక్షితంగా ఉన్నాను. నా ప్రదేశం [location]. దయచేసి గమనించండి.",
            'ml': "എൻ്റെ നിലവിലെ ട്രിപ്പിൽ എനിക്ക് സുരക്ഷിതത്വമില്ല എന്ന് തോന്നുന്നു. എൻ്റെ സ്ഥലം [location]. ദയവായി ശ്രദ്ധിക്കുക."
        }
        msg = fallbacks.get(lang_code, fallbacks['en'])
        
    return {"draft_message": msg.strip(' "')}

@app.post("/route-safety", response_model=RouteSafetyResponse)
async def route_safety_endpoint(request: RouteSafetyRequest):
    try:
        from safety import compute_route_safety_score
        
        # Use default English if language_name is missing, though we updated schema to default to English
        score, message = compute_route_safety_score(
            job_timestamp=request.job_timestamp,
            area_hint=request.area_hint,
            language_name=request.language_name
        )
        
        return {
            "score": score,
            "message": message
        }
    except Exception as e:
        print(f"Error computing route safety: {e}")
        return {
            "score": "low",
            "message": "Error calculating safety score."
        }

import re

def regex_parse_transcript(transcript: str):
    transcript_lower = transcript.lower()
    
    # 1. Platform (fuzzy matching)
    import difflib
    platform = None
    platforms = ["zomato", "swiggy", "uber", "ola", "rapido", "zepto", "blinkit", "porter", "indrive"]
    
    # Try exact match / contains first
    for p in platforms:
        if p in transcript_lower:
            platform = p.capitalize()
            break
            
    if not platform:
        words = transcript_lower.split()
        for word in words:
            clean_word = "".join(c for c in word if c.isalpha())
            matches = difflib.get_close_matches(clean_word, platforms, n=1, cutoff=0.6)
            if matches:
                platform = matches[0].capitalize()
                break
            
    # 2. Fare (Rupees)
    fare = None
    fare_match = re.search(r'(?:rs\.?|rupees|inr|₹|rs|रुपये|रुपया|रू|रु|ರೂಪಾಯಿ|ರೂಪಾಯಿಗಳು|ರೂ|రూపాయలు|రూపాయి|రూபாய்|രൂപ)\s*(\d+(?:\.\d+)?)', transcript_lower)
    if not fare_match:
        fare_match = re.search(r'(\d+(?:\.\d+)?)\s*(?:rupees|rs|rs\.?|रुपये|रुपया|रू|रु|ರೂಪಾಯಿ|ರೂಪಾಯಿಗಳು|ರೂ|రూపాయలు|రూపాయి|రూபாய்|രൂപ)', transcript_lower)
    if fare_match:
        try:
            fare = float(fare_match.group(1))
        except ValueError:
            pass
        
    # 3. Distance (km)
    distance_km = None
    dist_match = re.search(r'(\d+(?:\.\d+)?)\s*(?:km|kms|kilometers|kilometer|kilo\s*meter|किमी|किलोमीटर|ಕಿಮೀ|ಕಿಲೋಮೀಟರ್|ಕಿಲೋಮೀಟರ್‌ಗಳು|కిమీ|కిలోమీటర్లు|కిలోమీటర్|கிமீ|கிலோமீட்டர்|കിലോമീറ്റർ|കിമീ)', transcript_lower)
    if dist_match:
        try:
            distance_km = float(dist_match.group(1))
        except ValueError:
            pass
        
    # 4. Duration (min)
    duration_min = None
    dur_match = re.search(r'(\d+(?:\.\d+)?)\s*(?:mins|min|minutes|minute|मिनट|ನಿಮಿಷ|ನಿಮಿಷಗಳು|నిమిషాలు|నిమిషం|நிமிடங்கள்|நிமிடம்|മിനിറ്റ്)', transcript_lower)
    if dur_match:
        try:
            duration_min = float(dur_match.group(1))
        except ValueError:
            pass
        
    return {
        "platform": platform,
        "fare": fare,
        "distance_km": distance_km,
        "duration_min": duration_min
    }

@app.post("/jobs/voice-parse")
async def voice_parse_job(req: VoiceParseRequest):
    print(f"[VOICE LOG] Parsing transcript: '{req.transcript}' in language '{req.language_name}', target field: {req.target_field}")
    
    # 1. Run regex parser as baseline/fallback
    regex_data = regex_parse_transcript(req.transcript)
    
    # 2. Get prompt and run LLM
    from llm import get_voice_parse_prompt
    prompt = get_voice_parse_prompt(req.transcript, req.language_name)
    response_text = ask_gemma(prompt)
    
    parsed_json = {}
    if response_text != "OLLAMA_UNREACHABLE_ERROR":
        # Extract JSON block
        try:
            # Strip any markdown backticks if returned
            clean_text = response_text.strip()
            if clean_text.startswith("```"):
                clean_text = clean_text.split("```")[1]
                if clean_text.startswith("json"):
                    clean_text = clean_text[4:]
            clean_text = clean_text.strip()
            
            # Parse json
            parsed_json = json.loads(clean_text)
            print(f"[VOICE LOG] LLM parsed JSON: {parsed_json}")
        except Exception as e:
            print(f"[VOICE LOG] LLM response JSON parsing error: {e}. Raw response: {response_text}")
            
    # 3. Merge LLM parsed data with regex data fallbacks
    platform = parsed_json.get("platform") or regex_data.get("platform")
    fare = parsed_json.get("fare") or regex_data.get("fare")
    distance_km = parsed_json.get("distance_km") or regex_data.get("distance_km")
    duration_min = parsed_json.get("duration_min") or regex_data.get("duration_min")
    
    # 4. Clarification-specific fallback: extract any number for numeric fields if they couldn't be parsed
    if req.target_field:
        if req.target_field == "fare" and not fare:
            num_match = re.search(r'(\d+(?:\.\d+)?)', req.transcript)
            if num_match:
                fare = float(num_match.group(1))
        elif req.target_field == "distance_km" and not distance_km:
            num_match = re.search(r'(\d+(?:\.\d+)?)', req.transcript)
            if num_match:
                distance_km = float(num_match.group(1))
        elif req.target_field == "duration_min" and not duration_min:
            num_match = re.search(r'(\d+(?:\.\d+)?)', req.transcript)
            if num_match:
                duration_min = float(num_match.group(1))
        elif req.target_field == "platform" and not platform:
            import difflib
            platforms = ["zomato", "swiggy", "uber", "ola", "rapido", "zepto", "blinkit", "porter", "indrive"]
            candidate = req.transcript.lower().strip()
            matches = difflib.get_close_matches(candidate, platforms, n=1, cutoff=0.5)
            if matches:
                platform = matches[0].capitalize()
            else:
                for word in candidate.split():
                    clean_word = "".join(c for c in word if c.isalpha())
                    word_matches = difflib.get_close_matches(clean_word, platforms, n=1, cutoff=0.6)
                    if word_matches:
                        platform = word_matches[0].capitalize()
                        break

    # Standardize platform casing
    if platform and isinstance(platform, str):
        platform = platform.strip().capitalize()
        
    result = {
        "platform": platform,
        "fare": fare,
        "distance_km": distance_km,
        "duration_min": duration_min
    }
    
    # If a specific target field is requested, restrict returning other fields to avoid pollution
    if req.target_field:
        restricted_result = {
            "platform": platform if req.target_field == "platform" else None,
            "fare": fare if req.target_field == "fare" else None,
            "distance_km": distance_km if req.target_field == "distance_km" else None,
            "duration_min": duration_min if req.target_field == "duration_min" else None
        }
        print(f"[VOICE LOG] Restricted merged output for {req.target_field}: {restricted_result}")
        return restricted_result

    print(f"[VOICE LOG] Final merged output: {result}")
    return result

