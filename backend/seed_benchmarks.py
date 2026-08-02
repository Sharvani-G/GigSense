import os
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

# Path to service account key
cred_path = r"C:\Users\tms10\Downloads\gigshield-e38ec-firebase-adminsdk-fbsvc-600a05cdcd (1).json"

cred = credentials.Certificate(cred_path)
firebase_admin.initialize_app(cred)

db = firestore.client()

defaults = {
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

print("Starting Firebase Seeding via Admin SDK...")
for platform, data in defaults.items():
    db.collection('benchmarks').document(platform).set(data)
    print(f"Seeded: {platform}")
print("Seeding finished successfully!")
