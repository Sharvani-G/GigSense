import os
import random
import sys
from datetime import datetime, timedelta
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

# Reconfigure stdout to avoid CP1252 encoding issues on Windows
sys.stdout.reconfigure(encoding='utf-8')

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

reports_ref = db.collection('mapFairnessReports')

# 1. Clean existing seed data
print("Querying and deleting existing seed documents in 'mapFairnessReports' for idempotency...")
query = reports_ref.where('isSeedData', '==', True).limit(500)
docs = query.get()
deleted_count = 0
while len(docs) > 0:
    batch = db.batch()
    for doc in docs:
        batch.delete(doc.reference)
        deleted_count += 1
    batch.commit()
    docs = query.get()

print(f"Deleted {deleted_count} old seed documents.")

# Config options
platforms = ['zomato', 'swiggy', 'uber', 'ola']
time_of_days = ['morning', 'evening', 'latenight']

# 2. Generate 1200 fair logs in Koramangala & Malleshwaram
# 3. Generate 300 fair logs in Jayanagar (JP Nagar/Jayaprakash Nagar)
# 4. Generate 500 unfair logs in Electronic City & Yelahanka
print("Generating 1500 fair logs (1200 in Koramangala/Malleshwaram, 300 in JP Nagar/Jayaprakash Nagar)...")
print("Generating 500 unfair logs in Electronic City/Yelahanka...")

reports_data = []

# Helper to generate single report data
def make_report(locality, is_fair):
    plat = random.choice(platforms)
    tod = random.choice(time_of_days)
    
    if plat in ['uber', 'ola']:
        distance_km = round(random.uniform(2.0, 22.0), 1)
        duration_min = round(distance_km * random.uniform(2.0, 3.5))
        rate_per_km = 16.00 if plat == 'uber' else 15.50
        rate_per_min = 1.50 if plat == 'uber' else 1.40
    else:
        distance_km = round(random.uniform(1.0, 7.5), 1)
        duration_min = round(distance_km * random.uniform(3.0, 4.5) + random.uniform(2, 6))
        rate_per_km = 8.50
        rate_per_min = 0.80
        
    expected_fare = round((rate_per_km * distance_km) + (rate_per_min * duration_min), 2)
    
    if is_fair:
        # Fair: payout is 100% to 115% of expected
        payout_multiplier = random.uniform(1.00, 1.15)
    else:
        # Unfair: payout is 65% to 75% of expected (clearly < 85%)
        payout_multiplier = random.uniform(0.65, 0.75)
        
    fare = round(expected_fare * payout_multiplier, 2)
    
    # Random reported date within the last 7 days
    reported_date = datetime.now() - timedelta(days=random.uniform(0, 7))
    
    return {
        'isSeedData': True,
        'platform': plat,
        'locality': locality.lower(),
        'timeOfDay': tod,
        'fareActual': fare,
        'fareExpected': expected_fare,
        'distanceKm': distance_km,
        'durationMin': duration_min,
        'reportedAt': reported_date
    }

# 1200 Koramangala / Malleshwaram (Fair)
for _ in range(1200):
    loc = random.choice(['Koramangala', 'Malleshwaram'])
    reports_data.append(make_report(loc, is_fair=True))

# 300 JP Nagar / Jayaprakash Nagar (Fair)
# These should resolve to Jayanagar in the app
for _ in range(300):
    loc = random.choice(['JP Nagar', 'Jayaprakash Nagar', 'J.P. Nagar'])
    reports_data.append(make_report(loc, is_fair=True))

# 500 Electronic City / Yelahanka (Unfair)
for _ in range(500):
    loc = random.choice(['Electronic City', 'Yelahanka'])
    reports_data.append(make_report(loc, is_fair=False))

# Shuffle reports list
random.shuffle(reports_data)

# 5. Write to Firestore in batches of 400
batch = db.batch()
count = 0
for data in reports_data:
    doc_ref = reports_ref.document()
    batch.set(doc_ref, data)
    count += 1
    if count % 400 == 0:
        batch.commit()
        batch = db.batch()
        print(f"Uploaded {count}/2000 reports...")

if count % 400 != 0:
    batch.commit()

print(f"Successfully seeded {count} anonymized documents into 'mapFairnessReports'!")
