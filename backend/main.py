from fastapi import FastAPI
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

app = FastAPI(title="GigShield API")

@app.get("/health")
def health_check():
    # In a fully configured environment, we would query the benchmarks collection here 
    # to verify Firebase connectivity.
    # e.g.:
    # from firebase_client import db
    # benchmarks_ref = db.collection('benchmarks')
    # docs = benchmarks_ref.limit(1).stream()
    return {"status": "ok"}
