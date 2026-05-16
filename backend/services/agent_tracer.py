# backend/services/agent_tracer.py 
import time, uuid 
from typing import List 
from services.supabase_client import get_supabase 
 
class AgentTracer: 
    def __init__(self): 
        self.session_id = str(uuid.uuid4())[:8].upper() 
        self.logs = [] 
        self.step = 0 
 
    def log(self, agent_name: str, input_data: dict, output_data: dict, 
            reasoning: str, decision: str, confidence: float, 
            start_time: float, fallback: bool = False, fallback_reason: str = None): 
        self.step += 1 
        elapsed = int((time.time() - start_time) * 1000) 
        entry = { 
            "session_id": self.session_id, 
            "agent_name": agent_name, 
            "step_number": self.step, 
            "input_data": input_data, 
            "output_data": output_data, 
            "reasoning": reasoning, 
            "decision": decision, 
            "confidence": confidence, 
            "execution_time_ms": elapsed, 
            "status": "success", 
            "fallback_triggered": fallback, 
            "fallback_reason": fallback_reason 
        } 
        self.logs.append(entry) 
        try: 
            get_supabase().table("agent_logs").insert(entry).execute() 
        except Exception as e: 
            print(f"Trace save error: {e}") 
        return entry 
 
    def get_trace(self) -> List[dict]: 
        return self.logs