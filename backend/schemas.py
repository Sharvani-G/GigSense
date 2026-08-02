from pydantic import BaseModel
from typing import Optional

class JobScanResponse(BaseModel):
    platform: Optional[str]
    fare: Optional[float]
    distance_km: Optional[float]
    duration_min: Optional[float]
    confidence_note: Optional[str]
    raw_text: str

class ChatRequest(BaseModel):
    message: str
    user_id: str
    session_id: str

class ChatResponse(BaseModel):
    response: str

class ComplaintRequest(BaseModel):
    platform: str
    fare: float
    distance_km: float
    duration_min: float
    expected_fare: float
    user_id: str

class DraftRequest(BaseModel):
    job_id: str
    user_id: str

class FatigueRequest(BaseModel):
    user_id: str
    total_hours: float

class SOSRequest(BaseModel):
    user_id: str
    job_id: Optional[str] = None

class RouteSafetyRequest(BaseModel):
    job_timestamp: str
    area_hint: Optional[str] = None
    language_name: Optional[str] = "English"

class RouteSafetyResponse(BaseModel):
    score: str # "low", "moderate", "higher"
    message: str

class VoiceParseRequest(BaseModel):
    transcript: str
    language_name: str
    target_field: Optional[str] = None

