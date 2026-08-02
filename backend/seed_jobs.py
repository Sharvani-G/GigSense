import os
import random
from datetime import datetime, timedelta
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

# Load env file from backend/.env
backend_dir = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(backend_dir, ".env"))

cred_path = os.environ.get("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")
if not os.path.isabs(cred_path):
    cred_path = os.path.join(backend_dir, cred_path)

if not os.path.exists(cred_path):
    raise FileNotFoundError(f"Credentials not found at {cred_path}")

print(f"Initializing Firebase Admin SDK using credentials from: {cred_path}")
cred = credentials.Certificate(cred_path)
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

localities = ['Koramangala', 'Indiranagar', 'HSR Layout', 'Electronic City', 'Jayanagar']
platforms = ['zomato', 'swiggy', 'uber', 'ola']
time_of_days = ['morning', 'evening', 'latenight']
workers = [f"synth_worker_{i}" for i in range(1, 11)]

platform_rates = {
    'uber': {'rate_per_km': 16.00, 'rate_per_min': 1.50},
    'ola': {'rate_per_km': 15.50, 'rate_per_min': 1.40},
    'zomato': {'rate_per_km': 8.50, 'rate_per_min': 0.80},
    'swiggy': {'rate_per_km': 8.50, 'rate_per_min': 0.80},
}

# Target payout skews relative to expected benchmark
locality_skews = {
    'Koramangala': (1.02, 1.15),      # Fair (Green)
    'Electronic City': (0.65, 0.78),  # Underpaid (Pink)
    'Indiranagar': (0.86, 0.94),      # Mixed (Amber)
    'HSR Layout': (0.88, 0.96),       # Mixed (Amber)
    'Jayanagar': (0.90, 0.98),        # Mixed (Amber)
}

print("Deleting existing jobs in the 'jobs' collection to ensure a clean seed...")
jobs_ref = db.collection('jobs')
docs = jobs_ref.limit(500).get()
deleted_count = 0
for doc in docs:
    doc.reference.delete()
    deleted_count += 1
if deleted_count > 0:
    print(f"Deleted {deleted_count} old job documents.")

print("Generating 180 realistic gig job records...")

# To make sure every combination of locality x platform x time_of_day has at least 2 trips,
# we first seed 1 explicit trip for each of the 5 * 4 * 3 = 60 combinations, and then add 120 random trips.
combinations = []
for loc in localities:
    for plat in platforms:
        for tod in time_of_days:
            combinations.append((loc, plat, tod))

# Duplicate combinations to get 120 base, plus add another 60 random ones
while len(combinations) < 180:
    combinations.append(random.choice(combinations))

batch = db.batch()
count = 0

for i, (loc, plat, tod) in enumerate(combinations):
    worker_id = random.choice(workers)
    
    # 1. Distribute distance and duration realistically
    # Cabs have longer distances (2km to 25km), delivery shorter (1km to 8km)
    if plat in ['uber', 'ola']:
        distance_km = round(random.uniform(2.0, 22.0), 1)
        # Average speed of 25 km/h in BLR traffic
        duration_min = round(distance_km * random.uniform(2.0, 3.5))
    else:
        distance_km = round(random.uniform(1.0, 7.5), 1)
        # Delivery speed of 18 km/h including pickup wait times
        duration_min = round(distance_km * random.uniform(3.0, 4.5) + random.uniform(2, 6))

    # 2. Get platform benchmark rates
    rates = platform_rates[plat]
    expected_fare = round((rates['rate_per_km'] * distance_km) + (rates['rate_per_min'] * duration_min), 2)

    # 3. Apply payout skew based on locality
    skew_min, skew_max = locality_skews[loc]
    payout_skew = random.uniform(skew_min, skew_max)
    fare = round(expected_fare * payout_skew, 2)

    # 4. Underpaid calculation threshold is < 85%
    is_underpaid = fare < (expected_fare * 0.85)

    # 5. Generate timestamp matching time_of_day
    # We spread dates over the last 7 days
    days_ago = random.randint(0, 6)
    base_date = datetime.now() - timedelta(days=days_ago)
    
    if tod == 'morning':
        hour = random.randint(7, 10)
    elif tod == 'evening':
        hour = random.randint(17, 20)
    else: # latenight
        hour = random.choice([22, 23, 0, 1, 2, 3])
        
    job_dt = datetime(base_date.year, base_date.month, base_date.day, hour, random.randint(0, 59), random.randint(0, 59))
    
    # Capitalize platform name for UI explanation
    plat_cap = plat.capitalize()
    explanation = (
        "This came in noticeably below what's typical for this distance and platform."
        if is_underpaid else
        f"This is about what's typical for a {distance_km}km {plat_cap} trip."
    )

    job_data = {
        'user_id': worker_id,
        'platform': plat,
        'fare': fare,
        'distance_km': distance_km,
        'duration_min': duration_min,
        'expected_fare': expected_fare,
        'is_underpaid': is_underpaid,
        'explanation': explanation,
        'source': 'manual',
        'rate_source': 'fallback',
        'sample_size': random.randint(15, 60),
        'area_hint': loc,
        'job_timestamp': job_dt,
        'created_at': job_dt,
        'base_fare': round(fare * 0.4, 2),
        'incentive_amount': 0.0 if is_underpaid else round(fare * random.uniform(0.05, 0.15), 2),
        'surge_amount': round(fare * random.uniform(0.02, 0.08), 2) if (tod == 'evening' or tod == 'latenight') else 0.0,
        'deduction_amount': round(fare * random.uniform(0.05, 0.1), 2) if random.random() < 0.2 else 0.0,
        'deduction_reason_stated': random.random() < 0.5,
    }

    doc_ref = db.collection('jobs').document()
    batch.set(doc_ref, job_data)
    count += 1
    
    # Commit in batches of 100
    if count % 100 == 0:
        batch.commit()
        batch = db.batch()

if count % 100 != 0:
    batch.commit()

print(f"Successfully seeded {count} job documents into Firestore!")
