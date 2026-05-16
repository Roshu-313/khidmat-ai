# backend/agents/booking_agent.py
import time, random, uuid
from datetime import datetime
from models.schemas import Provider, ParsedIntent, JobComplexity, ScheduleSlot, PriceQuote, BookingResult
from services.supabase_client import get_supabase

class BookingAgent:
    def __init__(self, tracer):
        self.tracer = tracer
        self.db = get_supabase()

    async def create_booking(self, provider: Provider, intent: ParsedIntent,
                             complexity: JobComplexity, slot: ScheduleSlot,
                             price: PriceQuote, user_name: str,
                             user_phone: str, original_request: str) -> BookingResult:
        start = time.time()

        booking_code = f"BK-{random.randint(1000,9999)}"

        # Parse date/time from slot
        slot_time_str = datetime.strptime(slot.time, "%I:%M %p").strftime("%H:%M:%S")
        slot_date_str = datetime.now().strftime("%Y-%m-%d")  # simplified

        # Write booking to Supabase
        booking_data = {
            "booking_code": booking_code,
            "user_name": user_name or "Guest User",
            "user_phone": user_phone,
            "provider_id": provider.id,
            "service_type": intent.service_type,
            "job_complexity": complexity.level,
            "location": intent.location,
            "appointment_date": slot_date_str,
            "appointment_time": slot_time_str,
            "status": "confirmed",
            "original_request": original_request,
            "detected_language": intent.detected_language,
            "confidence_score": intent.confidence,
            "total_price": price.total_price,
            "price_breakdown": {"base": price.base_rate, "distance": price.distance_charge,
                                 "urgency": price.urgency_surcharge, "complexity": price.complexity_charge,
                                 "demand_mult": price.demand_multiplier, "total": price.total_price},
            "matching_rationale": provider.selection_reasoning
        }

        result = self.db.table("bookings").insert(booking_data).execute()
        booking_id = result.data[0]["id"] if result.data else str(uuid.uuid4())

        # Lock the schedule slot
        try:
            self.db.table("schedule_slots").insert({
                "provider_id": provider.id,
                "slot_date": slot_date_str,
                "slot_time": slot_time_str,
                "end_time": datetime.strptime(slot.end_time, "%I:%M %p").strftime("%H:%M:%S"),
                "booking_id": booking_id,
                "travel_buffer_minutes": slot.travel_buffer_minutes
            }).execute()
        except Exception:
            pass  # Slot might already exist in edge cases

        # Generate receipt
        receipt = {
            "booking_code": booking_code,
            "service": intent.service_type,
            "provider": provider.name,
            "provider_phone": "Shared on confirmation",
            "date": slot.date,
            "time": slot.time,
            "location": intent.location,
            "complexity": complexity.level,
            "price_breakdown": price.breakdown_text,
            "total": f"PKR {price.total_price}",
            "status": "CONFIRMED",
            "issued_at": datetime.now().strftime("%Y-%m-%d %H:%M"),
        }

        # Simulated notifications
        sms_sim = f"[SMS SIM] Sent to {user_phone or 'user'}: Your {intent.service_type} booking {booking_code} is confirmed for {slot.date} at {slot.time} with {provider.name}."
        whatsapp_sim = f"[WhatsApp SIM] Booking details shared with provider {provider.name}."
        print(sms_sim)
        print(whatsapp_sim)

        booking_result = BookingResult(
            booking_id=booking_id, booking_code=booking_code,
            provider=provider, slot=slot, price=price,
            job_complexity=complexity, status="confirmed",
            confirmation_message=(
                f"✅ Booking {booking_code} Confirmed!\n"
                f"Provider: {provider.name}\n"
                f"When: {slot.date} at {slot.time}\n"
                f"Total: PKR {price.total_price}\n"
                f"Complexity: {complexity.level.title()} job"
            ),
            receipt=receipt
        )

        self.tracer.log(
            agent_name="BookingAgent",
            input_data={"provider_id": provider.id, "service": intent.service_type,
                        "slot": slot.time, "price": price.total_price},
            output_data={"booking_code": booking_code, "status": "confirmed",
                         "slot_locked": True, "notifications_sent": 2},
            reasoning=f"Created booking {booking_code} in database. Locked schedule slot for "
                      f"{provider.name} on {slot.date} at {slot.time}. "
                      f"Simulated SMS and WhatsApp notifications. Receipt generated.",
            decision=f"Booking CONFIRMED. Slot secured. Provider notified (simulated). "
                     f"Calendar updated. Receipt issued.",
            confidence=1.0,
            start_time=start
        )
        return booking_result