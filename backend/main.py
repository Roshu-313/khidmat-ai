# backend/main.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from orchestrator import run_orchestration, run_orchestration_stream
from agents.service_quality_agent import ServiceQualityAgent
from agents.dispute_agent import DisputeAgent
from services.agent_tracer import AgentTracer
from services.supabase_client import get_supabase
from models.schemas import ServiceRequest
import uvicorn
import json

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

@app.post("/api/process-stream")
async def process_stream(request: ServiceRequest):
    async def event_generator():
        async for event in run_orchestration_stream(request):
            yield f"data: {json.dumps(event)}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
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
