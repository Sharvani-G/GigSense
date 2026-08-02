import os
import sys
import datetime
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

# Reconfigure stdout to use UTF-8 to handle rupee symbol and other native scripts
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

# Load env
load_dotenv()

# Initialize Firebase Admin
cred_path = os.environ.get("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")
if not firebase_admin._apps:
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
db = firestore.client()

# Import the logic under test from main
from main import compute_weekly_forecast, get_weekly_insight_prompt, ask_gemma

def clear_test_jobs(user_ids):
    print("Clearing previous test jobs...")
    jobs_ref = db.collection("jobs")
    for uid in user_ids:
        docs = jobs_ref.where("user_id", "==", uid).stream()
        for doc in docs:
            doc.reference.delete()
    print("Cleanup done.")

def seed_job(user_id, platform, fare, duration, dt, area_hint="Indiranagar Bangalore"):
    db.collection("jobs").add({
        "user_id": user_id,
        "platform": platform,
        "fare": float(fare),
        "distance_km": 10.0,
        "duration_min": float(duration),
        "is_underpaid": False,
        "area_hint": area_hint,
        "created_at": dt,
        "source": "manual"
    })

def main():
    uids = ["test_user_under_threshold", "test_user_thin_data", "test_user_robust_data", "test_community_user"]
    clear_test_jobs(uids)

    base_time = datetime.datetime.now(datetime.timezone.utc)
    
    # 1. Seed User Under Threshold: 5 jobs total
    print("Seeding test_user_under_threshold (5 jobs)...")
    for i in range(5):
        # Monday morning Uber
        dt = base_time - datetime.timedelta(days=i, hours=24)
        # Set time to morning (e.g. 8 AM)
        dt_morning = dt.replace(hour=8, minute=0, second=0, microsecond=0)
        seed_job("test_user_under_threshold", "uber", 100, 60, dt_morning)

    # 2. Seed User Thin Data: 12 jobs total
    # 5 jobs are on Friday Evening Zomato (high pay: 300/hr)
    # 7 jobs are on Monday Morning Swiggy (lower pay: 100/hr)
    print("Seeding test_user_thin_data (12 jobs)...")
    friday_count = 0
    monday_count = 0
    for i in range(120):
        dt = base_time - datetime.timedelta(days=i)
        if dt.weekday() == 4 and friday_count < 5:  # Friday
            dt_evening = dt.replace(hour=18, minute=0, second=0, microsecond=0)
            seed_job("test_user_thin_data", "zomato", 150, 30, dt_evening)  # EPH = 300
            friday_count += 1
        elif dt.weekday() == 0 and monday_count < 7:  # Monday
            dt_morning = dt.replace(hour=9, minute=0, second=0, microsecond=0)
            seed_job("test_user_thin_data", "swiggy", 100, 60, dt_morning)   # EPH = 100
            monday_count += 1

    # 3. Seed User Robust Data: 25 jobs total
    # 10 jobs on Friday Evening Zomato (high pay: 300/hr)
    # 15 jobs on Monday Morning Swiggy (lower pay: 100/hr)
    print("Seeding test_user_robust_data (25 jobs)...")
    friday_count = 0
    monday_count = 0
    for i in range(200):
        dt = base_time - datetime.timedelta(days=i)
        if dt.weekday() == 4 and friday_count < 10:  # Friday
            dt_evening = dt.replace(hour=19, minute=0, second=0, microsecond=0)
            seed_job("test_user_robust_data", "zomato", 150, 30, dt_evening)  # EPH = 300
            friday_count += 1
        elif dt.weekday() == 0 and monday_count < 15:  # Monday
            dt_morning = dt.replace(hour=10, minute=0, second=0, microsecond=0)
            seed_job("test_user_robust_data", "swiggy", 100, 60, dt_morning)   # EPH = 100
            monday_count += 1

    # 4. Seed Community Data to corroborate Zomato Friday Evening
    # We need 3 community jobs for Zomato Friday Evening
    print("Seeding community jobs...")
    for i in range(3):
        # Friday evening
        dt = base_time - datetime.timedelta(days=7 * (i + 1))
        # Ensure it falls on a Friday
        while dt.weekday() != 4:
            dt -= datetime.timedelta(days=1)
        dt_evening = dt.replace(hour=18, minute=30, second=0, microsecond=0)
        seed_job("test_community_user", "zomato", 200, 30, dt_evening)  # EPH = 400

    # Also seed some baseline community jobs for Zomato with lower pay to ensure window average > overall average
    for i in range(5):
        dt = base_time - datetime.timedelta(days=i + 1)
        # Tuesday Morning (not Friday evening)
        while dt.weekday() == 4:
            dt -= datetime.timedelta(days=1)
        dt_morning = dt.replace(hour=10, minute=0, second=0, microsecond=0)
        seed_job("test_community_user", "zomato", 80, 60, dt_morning)  # EPH = 80

    print("\n--- Running Forecast Tests ---\n")

    # Test 1: User Under Threshold
    print("Testing user_under_threshold...")
    forecast_1 = compute_weekly_forecast("test_user_under_threshold")
    print(f"Result (Expected None): {forecast_1}")
    assert forecast_1 is None, "Failed: Should be None for < 10 jobs"
    print("Test 1 Passed!\n")

    # Test 2: User Thin Data (12 jobs)
    print("Testing user_thin_data...")
    # Debug print: query directly to see jobs in DB
    debug_docs = db.collection("jobs").where("user_id", "==", "test_user_thin_data").stream()
    debug_jobs = [doc.to_dict() for doc in debug_docs]
    print(f"DEBUG: Found {len(debug_jobs)} raw jobs for test_user_thin_data in DB")
    for j in debug_jobs:
        print(f"  job: platform={j.get('platform')}, fare={j.get('fare')}, duration={j.get('duration_min')}, created_at={j.get('created_at')} (type={type(j.get('created_at'))})")
    
    forecast_2 = compute_weekly_forecast("test_user_thin_data")
    print(f"Result (Expected: Zomato, Friday, evening, is_data_thin=True): {forecast_2}")
    assert forecast_2 is not None, "Failed: Should have forecast"
    assert forecast_2["platform"] == "Zomato", f"Failed platform: {forecast_2['platform']}"
    assert forecast_2["best_day"] == "Friday", f"Failed day: {forecast_2['best_day']}"
    assert forecast_2["best_time_band"] == "evening", f"Failed time: {forecast_2['best_time_band']}"
    assert forecast_2["is_data_thin"] is True, f"Failed data thinness: {forecast_2['is_data_thin']}"
    # check corroboration (community has 3 jobs with EPH 400, baseline has 5 with EPH 80. overall = (3*400 + 5*80)/8 = 200. window = 400. 400 > 200, so corroborated = True)
    assert forecast_2["corroborated_by_community"] is True, f"Failed corroboration: {forecast_2['corroborated_by_community']}"
    print("Test 2 Passed!\n")

    # Test 3: User Robust Data (25 jobs)
    print("Testing user_robust_data...")
    forecast_3 = compute_weekly_forecast("test_user_robust_data")
    print(f"Result (Expected: Zomato, Friday, evening, is_data_thin=False): {forecast_3}")
    assert forecast_3 is not None, "Failed: Should have forecast"
    assert forecast_3["is_data_thin"] is False, f"Failed data thinness: {forecast_3['is_data_thin']}"
    assert forecast_3["corroborated_by_community"] is True, f"Failed corroboration: {forecast_3['corroborated_by_community']}"
    print("Test 3 Passed!\n")

    # Test 4: Verify prompt generation and Gemma output
    print("Testing Gemma Prompt Generation...")
    import json
    dummy_aggregates = {
        "total_earnings": 1500.0,
        "total_hours": 10.0,
        "flagged_count": 0,
        "total_jobs": 12,
        "platforms": {"zomato": 1500.0},
        "undisclosed_deductions_count": 0,
        "undisclosed_deductions_by_platform": {}
    }

    # Case A: Thin data (forecast_2)
    prompt_thin = get_weekly_insight_prompt(
        worker_type_desc="food delivery partner",
        aggregates_json=json.dumps(dummy_aggregates),
        language_name="English",
        forecast_json=json.dumps(forecast_2)
    )
    print("\n--- Prompt (Thin Data) ---")
    print(prompt_thin)
    print("--------------------------")
    
    # Let's run ask_gemma to see response
    response_thin = ask_gemma(prompt_thin)
    print("\n--- Gemma Response (Thin Data) ---")
    print(response_thin)
    print("----------------------------------")

    # Case B: Robust data (forecast_3)
    prompt_robust = get_weekly_insight_prompt(
        worker_type_desc="food delivery partner",
        aggregates_json=json.dumps(dummy_aggregates),
        language_name="English",
        forecast_json=json.dumps(forecast_3)
    )
    
    response_robust = ask_gemma(prompt_robust)
    print("\n--- Gemma Response (Robust Data) ---")
    print(response_robust)
    print("------------------------------------")

    # Clean up test data
    clear_test_jobs(uids)

if __name__ == "__main__":
    main()
