import re
import io
from PIL import Image
import pytesseract
import os

# Explicitly set the path for Windows
if os.name == 'nt':
    pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
def extract_job_data(image_bytes: bytes) -> dict:
    try:
        # Load image from bytes
        image = Image.open(io.BytesIO(image_bytes))
        
        # Perform OCR
        raw_text = pytesseract.image_to_string(image)
    except Exception as e:
        # Raise exception to be caught in main.py to return 422
        raise ValueError(f"Failed to process image: {e}")

    platform = "other"
    lower_text = raw_text.lower()
    platform_map = {
        "uber": "uber",
        "rapido": "rapido",
        "ola": "ola",
        "indrive": "indrive",
        "zomato": "zomato",
        "swiggy": "swiggy",
        "dunzo": "dunzo",
        "blinkit": "blinkit",
        "zepto": "zepto",
        "bigbasket": "bigbasket",
        "big basket": "bigbasket",
        "amazon flex": "amazon_flex",
        "amazonflex": "amazon_flex",
        "urban company": "urban_company",
        "urbancompany": "urban_company",
        "porter": "porter",
        "housejoy": "housejoy"
    }
    for keyword, p_id in platform_map.items():
        if keyword in lower_text:
            platform = p_id
            break
            
    # 2. Fare (₹ or Rs followed by digits)
    fare = None
    fare_match = re.search(r'(?:₹|Rs\.?)\s*(\d+(?:\.\d+)?)', raw_text, re.IGNORECASE)
    if fare_match:
        try:
            fare = float(fare_match.group(1))
        except ValueError:
            pass
            
    # 3. Distance (digits followed by km)
    distance_km = None
    dist_match = re.search(r'(\d+(?:\.\d+)?)\s*km', raw_text, re.IGNORECASE)
    if dist_match:
        try:
            distance_km = float(dist_match.group(1))
        except ValueError:
            pass
            
    # 4. Duration (digits followed by min)
    duration_min = None
    dur_match = re.search(r'(\d+(?:\.\d+)?)\s*min', raw_text, re.IGNORECASE)
    if dur_match:
        try:
            duration_min = float(dur_match.group(1))
        except ValueError:
            pass

    # Confidence note construction
    failed_fields = []
    if fare is None:
        failed_fields.append("fare")
    if distance_km is None:
        failed_fields.append("distance")
    if duration_min is None:
        failed_fields.append("duration")
        
    confidence_note = None
    if failed_fields:
        confidence_note = f"Could not confidently read: {', '.join(failed_fields)}"

    return {
        "platform": platform,
        "fare": fare,
        "distance_km": distance_km,
        "duration_min": duration_min,
        "confidence_note": confidence_note,
        "raw_text": raw_text
    }
