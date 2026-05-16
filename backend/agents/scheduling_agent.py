# backend/agents/scheduling_agent.py
import time
from datetime import date, timedelta, datetime
from models.schemas import ParsedIntent, Provider, JobComplexity, ScheduleSlot
from services.supabase_client import get_supabase

TIME_MAP = {
    "today_asap":       (0, "09:00:00", "11:00:00"),
    "today_morning":    (0, "10:00:00", "12:00:00"),
    "today_afternoon":  (0, "14:00:00", "16:00:00"),
    "today_evening":    (0, "18:00:00", "20:00:00"),
    "tomorrow_morning": (1, "10:00:00", "12:00:00"),
    "tomorrow_afternoon":(1, "14:00:00","16:00:00"),
    "this_week":        (2, "10:00:00", "12:00:00"),
    "flexible":         (1, "10:00:00", "12:00:00"),
}

ALTERNATIVES = ["09:00 AM", "11:00 AM", "02:00 PM", "04:00 PM", "06:00 PM"]

class SchedulingAgent:
    def __init__(self, tracer):
        self.tracer = tracer
        self.db = get_supabase()

    async def schedule(self, provider: Provider, intent: ParsedIntent,
                       complexity: JobComplexity) -> ScheduleSlot:
        start = time.time()

        day_offset, slot_time, end_time = TIME_MAP.get(
            intent.requested_time, (1, "10:00:00", "12:00:00"))
        slot_date = date.today() + timedelta(days=day_offset)

        # Check for conflicts
        conflict = self.db.table("schedule_slots")\
            .select("*")\
            .eq("provider_id", provider.id)\
            .eq("slot_date", str(slot_date))\
            .eq("slot_time", slot_time)\
            .execute()

        conflict_found = len(conflict.data) > 0
        conflict_reason = None
        alt_slots = ALTERNATIVES

        if conflict_found:
            conflict_reason = f"Provider already booked at {slot_time} on {slot_date}"
            # Find next available slot
            for alt_time in ["11:00:00", "14:00:00", "16:00:00"]:
                alt_check = self.db.table("schedule_slots")\
                    .select("*")\
                    .eq("provider_id", provider.id)\
                    .eq("slot_date", str(slot_date))\
                    .eq("slot_time", alt_time).execute()
                if not alt_check.data:
                    slot_time = alt_time
                    end_time = "16:00:00" if alt_time == "14:00:00" else "18:00:00"
                    conflict_found = False
                    break

        # Travel buffer based on distance
        buffer = 20 if provider.distance_km <= 3 else 30 if provider.distance_km <= 7 else 45

        time_display = datetime.strptime(slot_time, "%H:%M:%S").strftime("%I:%M %p")
        end_display = datetime.strptime(end_time, "%H:%M:%S").strftime("%I:%M %p")
        date_label = ["Today", "Tomorrow", "Day After Tomorrow"][min(day_offset, 2)]

        result = ScheduleSlot(
            date=f"{date_label}, {slot_date.strftime('%B %d')}",
            time=time_display,
            end_time=end_display,
            conflict_found=conflict_found,
            conflict_reason=conflict_reason,
            alternative_slots=alt_slots,
            travel_buffer_minutes=buffer
        )

        self.tracer.log(
            agent_name="SchedulingAgent",
            input_data={"provider": provider.name, "requested_time": intent.requested_time,
                        "date": str(slot_date)},
            output_data={"slot": time_display, "date": result.date,
                         "conflict": conflict_found, "buffer_min": buffer},
            reasoning=f"Checked provider schedule for {slot_date}. "
                      f"{'Conflict detected at requested time — auto-resolved to ' + time_display if conflict_found else 'No conflicts found.'} "
                      f"Travel buffer set to {buffer} min based on {provider.distance_km}km distance.",
            decision=f"Slot assigned: {result.date} at {time_display}. "
                     f"{'Rescheduled from original request.' if conflict_found else 'Matches user preference exactly.'}",
            confidence=0.95,
            start_time=start
        )
        return result