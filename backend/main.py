# backend/main.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from orchestrator import run_orchestration
from agents.service_quality_agent import ServiceQualityAgent
from agents.dispute_agent import DisputeAgent
from services.agent_tracer import AgentTracer
from services.supabase_client import get_supabase
from models.schemas import ServiceRequest, OrchestrationResult
import uvicorn
import json
import asyncio
import time

# Required agent imports for SSE streaming
from agents.intent_parser import IntentParserAgent
from agents.complexity_classifier import ComplexityClassifierAgent
from agents.provider_matcher import ProviderMatcherAgent
from agents.scheduling_agent import SchedulingAgent
from agents.pricing_agent import PricingAgent
from agents.booking_agent import BookingAgent

app = FastAPI(title="Khidmat AI", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"]
)

@app.get("/")
def root():
    return {"status": "live", "version": "2.0.0", "agents": 8}

@app.post("/api/process-request")
async def process(request: ServiceRequest):
    try:
        return await run_orchestration(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# NEW: SSE Streaming Endpoint
@app.post("/api/process-stream")
async def process_stream(request: ServiceRequest):
    """
    Streams agent results one by one using Server-Sent Events.
    Each agent completion is pushed immediately to the client.
    """

    async def event_generator():
        tracer = AgentTracer()
        total_start = time.time()

        try:
            # Step 1: Intent Parser
            yield f"data: {json.dumps({'type': 'agent_start', 'data': {'agent': 'IntentParserAgent', 'step': 1, 'total': 6, 'message': 'Analyzing your request...'}})}\n\n"

            intent = await IntentParserAgent(tracer).parse(request.user_input)

            yield f"data: {json.dumps({'type': 'agent_done', 'data': {'agent': 'IntentParserAgent', 'step': 1, 'result': intent.model_dump(mode='json')}})}\n\n"

            await asyncio.sleep(0.1)

            # Step 2: Complexity Classifier
            yield f"data: {json.dumps({'type': 'agent_start', 'data': {'agent': 'ComplexityClassifierAgent', 'step': 2, 'total': 6, 'message': 'Classifying job complexity...'}})}\n\n"

            complexity = await ComplexityClassifierAgent(tracer).classify(intent)

            yield f"data: {json.dumps({'type': 'agent_done', 'data': {'agent': 'ComplexityClassifierAgent', 'step': 2, 'result': complexity.model_dump(mode='json')}})}\n\n"

            await asyncio.sleep(0.1)

            # Step 3: Provider Matcher
            yield f"data: {json.dumps({'type': 'agent_start', 'data': {'agent': 'ProviderMatcherAgent', 'step': 3, 'total': 6, 'message': 'Finding and ranking providers...'}})}\n\n"

            providers = await ProviderMatcherAgent(tracer).find_providers(
                intent,
                complexity
            )

            yield f"data: {json.dumps({'type': 'agent_done', 'data': {'agent': 'ProviderMatcherAgent', 'step': 3, 'result': [p.model_dump(mode='json') for p in providers]}})}\n\n"

            await asyncio.sleep(0.1)

            # Step 4: Scheduling
            yield f"data: {json.dumps({'type': 'agent_start', 'data': {'agent': 'SchedulingAgent', 'step': 4, 'total': 6, 'message': 'Checking availability and conflicts...'}})}\n\n"

            slot = await SchedulingAgent(tracer).schedule(
                providers[0],
                intent,
                complexity
            )

            yield f"data: {json.dumps({'type': 'agent_done', 'data': {'agent': 'SchedulingAgent', 'step': 4, 'result': slot.model_dump(mode='json')}})}\n\n"

            await asyncio.sleep(0.1)

            # Step 5: Pricing
            yield f"data: {json.dumps({'type': 'agent_start', 'data': {'agent': 'PricingAgent', 'step': 5, 'total': 6, 'message': 'Calculating dynamic price quote...'}})}\n\n"

            price = await PricingAgent(tracer).generate_quote(
                providers[0],
                intent,
                complexity
            )

            yield f"data: {json.dumps({'type': 'agent_done', 'data': {'agent': 'PricingAgent', 'step': 5, 'result': price.model_dump(mode='json')}})}\n\n"

            await asyncio.sleep(0.1)

            # Step 6: Booking
            yield f"data: {json.dumps({'type': 'agent_start', 'data': {'agent': 'BookingAgent', 'step': 6, 'total': 6, 'message': 'Confirming booking and sending notifications...'}})}\n\n"

            booking = await BookingAgent(tracer).create_booking(
                provider=providers[0],
                intent=intent,
                complexity=complexity,
                slot=slot,
                price=price,
                user_name=request.user_name,
                user_phone=request.user_phone,
                original_request=request.user_input
            )

            yield f"data: {json.dumps({'type': 'agent_done', 'data': {'agent': 'BookingAgent', 'step': 6, 'result': booking.model_dump(mode='json')}})}\n\n"

            # Same shape as /api/process-request so the mobile result screen works
            total_ms = int((time.time() - total_start) * 1000)
            selected = providers[0]
            follow_up = {
                "reminder_scheduled": slot.time,
                "reminder_message": f"Reminder: {selected.name} arrives in 1 hour",
                "completion_check": "After service",
                "status": "scheduled",
            }
            baseline = {
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
            full_result = OrchestrationResult(
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
                total_time_ms=total_ms,
                baseline_comparison=baseline,
            )
            yield f"data: {json.dumps({'type': 'complete', 'data': full_result.model_dump(mode='json')})}\n\n"

        except Exception as e:
            yield f"data: {json.dumps({'type': 'error', 'data': {'message': str(e)}})}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # Important for Railway/nginx
        }
    )

@app.post("/api/submit-feedback")
async def feedback(booking_id: str, rating: int, comment: str):
    tracer = AgentTracer()
    agent = ServiceQualityAgent(tracer)
    return await agent.collect_feedback(booking_id, rating, comment)

@app.post("/api/dispute")
async def dispute(booking_id: str, dispute_type: str, description: str):
    tracer = AgentTracer()
    agent = DisputeAgent(tracer)
    return await agent.handle(booking_id, dispute_type, description)

@app.get("/api/providers")
def providers(category: str = None):
    db = get_supabase()
    q = db.table("providers").select("*")

    if category:
        q = q.eq("service_category", category)

    return {"providers": q.execute().data}

@app.get("/api/bookings")
def bookings():
    db = get_supabase()

    return {
        "bookings": db.table("bookings")
        .select("*")
        .order("created_at", desc=True)
        .limit(20)
        .execute()
        .data
    }

@app.get("/api/agent-trace/{session_id}")
def trace(session_id: str):
    db = get_supabase()

    return {
        "trace": db.table("agent_logs")
        .select("*")
        .eq("session_id", session_id)
        .order("step_number")
        .execute()
        .data
    }

@app.get("/api/stress-test/{scenario}")
async def stress_test(scenario: str):
    """Pre-built stress test scenarios for demo"""

    scenarios = {
        "no_provider": ServiceRequest(
            user_input="Mujhe F-100 mein AC technician chahiye G-100 area"
        ),
        "ambiguous": ServiceRequest(
            user_input="kuch kaam karna hai"
        ),
        "budget": ServiceRequest(
            user_input="sasta plumber chahiye, budget 200 rupees"
        ),
        "emergency": ServiceRequest(
            user_input="pipe burst emergency G-9 abhi chahiye"
        ),
        "cancellation": ServiceRequest(
            user_input="AC service tomorrow G-13 morning"
        ),
    }

    req = scenarios.get(scenario, scenarios["ambiguous"])

    try:
        return await run_orchestration(req)

    except Exception as e:
        return {
            "error": str(e),
            "scenario": scenario,
            "fallback_triggered": True
        }

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)