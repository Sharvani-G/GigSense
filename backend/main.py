from fastapi import FastAPI, UploadFile, File, status
from fastapi.responses import JSONResponse, StreamingResponse
from dotenv import load_dotenv

# Load environment variables first
load_dotenv()

import os

# Load environment variables FIRST before importing other modules
load_dotenv()

import json
import datetime
from ocr import extract_job_data
from llm import ask_gemma, ask_gemma_stream, get_chat_system_prompt, get_weekly_insight_prompt, get_complaint_draft_prompt
from schemas import JobScanResponse, ChatRequest, ChatResponse, ComplaintRequest, DraftRequest, FatigueRequest, SOSRequest, RouteSafetyRequest, RouteSafetyResponse
from firebase_client import db
from firebase_admin import firestore

app = FastAPI(title="GigShield API")

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
    'ml': 'Malayalam',
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
    recent_jobs = get_recent_jobs(request.user_id)[:5]
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
    language_name = LANGUAGE_NAMES.get(lang_code, 'English')

    system_prompt = get_chat_system_prompt(
        worker_type_desc=worker_type_desc,
        recent_jobs_json=recent_jobs_json,
        conversation_history_str=conversation_history_str,
        language_name=language_name
    )

    def event_generator():
        full_response = ""
        for chunk in ask_gemma_stream(request.message, system_prompt):
            if chunk == "OLLAMA_UNREACHABLE_ERROR":
                yield json.dumps({"error": "Assistant is temporarily unavailable — please try again in a moment."}) + "\n"
                return
            full_response += chunk
            yield json.dumps({"chunk": chunk}) + "\n"
            
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
    language_name = LANGUAGE_NAMES.get(lang_code, 'English')

    prompt = get_weekly_insight_prompt(
        worker_type_desc=worker_type_desc,
        aggregates_json=json.dumps(aggregates),
        language_name=language_name
    )

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

@app.post("/admin/recalculate-benchmarks")
async def recalculate_benchmarks():
    if db is None:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"error": "Database is not initialized"}
        )
    
    summary = []
    try:
        # 1. Fetch cutoff date: 60 days ago
        cutoff_date = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=60)
        
        # 2. Fetch all platforms/benchmarks
        benchmarks_ref = db.collection("benchmarks")
        platforms = [doc.id for doc in benchmarks_ref.stream()]
        
        # 3. Fetch all jobs in one go to optimize DB reads
        all_jobs_ref = db.collection("jobs")
        all_jobs_docs = all_jobs_ref.stream()
        
        # Group jobs by platform in-memory
        jobs_by_platform = {p: [] for p in platforms}
        for doc in all_jobs_docs:
            job = doc.to_dict()
            platform = job.get("platform")
            if platform in jobs_by_platform:
                jobs_by_platform[platform].append(job)
        
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
                'te': "{platform} లో {date} న నా ప్రయాణానికి సంబంధించి నేను వ్రాస్తున్నాను. {distance_km:.1f} కిమీ మరియు {duration_min:.0f} నిమిషాల ప్రయాణానికి నాకు ₹{fare:.2f} చెల్లించబడింది. ప్రామాణిక రేట్ల ప్రకారం, ఆశించిన ఛార్జీ ₹{expected_fare:.2f} ఉండాలి. దయస చేసి దీనిని సమీక్షించండి. ಧನ್ಯವಾದಗಳು."
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
    
    prompt = f"This gig worker has logged over {request.total_hours:.1f} hours of work in the last 24 hours. Write one short, warm sentence in {language_name} gently checking in and suggesting they consider a break — do not be alarming or clinical, be supportive, like a friend noticing they've been at it a while."
    
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
    
    prompt = f"Draft a short, clear, calm safety alert message a gig worker can send to emergency contacts if they feel unsafe during a job. Include placeholders for [current approximate location] and [platform/trip details]. Keep it under 3 sentences, direct and actionable, not panicked in tone. Write it in {language_name}."
    
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
