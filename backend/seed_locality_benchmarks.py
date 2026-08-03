import os
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

localities = ['koramangala', 'indiranagar', 'hsr layout', 'whitefield', 'jayanagar', 'yelahanka', 'electronic city', 'malleshwaram']
platforms = {
    'uber': {'displayName': 'Uber', 'rate_per_km': 16.00, 'rate_per_min': 1.50, 'category': 'cab'},
    'rapido': {'displayName': 'Rapido', 'rate_per_km': 16.50, 'rate_per_min': 1.20, 'category': 'cab'},
    'ola': {'displayName': 'Ola', 'rate_per_km': 15.50, 'rate_per_min': 1.40, 'category': 'cab'},
    'indrive': {'displayName': 'InDrive', 'rate_per_km': 14.50, 'rate_per_min': 1.30, 'category': 'cab'},
    'zomato': {'displayName': 'Zomato', 'rate_per_km': 8.50, 'rate_per_min': 0.80, 'category': 'delivery'},
    'swiggy': {'displayName': 'Swiggy', 'rate_per_km': 8.50, 'rate_per_min': 0.80, 'category': 'delivery'},
    'dunzo': {'displayName': 'Dunzo', 'rate_per_km': 9.00, 'rate_per_min': 0.90, 'category': 'delivery'},
    'blinkit': {'displayName': 'Blinkit', 'rate_per_km': 10.00, 'rate_per_min': 0.60, 'category': 'delivery'},
    'zepto': {'displayName': 'Zepto', 'rate_per_km': 9.50, 'rate_per_min': 0.50, 'category': 'delivery'},
    'bigbasket': {'displayName': 'BigBasket', 'rate_per_km': 11.00, 'rate_per_min': 1.00, 'category': 'delivery'},
    'amazon_flex': {'displayName': 'Amazon Flex', 'rate_per_km': 12.00, 'rate_per_min': 1.10, 'category': 'delivery'},
    'urban_company': {'displayName': 'Urban Company', 'rate_per_km': 15.00, 'rate_per_min': 1.50, 'category': 'other_gig'},
    'porter': {'displayName': 'Porter', 'rate_per_km': 14.00, 'rate_per_min': 1.30, 'category': 'other_gig'},
    'housejoy': {'displayName': 'Housejoy', 'rate_per_km': 13.00, 'rate_per_min': 1.20, 'category': 'other_gig'},
    'other': {'displayName': 'Other', 'rate_per_km': 12.00, 'rate_per_min': 1.00, 'category': 'other_gig'},
}

print("Querying and deleting old locality-specific benchmarks from the benchmarks collection...")
benchmarks_ref = db.collection('benchmarks')
docs = list(benchmarks_ref.stream())
deleted_count = 0
batch = db.batch()
for doc in docs:
    # Locality benchmarks doc IDs contain '_' (e.g., 'koramangala_uber')
    if '_' in doc.id:
        batch.delete(doc.reference)
        deleted_count += 1
        if deleted_count % 400 == 0:
            batch.commit()
            batch = db.batch()
if deleted_count % 400 != 0:
    batch.commit()
print(f"Deleted {deleted_count} old locality-specific benchmarks from the 'benchmarks' collection.")

print("Querying and deleting old locality-specific benchmarks from the 'locality_benchmarks' collection...")
locality_benchmarks_ref = db.collection('locality_benchmarks')
loc_docs = list(locality_benchmarks_ref.stream())
deleted_loc_count = 0
batch = db.batch()
for doc in loc_docs:
    batch.delete(doc.reference)
    deleted_loc_count += 1
    if deleted_loc_count % 400 == 0:
        batch.commit()
        batch = db.batch()
if deleted_loc_count % 400 != 0:
    batch.commit()
print(f"Deleted {deleted_loc_count} old locality-specific benchmarks from the 'locality_benchmarks' collection.")

print("Seeding locality-specific benchmarks to 'locality_benchmarks' collection...")
batch = db.batch()
count = 0
for loc in localities:
    for plat_id, rates in platforms.items():
        doc_id = f"{loc}_{plat_id}"
        
        # Ground expected rates with slight variances per locality for realism
        rate_mult = 1.0
        if loc == 'electronic city':
            rate_mult = 0.95
        elif loc == 'koramangala':
            rate_mult = 1.05
            
        rate_km = round(rates['rate_per_km'] * rate_mult, 2)
        rate_min = round(rates['rate_per_min'] * rate_mult, 2)
        
        doc_data = {
            'displayName': f"{loc.title()} {rates['displayName']}",
            'category': rates['category'],
            'rate_per_km': rate_km,
            'rate_per_min': rate_min,
            'seedRate': {
                'rate_per_km': rate_km,
                'rate_per_min': rate_min
            },
            'communityRate': None,
            'sampleSize': 0
        }
        
        doc_ref = locality_benchmarks_ref.document(doc_id)
        batch.set(doc_ref, doc_data)
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()

if count % 400 != 0:
    batch.commit()
print(f"Successfully seeded {count} locality-specific benchmarks into 'locality_benchmarks'!")
