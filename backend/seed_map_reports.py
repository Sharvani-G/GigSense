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

platform_rates = {
    'uber': {'rate_per_km': 16.00, 'rate_per_min': 1.50},
    'ola': {'rate_per_km': 15.50, 'rate_per_min': 1.40},
    'zomato': {'rate_per_km': 8.50, 'rate_per_min': 0.80},
    'swiggy': {'rate_per_km': 8.50, 'rate_per_min': 0.80},
}

locality_skews = {
    'Koramangala': (1.02, 1.15),      # Fair (Green)
    'Electronic City': (0.65, 0.78),  # Underpaid (Pink)
    'Indiranagar': (0.86, 0.94),      # Mixed (Amber)
    'HSR Layout': (0.88, 0.96),       # Mixed (Amber)
    'Jayanagar': (0.90, 0.98),        # Mixed (Amber)
}

print("Querying and deleting existing seed documents in 'mapFairnessReports' for idempotency...")
reports_ref = db.collection('mapFairnessReports')
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

if deleted_count > 0:
    print(f"Deleted {deleted_count} old seed documents.")
else:
    print("No old seed documents found.")

print("Generating 150 realistic anonymized map reports...")
combinations = []
for loc in localities:
    for plat in platforms:
        for tod in time_of_days:
            combinations.append((loc, plat, tod))

while len(combinations) < 150:
    combinations.append(random.choice(combinations))

batch = db.batch()
count = 0

for i, (loc, plat, tod) in enumerate(combinations):
    if plat in ['uber', 'ola']:
        distance_km = round(random.uniform(2.0, 22.0), 1)
        duration_min = round(distance_km * random.uniform(2.0, 3.5))
    else:
        distance_km = round(random.uniform(1.0, 7.5), 1)
        duration_min = round(distance_km * random.uniform(3.0, 4.5) + random.uniform(2, 6))

    rates = platform_rates[plat]
    expected_fare = round((rates['rate_per_km'] * distance_km) + (rates['rate_per_min'] * duration_min), 2)

    skew_min, skew_max = locality_skews[loc]
    payout_skew = random.uniform(skew_min, skew_max)
    fare = round(expected_fare * payout_skew, 2)

    report_data = {
        'isSeedData': True,
        'platform': plat,
        'locality': loc,
        'timeOfDay': tod,
        'fareActual': fare,
        'fareExpected': expected_fare,
        'distanceKm': distance_km,
        'durationMin': duration_min,
        'reportedAt': firestore.SERVER_TIMESTAMP
    }

    doc_ref = reports_ref.document()
    batch.set(doc_ref, report_data)
    count += 1

    if count % 400 == 0:
        batch.commit()
        batch = db.batch()

if count % 400 != 0:
    batch.commit()

print(f"Successfully seeded {count} anonymized documents into 'mapFairnessReports'!")
