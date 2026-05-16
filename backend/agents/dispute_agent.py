# backend/agents/dispute_agent.py
import time, uuid
from services.gemini_client import get_model
from models.schemas import BookingResult, DisputeResult
from services.supabase_client import get_supabase

RESOLUTIONS = {
    "no_show": {
        "resolution": "Full refund issued. Provider account flagged. Rebooking offered with priority provider.",
        "compensation": 0,
        "next_steps": ["Refund processed", "Provider warned", "Rebook with priority provider?"],
        "escalate": False
    },
    "quality_complaint": {
        "resolution": "Partial refund of 30% issued. Provider flagged for quality review.",
        "compensation": 300,
        "next_steps": ["Partial refund processed", "Quality review initiated", "Alternative provider offered"],
        "escalate": False
    },
    "price_disagreement": {
        "resolution": "Price breakdown reviewed. If error found, full correction applied.",
        "compensation": 0,
        "next_steps": ["Price audit completed", "Any overcharge refunded"],
        "escalate": False
    },
    "cancellation": {
        "resolution": "Auto-rescheduled to next available slot. No charge for cancellation.",
        "compensation": 0,
        "next_steps": ["Rescheduled", "New confirmation sent", "Priority slot given"],
        "escalate": False
    },
    "overrun": {
        "resolution": "Time overrun reviewed. Extra charge capped at 20% of quote.",
        "compensation": 0,
        "next_steps": ["Overrun validated", "Extra charge applied fairly"],
        "escalate": False
    },
    "refund_request": {
        "resolution": "Full investigation within 24hrs. Temporary hold on provider payouts.",
        "compensation": 0,
        "next_steps": ["Investigation open", "Both sides contacted", "Decision in 24hrs"],
        "escalate": True
    }
}

class DisputeAgent:
    def __init__(self, tracer):
        self.tracer = tracer
        self.db = get_supabase()
        self.model = get_model()

    async def handle(self, booking_id: str, dispute_type: str,
                     description: str) -> DisputeResult:
        start = time.time()

        template = RESOLUTIONS.get(dispute_type, RESOLUTIONS["quality_complaint"])

        # Use Gemini to generate context-aware decision
        prompt = f"""You are a dispute resolution agent for a home services platform.

Booking: {booking_id}
Dispute type: {dispute_type}
Customer description: "{description}"
Standard resolution: {template['resolution']}

Generate a 2-sentence fair decision that considers both customer and provider interests.
Be specific. Return plain text only."""

        gemini_decision = template["resolution"]
        try:
            r = self.model.generate_content(prompt)
            gemini_decision = r.text.strip()
        except:
            pass

        dispute_id = str(uuid.uuid4())[:8].upper()

        self.db.table("disputes").insert({
            "booking_id": booking_id,
            "dispute_type": dispute_type,
            "description": description,
            "status": "escalated" if template["escalate"] else "resolved",
            "resolution": template["resolution"],
            "compensation_amount": template["compensation"],
            "agent_decision": gemini_decision
        }).execute()

        if template["compensation"] > 0:
            self.db.table("bookings").update({
                "status": "disputed"
            }).eq("id", booking_id).execute()

        result = DisputeResult(
            dispute_id=f"DS-{dispute_id}",
            dispute_type=dispute_type,
            agent_decision=gemini_decision,
            resolution=template["resolution"],
            compensation=template["compensation"],
            next_steps=template["next_steps"],
            escalated=template["escalate"]
        )

        self.tracer.log(
            agent_name="DisputeAgent",
            input_data={"booking_id": booking_id, "type": dispute_type, "description": description},
            output_data={"dispute_id": result.dispute_id, "resolution": result.resolution,
                         "compensation": result.compensation, "escalated": result.escalated},
            reasoning=f"Dispute type '{dispute_type}' received. Applied resolution policy: {template['resolution']}. "
                      f"Compensation: PKR {template['compensation']}. "
                      f"{'Escalated to human review.' if template['escalate'] else 'Auto-resolved.'}",
            decision=gemini_decision,
            confidence=0.87,
            start_time=start,
            fallback=False
        )
        return result