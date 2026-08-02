# GiGly Pitch Strategy & Accessibility Thesis

This document outlines the final pitch narrative and out-of-the-box differentiators implemented in GiGly for the Synaptrix Hackathon.

---

## 1. The Accessibility Thesis (Voice + Language)
Instead of presenting native languages and voice features as independent bonus checkboxes, frame them as a unified **"Low-Literacy Accessibility Story"** tailored for the brief's Deepak persona:
- **The Problem**: A significant portion of India’s gig economy workers have low digital/text literacy, or prefer conversational speech over typing long messages in English.
- **The Solution**: GiGly provides a complete end-to-end voice and localized language loop:
  1. **Voice Input (Speech-to-Text)**: Workers tap the microphone button to speak their questions naturally in their native tongue.
  2. **Multilingual Interface**: Static UI text and chatbot responses instantly translate across 5 major Indian languages (English, Hindi, Tamil, Telugu, Kannada).
  3. **Voice Output (Text-to-Speech)**: Gemma's generated text response is read aloud by clicking the speaker icon on the reply bubble, ensuring workers who struggle to read complex text can hear their rights and options.

---

## 2. Fairness Streak & Platform Trust Scores
- **Pitch Line**: *"GiGly doesn't just flag one bad payout — it shows you which platforms are consistently fair to you and which aren't."*
- **Implementation**: Real-time client-side calculation on the Home tab. Each platform pill in the **Platform Breakdown** section now computes a dynamic **Trust Score** (e.g. `Trust: 80%`), representing the percentage of fair-paid trips vs. underpaid trips logged for that specific platform over the last week.

---

## 3. AI-Generated Complaint Drafts
- **Pitch Line**: *"When underpaid, workers don't just get flagged — they get a copy-paste support chat complaint drafted by Gemma in their native language."*
- **Implementation**: Tapping **"DRAFT A COMPLAINT"** on the Fairness Result Screen calls a dedicated backend Gemma endpoint. It generates a short, polite, factual message detailing the exact platform, actual fare, distance, duration, and expected benchmark fare. The text is loaded directly inside a custom dialog with a one-tap **Copy to Clipboard** button.

---

## 4. Worker-Type-Aware Coaching Tone
- **Pitch Line**: *"GiGly doesn't give generic advice — it coaches a cab driver and a delivery rider differently because their weeks look completely different."*
- **Implementation**: Capture of `workerType` (Cab Driver vs. Delivery Rider) on onboarding or profile edit. This selection is fed directly into the system prompts for both the **Chat Assistant** and the **Weekly AI Insight**, allowing Gemma to tailor advice (e.g. optimizing long routes/fares for cab drivers, vs. quick delivery turnaround times and incentive goals for delivery riders) in the worker's selected language.
