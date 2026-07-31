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
            
    # 3. Distance
    distance = None
    distance_unit = "km"
    dist_match = re.search(r'(\d+(?:\.\d+)?)\s*(km|m)\b', raw_text, re.IGNORECASE)
    if dist_match:
        try:
            distance = float(dist_match.group(1))
            distance_unit = dist_match.group(2).lower()
        except ValueError:
            pass
            
    # 4. Duration
    duration = None
    duration_unit = "min"
    dur_match = re.search(r'(\d+(?:\.\d+)?)\s*(min|mins|minutes?|hr|hours?)\b', raw_text, re.IGNORECASE)
    if dur_match:
        try:
            duration = float(dur_match.group(1))
            du = dur_match.group(2).lower()
            duration_unit = "hr" if du.startswith("h") else "min"
        except ValueError:
            pass

    # Confidence note construction
    failed_fields = []
    if fare is None:
        failed_fields.append("fare")
    if distance is None:
        failed_fields.append("distance")
    if duration is None:
        failed_fields.append("duration")
        
    confidence_note = None
    if failed_fields:
        confidence_note = f"Could not confidently read: {', '.join(failed_fields)}"

    # Relevance Checking
    receipt_keywords = ["items", "order total", "restaurant", "add to cart", "delivery address"]
    trip_keywords = ["trip", "ride", "km", "fare", "earnings"]
    
    has_receipt_word = any(kw in lower_text for kw in receipt_keywords)
    has_trip_word = any(kw in lower_text for kw in trip_keywords)
    
    if has_receipt_word and not has_trip_word:
        return {"relevant": False, "reason": "This looks like a food/shopping receipt, not a gig worker pay screenshot."}
        
    if fare is None and (distance is None and duration is None):
        return {"relevant": False, "reason": "Could not detect fare and trip distance/duration on this image."}

    return {
        "relevant": True,
        "platform": platform,
        "fare": fare,
        "distance": distance,
        "distance_unit": distance_unit,
        "duration": duration,
        "duration_unit": duration_unit,
        "confidence_note": confidence_note,
        "raw_text": raw_text
    }
