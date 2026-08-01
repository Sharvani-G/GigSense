import os
import firebase_admin
from firebase_admin import credentials, firestore

from dotenv import load_dotenv

# Load env variables in case this is imported before main.py calls load_dotenv()
load_dotenv()

cred_path = os.environ.get("FIREBASE_CREDENTIALS_PATH", "")

# Initialize Firebase Admin if credentials path is provided
db = None
if cred_path and os.path.exists(cred_path):
    try:
        if not firebase_admin._apps:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
        db = firestore.client()
    except Exception as e:
        print(f"Firebase initialization failed: {e}")
