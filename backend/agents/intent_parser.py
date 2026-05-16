import os
import json
import time

from services.gemini_client import get_model
from dotenv import load_dotenv

from models.schemas import ParsedIntent


# Load environment variables
load_dotenv()



class IntentParserAgent:
    def __init__(self, tracer):
        self.tracer = tracer
        self.model = get_model()

    async def parse(self, user_input: str) -> ParsedIntent:
        start = time.time()

        prompt = f"""
You are an expert multilingual intent extraction agent for a Pakistani home services platform.

Analyze this service request (may be Urdu, Roman Urdu, English, or mixed):

"{user_input}"

Extract all details and respond ONLY with this exact JSON.
Do NOT return markdown.
Do NOT return explanation text.

{{
    "service_type": "human readable service name in English",
    "service_category": "one of: ac_technician | plumber | electrician | tutor | beautician | carpenter | painter | cleaner | mechanic | other",
    "location": "area/sector name, e.g. G-13, F-10, DHA. Default G-13 if unclear",
    "urgency": "one of: low | medium | high | emergency",
    "requested_time": "one of: today_asap | today_morning | today_afternoon | today_evening | tomorrow_morning | tomorrow_afternoon | this_week | flexible",
    "budget_sensitivity": "one of: low_budget | moderate | flexible",
    "special_notes": "any specific issue, constraint, or detail mentioned",
    "detected_language": "one of: urdu | roman_urdu | english | mixed",
    "confidence": 0.94,
    "needs_clarification": false,
    "clarification_question": null
}}

Rules:
- If confidence < 0.70, set needs_clarification = true
- Write a short clarification question if needed
- Detect budget sensitivity from words like:
  "budget nahi", "sasta", "affordable", "expensive ok"
- Detect urgency from words like:
  "bilkul kaam nahi", "emergency", "urgent", "kal tak"

Location examples:
- G-13
- G-11
- F-10
- F-11
- G-9
- G-10
- DHA
- I-8
- E-11

Roman Urdu examples:
- "chahiye" = need
- "kal" = tomorrow
- "subah" = morning
- "budget zyada nahi" = tight budget

Examples:

Input:
"AC bilkul kaam nahi kar raha, kal subah G-13 mein technician chahiye, budget zyada nahi hai"

Output:
{{
    "service_category": "ac_technician",
    "urgency": "high",
    "location": "G-13",
    "budget_sensitivity": "low_budget"
}}

Input:
"I need a plumber urgently, pipe burst in F-10"

Output:
{{
    "service_category": "plumber",
    "urgency": "emergency",
    "location": "F-10"
}}

Input:
"bijli wala chahiye"

Output:
{{
    "needs_clarification": true,
    "clarification_question": "Aap ka area kya hai? (Which area are you in?)"
}}
"""

        try:
            response = self.model.generate_content(prompt)

            text = (
                response.text
                .strip()
                .replace("```json", "")
                .replace("```", "")
                .strip()
            )

            data = json.loads(text)

        except json.JSONDecodeError:
            data = self._fallback(user_input)

        except Exception:
            data = self._fallback(user_input)

        result = ParsedIntent(**data)

        self.tracer.log(
            agent_name="IntentParserAgent",
            input_data={
                "user_input": user_input
            },
            output_data=data,
            reasoning=(
                f"Analyzed input using Gemini 1.5 Flash. "
                f"Language detected: {result.detected_language}. "
                f"Service identified as '{result.service_type}' "
                f"with {result.urgency} urgency in {result.location}. "
                f"Budget sensitivity: {result.budget_sensitivity}."
            ),
            decision=(
                f"Extracted intent with "
                f"{result.confidence * 100:.0f}% confidence. "
                f"{'Clarification needed: ' + str(result.clarification_question) if result.needs_clarification else 'Confidence sufficient, proceeding.'}"
            ),
            confidence=result.confidence,
            start_time=start
        )

        return result

    def _fallback(self, text: str) -> dict:
        lower = text.lower()

        categories = {
            "ac": "ac_technician",
            "plumber": "plumber",
            "bijli": "electrician",
            "electrician": "electrician",
            "tutor": "tutor",
            "beautician": "beautician",
        }

        category = next(
            (v for k, v in categories.items() if k in lower),
            "other"
        )

        return {
            "service_type": category.replace("_", " ").title(),
            "service_category": category,
            "location": "G-13",
            "urgency": "medium",
            "requested_time": "tomorrow_morning",
            "budget_sensitivity": "moderate",
            "special_notes": "",
            "detected_language": "mixed",
            "confidence": 0.55,
            "needs_clarification": True,
            "clarification_question": (
                "Could you confirm your area and preferred time?"
            )
        }