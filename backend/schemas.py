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
