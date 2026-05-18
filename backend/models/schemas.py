from pydantic import BaseModel 
from typing import Optional, List, Dict, Any 
from datetime import datetime 
 
class ServiceRequest(BaseModel): 
    user_input: str 
    user_name: Optional[str] = "Guest User" 
    user_phone: Optional[str] = None 
    user_location: Optional[str] = None  # override if GPS available 
 
class ParsedIntent(BaseModel): 
    service_type: str 
    service_category: str 
    location: str 
    urgency: str             # low / medium / high / emergency 
    requested_time: str      # today_morning / tomorrow_morning etc. 
    budget_sensitivity: str  # low_budget / moderate / flexible 
    special_notes: Optional[str] = ""
    detected_language: str   # urdu / roman_urdu / english / mixed 
    confidence: float        # 0.0 - 1.0 
    needs_clarification: bool 
    clarification_question: Optional[str] = None 
 
class JobComplexity(BaseModel): 
    level: str              # basic / intermediate / complex 
    reasoning: str 
    required_skills: List[str] 
    estimated_duration_hours: float 
    tools_required: List[str] 
 
class Provider(BaseModel): 
    id: str 
    name: str 
    service_category: str 
    specializations: List[str] 
    area: str 
    rating: float 
    distance_km: float 
    on_time_score: float 
    cancellation_rate: float 
    experience_years: int 
    complexity_level: str 
    hourly_rate: int 
    is_available: bool 
    jobs_today: int 
    risk_score: float 
    composite_score: float 
    rank: int 
    selection_reasoning: str 
 
class ScheduleSlot(BaseModel): 
    date: str 
    time: str 
    end_time: str 
    conflict_found: bool 
    conflict_reason: Optional[str] = None 
    alternative_slots: List[str] 
    travel_buffer_minutes: int 
 
class PriceQuote(BaseModel): 
    base_rate: int 
    distance_charge: int 
    urgency_surcharge: int 
    complexity_charge: int 
    demand_multiplier: float 
    loyalty_discount: int 
    total_price: int 
    currency: str = "PKR" 
    breakdown_text: str 
    budget_alternative: Optional[Dict[str, Any]] = None 
    is_fair_to_provider: bool 
    is_within_budget: bool 
 
class BookingResult(BaseModel): 
    booking_id: str 
    booking_code: str 
    provider: Provider 
    slot: ScheduleSlot 
    price: PriceQuote 
    job_complexity: JobComplexity 
    status: str 
    confirmation_message: str 
    receipt: Dict[str, Any] 
 
class ServiceUpdate(BaseModel): 
    booking_id: str 
    stage: str   # enroute / arrived / in_progress / completed 
    update_message: str 
    checklist_items: List[Dict[str, Any]] 
    photo_evidence_placeholder: str 
 
class FeedbackResult(BaseModel): 
    booking_id: str 
    rating: int 
    review: str 
    provider_new_rating: float 
    reputation_updated: bool 
    impact_summary: str 
 
class DisputeResult(BaseModel): 
    dispute_id: str 
    dispute_type: str 
    agent_decision: str 
    resolution: str 
    compensation: int 
    next_steps: List[str] 
    escalated: bool 
 
class AgentLog(BaseModel): 
    session_id: str 
    agent_name: str 
    step_number: int 
    input_data: Dict 
    output_data: Dict 
    reasoning: str 
    decision: str 
    confidence: float 
    execution_time_ms: int 
    status: str = "success"
    fallback_triggered: bool = False 
    fallback_reason: Optional[str] = None 
 
class OrchestrationResult(BaseModel): 
    session_id: str 
    parsed_intent: ParsedIntent 
    job_complexity: JobComplexity 
    matched_providers: List[Provider] 
    selected_provider: Provider 
    schedule: ScheduleSlot 
    price_quote: PriceQuote 
    booking: BookingResult 
    follow_up: Dict 
    agent_trace: List[AgentLog] 
    total_time_ms: int 
    baseline_comparison: Dict  # agentic vs non-agentic comparison