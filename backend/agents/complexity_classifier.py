# backend/agents/complexity_classifier.py
import json, time
from services.gemini_client import get_model
from models.schemas import ParsedIntent, JobComplexity

class ComplexityClassifierAgent:
    def __init__(self, tracer):
        self.tracer = tracer
        self.model = get_model()

    async def classify(self, intent: ParsedIntent) -> JobComplexity:
        start = time.time()

        prompt = f"""You are a job complexity classifier for home services in Pakistan.

Service type: {intent.service_type}
Special notes: {intent.special_notes}
Urgency: {intent.urgency}

Classify complexity and respond ONLY with this JSON:
{{
  "level": "basic | intermediate | complex",
  "reasoning": "one sentence explanation",
  "required_skills": ["skill1", "skill2"],
  "estimated_duration_hours": 2.0,
  "tools_required": ["tool1", "tool2"]
}}

Rules:
- basic: simple tasks, no special tools, <1hr (fan cleaning, tap fix, basic wiring)
- intermediate: moderate skills needed, 1-3hrs (AC gas refill, pipe replacement, new wiring)
- complex: expert skills, special tools, >3hrs (AC compressor, boiler work, complete rewiring)
- Use special_notes to refine: "bilkul kaam nahi" = likely complex
"""
        response = self.model.generate_content(prompt)
        text = response.text.strip().replace("```json","").replace("```","").strip()

        try:
            data = json.loads(text)
        except:
            data = {"level": "intermediate", "reasoning": "Default classification applied",
                    "required_skills": ["general"], "estimated_duration_hours": 2.0,
                    "tools_required": ["standard toolkit"]}

        result = JobComplexity(**data)

        self.tracer.log(
            agent_name="ComplexityClassifierAgent",
            input_data={"service_type": intent.service_type, "notes": intent.special_notes},
            output_data=data,
            reasoning=f"Analyzed '{intent.service_type}' with notes '{intent.special_notes}'. "
                      f"Classification: {result.level}. {result.reasoning}",
            decision=f"Job classified as {result.level.upper()}. Estimated {result.estimated_duration_hours}hrs. "
                     f"Will filter providers who match {result.level}+ complexity level.",
            confidence=0.88,
            start_time=start
        )
        return result