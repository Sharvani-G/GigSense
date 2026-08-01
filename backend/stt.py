import os
from faster_whisper import WhisperModel

# Initialize Whisper model globally on CPU with int8 quantization for optimal speed/memory
# "small" is selected for optimal multilingual inference on standard laptop CPUs.
print("Loading Whisper 'small' model...")
try:
    model = WhisperModel("small", device="cpu", compute_type="int8")
    print("Whisper model loaded successfully.")
except Exception as e:
    print(f"Error loading Whisper model: {e}")
    model = None

def transcribe_audio(file_path: str, language_code: str = None) -> str:
    """
    Transcribes the audio file at file_path using Whisper.
    language_code: BCP-47 style code e.g., 'en', 'hi', 'kn', 'te', 'ta', 'ml'.
    """
    if model is None:
        raise RuntimeError("Whisper model is not loaded.")
        
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Audio file not found: {file_path}")

    # Map language codes to standard Whisper language codes if necessary
    # en, hi, kn, te, ta, ml are already standard Whisper 2-letter codes.
    whisper_lang = language_code
    if whisper_lang == "en":
        whisper_lang = "en"
    elif whisper_lang == "hi":
        whisper_lang = "hi"
    elif whisper_lang == "kn":
        whisper_lang = "kn"
    elif whisper_lang == "te":
        whisper_lang = "te"
    elif whisper_lang == "ta":
        whisper_lang = "ta"
    elif whisper_lang == "ml":
        whisper_lang = "ml"

    # Transcribe the audio
    segments, info = model.transcribe(file_path, beam_size=5, language=whisper_lang)
    transcript = "".join(segment.text for segment in segments)
    return transcript.strip()
