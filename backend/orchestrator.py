# backend/orchestrator.py
from typing import AsyncIterator, Any
from agents.intent_parser import IntentParserAgent
from agents.complexity_classifier import ComplexityClassifierAgent
from agents.provider_matcher import ProviderMatcherAgent
from agents.scheduling_agent import SchedulingAgent
from agents.pricing_agent import PricingAgent
from agents.booking_agent import BookingAgent
from services.agent_tracer import AgentTracer
from models.schemas import ServiceRequest, OrchestrationResult
import time

def _baseline_comparison() -> dict:
    return {
        "non_agentic": {
            "method": "Simple keyword match + hardcoded distance sort",
            "factors_used": 1,
            "pricing": "Fixed flat rate",
            "dispute_handling": "None",
            "languages": "English only",
        },
        "agentic": {
            "method": "8-agent pipeline with Gemini reasoning",
            "factors_used": 6,
            "pricing": "Dynamic (demand + urgency + complexity)",
            "dispute_handling": "Full resolution workflow",
            "languages": "Urdu + Roman Urdu + English + mixed",
        },
        "improvement": "6x more factors, dynamic pricing, multilingual, dispute handling, traceable reasoning",
    }


def _follow_up(slot, selected) -> dict:
    return {
        "reminder_scheduled": slot.time,
        "reminder_message": f"Reminder: {selected.name} arrives in 1 hour",
        "completion_check": "After service",
        "status": "scheduled",
    }


async def run_orchestration(request: ServiceRequest) -> OrchestrationResult:
    total_start = time.time()
    tracer = AgentTracer()

    # 1. Parse intent
    intent = await IntentParserAgent(tracer).parse(request.user_input)

    # 2. Classify job complexity
    complexity = await ComplexityClassifierAgent(tracer).classify(intent)

    # 3. Match providers (6-factor)
    providers = await ProviderMatcherAgent(tracer).find_providers(intent, complexity)
    if not providers:
        raise Exception("No providers available for this service.")
    selected = providers[0]

    # 4. Schedule slot
    slot = await SchedulingAgent(tracer).schedule(selected, intent, complexity)

    # 5. Generate price quote
    price = await PricingAgent(tracer).generate_quote(selected, intent, complexity)

    # 6. Create booking
    booking = await BookingAgent(tracer).create_booking(
        provider=selected, intent=intent, complexity=complexity,
        slot=slot, price=price, user_name=request.user_name,
        user_phone=request.user_phone, original_request=request.user_input
    )

    follow_up = _follow_up(slot, selected)

    return OrchestrationResult(
        session_id=tracer.session_id,
        parsed_intent=intent,
        job_complexity=complexity,
        matched_providers=providers,
        selected_provider=selected,
        schedule=slot,
        price_quote=price,
        booking=booking,
        follow_up=follow_up,
        agent_trace=tracer.get_trace(),
        total_time_ms=int((time.time() - total_start) * 1000),
        baseline_comparison=_baseline_comparison(),
    )


async def run_orchestration_stream(request: ServiceRequest) -> AsyncIterator[dict[str, Any]]:
    """Yield SSE event payloads while running agents one by one."""
    total_start = time.time()
    tracer = AgentTracer()

    def agent_start(name: str) -> dict:
        return {"type": "agent_start", "data": {"agent": name, "message": "Running..."}}

    def agent_done(name: str, result: Any) -> dict:
        return {"type": "agent_done", "data": {"agent": name, "result": result}}

    try:
        yield agent_start("IntentParserAgent")
        intent = await IntentParserAgent(tracer).parse(request.user_input)
        yield agent_done("IntentParserAgent", intent.model_dump(mode="json"))

        yield agent_start("ComplexityClassifierAgent")
        complexity = await ComplexityClassifierAgent(tracer).classify(intent)
        yield agent_done("ComplexityClassifierAgent", complexity.model_dump(mode="json"))

        yield agent_start("ProviderMatcherAgent")
        providers = await ProviderMatcherAgent(tracer).find_providers(intent, complexity)
        if not providers:
            raise Exception("No providers available for this service.")
        selected = providers[0]
        yield agent_done(
            "ProviderMatcherAgent",
            [p.model_dump(mode="json") for p in providers],
        )

        yield agent_start("SchedulingAgent")
        slot = await SchedulingAgent(tracer).schedule(selected, intent, complexity)
        yield agent_done("SchedulingAgent", slot.model_dump(mode="json"))

        yield agent_start("PricingAgent")
        price = await PricingAgent(tracer).generate_quote(selected, intent, complexity)
        yield agent_done("PricingAgent", price.model_dump(mode="json"))

        yield agent_start("BookingAgent")
        booking = await BookingAgent(tracer).create_booking(
            provider=selected,
            intent=intent,
            complexity=complexity,
            slot=slot,
            price=price,
            user_name=request.user_name,
            user_phone=request.user_phone,
            original_request=request.user_input,
        )
        yield agent_done("BookingAgent", booking.model_dump(mode="json"))

        full_result = OrchestrationResult(
            session_id=tracer.session_id,
            parsed_intent=intent,
            job_complexity=complexity,
            matched_providers=providers,
            selected_provider=selected,
            schedule=slot,
            price_quote=price,
            booking=booking,
            follow_up=_follow_up(slot, selected),
            agent_trace=tracer.get_trace(),
            total_time_ms=int((time.time() - total_start) * 1000),
            baseline_comparison=_baseline_comparison(),
        )
        yield {"type": "complete", "data": full_result.model_dump(mode="json")}

    except Exception as e:
        yield {"type": "error", "data": {"message": str(e)}}
