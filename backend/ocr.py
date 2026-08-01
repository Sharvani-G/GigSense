import re
import io
from PIL import Image
import pytesseract
import os

# Explicitly set the path for Windows
if os.name == 'nt':
    pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
def extract_batch_jobs(raw_text: str, default_platform: str) -> list:
    lower_text = raw_text.lower()
    fare_matches = list(re.finditer(r'(?:₹|Rs\.?|INR)\s*(\d+(?:\.\d+)?)', raw_text, re.IGNORECASE))
    
    if len(fare_matches) < 2:
        return []
        
    candidates = []
    used_dist_positions = set()
    used_dur_positions = set()
    
    dist_matches = list(re.finditer(r'(\d+(?:\.\d+)?)\s*(km|m)\b', raw_text, re.IGNORECASE))
    dur_matches = list(re.finditer(r'(\d+(?:\.\d+)?)\s*(min|mins|minutes?|hr|hours?)\b', raw_text, re.IGNORECASE))
    
    platform_map = {
        "uber": "uber", "rapido": "rapido", "ola": "ola", "indrive": "indrive",
        "zomato": "zomato", "swiggy": "swiggy", "dunzo": "dunzo", "blinkit": "blinkit",
        "zepto": "zepto", "bigbasket": "bigbasket", "porter": "porter", "housejoy": "housejoy"
    }

    for f_match in fare_matches:
        try:
            f_val = float(f_match.group(1))
        except ValueError:
            continue
            
        f_pos = f_match.start()
        best_dist = None
        best_dist_val = None
        best_dist_unit = "km"
        min_dist_diff = 150
        
        for d_match in dist_matches:
            d_pos = d_match.start()
            diff = abs(d_pos - f_pos)
            if diff < min_dist_diff and d_pos not in used_dist_positions:
                best_dist = d_pos
                try:
                    best_dist_val = float(d_match.group(1))
                    best_dist_unit = d_match.group(2).lower()
                    min_dist_diff = diff
                except ValueError:
                    pass
                
        best_dur = None
        best_dur_val = None
        best_dur_unit = "min"
        min_dur_diff = 150
        
        for dur_match in dur_matches:
            dur_pos = dur_match.start()
            diff = abs(dur_pos - f_pos)
            if diff < min_dur_diff and dur_pos not in used_dur_positions:
                best_dur = dur_pos
                try:
                    best_dur_val = float(dur_match.group(1))
                    du = dur_match.group(2).lower()
                    best_dur_unit = "hr" if du.startswith("h") else "min"
                    min_dur_diff = diff
                except ValueError:
                    pass
                
        if best_dist is not None:
            used_dist_positions.add(best_dist)
        if best_dur is not None:
            used_dur_positions.add(best_dur)
            
        plat = default_platform
        window_start = max(0, f_pos - 100)
        window_end = min(len(raw_text), f_pos + 100)
        window_text = raw_text[window_start:window_end].lower()
        for kw, p_id in platform_map.items():
            if kw in window_text:
                plat = p_id
                break
                
        candidates.append({
            "platform": plat,
            "fare": f_val,
            "distance": best_dist_val,
            "distance_unit": best_dist_unit,
            "duration": best_dur_val,
            "duration_unit": best_dur_unit
        })
        
    return candidates

def extract_job_data(image_bytes: bytes) -> dict:
    try:
        image = Image.open(io.BytesIO(image_bytes))
        raw_text = pytesseract.image_to_string(image)
    except Exception as e:
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

    # Check for batch scan
    batch_jobs = extract_batch_jobs(raw_text, platform)
    if len(batch_jobs) >= 2:
        currency_pattern = r'(?:₹|Rs\.?|INR)'
        has_currency = bool(re.search(currency_pattern, raw_text, re.IGNORECASE))
        units_pattern = r'\b(?:km|m|min|mins|minutes?|hr|hrs|hours?)\b'
        has_units = bool(re.search(units_pattern, raw_text, re.IGNORECASE))
        is_trip_related = has_currency or has_units or any(kw in lower_text for kw in ["trip", "ride", "earnings", "jobs"])
        
        if is_trip_related:
            all_confident = all(c["fare"] is not None and c["distance"] is not None and c["duration"] is not None for c in batch_jobs)
            return {
                "relevant": True,
                "status": "success" if all_confident else "partial",
                "is_batch": True,
                "candidates": batch_jobs,
                "raw_text": raw_text
            }
            
    # 2. Fare (₹ or Rs followed by digits)
    fare = None
    fare_match = re.search(r'(?:₹|Rs\.?)\s*(\d+(?:\.\d+)?)', raw_text, re.IGNORECASE)
    if fare_match:
        try:
            fare = float(fare_match.group(1))
        except ValueError:
            pass

    # Expanded single-job breakdown parsing
    base_fare = None
    base_match = re.search(r'(?:base\s*fare|base|trip\s*fare|minimum\s*fare)\s*(?:₹|Rs\.?|INR)?\s*(\d+(?:\.\d+)?)', raw_text, re.IGNORECASE)
    if base_match:
        try:
            base_fare = float(base_match.group(1))
        except ValueError:
            pass

    incentive = None
    inc_match = re.search(r'(?:incentive|bonus|quest|promo)\s*(?:₹|Rs\.?|INR)?\s*(\d+(?:\.\d+)?)', raw_text, re.IGNORECASE)
    if inc_match:
        try:
            incentive = float(inc_match.group(1))
        except ValueError:
            pass

    surge = None
    surge_match = re.search(r'(?:surge|peak|boost|demand\s*pricing)\s*(?:₹|Rs\.?|INR)?\s*(\d+(?:\.\d+)?)', raw_text, re.IGNORECASE)
    if surge_match:
        try:
            surge = float(surge_match.group(1))
        except ValueError:
            pass

    deduction = None
    deduction_reason_stated = False
    ded_match = re.search(r'(?:deduction|commission|service\s*fee|fee)\s*(?:₹|Rs\.?|INR)?\s*(\d+(?:\.\d+)?)', raw_text, re.IGNORECASE)
    if ded_match:
        try:
            deduction = float(ded_match.group(1))
            match_start = ded_match.start()
            line_start = raw_text.rfind('\n', 0, match_start) + 1
            line_end = raw_text.find('\n', match_start)
            if line_end == -1:
                line_end = len(raw_text)
            deduction_line = raw_text[line_start:line_end].lower()

            reason_words = ["toll", "cancellation", "tax", "booking", "penalty", "fuel", "wait", "insurance", "convenience", "device", "uber fee", "platform fee"]
            has_reason_word = any(w in deduction_line for w in reason_words)
            is_service_fee = "service fee" in deduction_line or "platform fee" in deduction_line

            words = [w for w in re.findall(r'[a-z]+', deduction_line)]
            has_extra_explanation = len(set(words) - {'deduction', 'commission', 'fee', 'rs', 'inr'}) > 0

            if has_reason_word or is_service_fee or has_extra_explanation:
                deduction_reason_stated = True
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

    has_platform = (platform != "other")
    currency_pattern = r'(?:₹|Rs\.?|INR)'
    has_currency = bool(re.search(currency_pattern, raw_text, re.IGNORECASE))
    units_pattern = r'\b(?:km|m|min|mins|minutes?|hr|hrs|hours?)\b'
    has_units = bool(re.search(units_pattern, raw_text, re.IGNORECASE))
    
    receipt_keywords = ["items", "order total", "restaurant", "add to cart", "delivery address"]
    trip_keywords = ["trip", "ride", "km", "fare", "earnings"]
    
    has_receipt_word = any(kw in lower_text for kw in receipt_keywords)
    has_trip_word = any(kw in lower_text for kw in trip_keywords)
    
    is_trip_related = (has_platform or has_currency or has_units or has_trip_word) and not (has_receipt_word and not has_trip_word)
    
    if fare is not None and distance is not None and duration is not None and is_trip_related:
        ocr_status = "success"
    elif is_trip_related:
        ocr_status = "partial"
    else:
        ocr_status = "irrelevant"

    return {
        "relevant": ocr_status != "irrelevant",
        "status": ocr_status,
        "is_batch": False,
        "platform": platform,
        "fare": fare,
        "distance": distance,
        "distance_unit": distance_unit,
        "duration": duration,
        "duration_unit": duration_unit,
        "base_fare": base_fare,
        "incentive_amount": incentive,
        "surge_amount": surge,
        "deduction_amount": deduction,
        "deduction_reason_stated": deduction_reason_stated,
        "confidence_note": confidence_note,
        "raw_text": raw_text
    }
