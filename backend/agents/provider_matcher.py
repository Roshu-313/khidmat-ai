# backend/agents/provider_matcher.py
import math, time
from typing import List
from models.schemas import ParsedIntent, JobComplexity, Provider
from services.supabase_client import get_supabase

AREA_COORDS = {
    "G-13": (33.6844, 73.0479), "G-11": (33.6938, 73.0551),
    "G-10": (33.6880, 73.0520), "G-9":  (33.6900, 73.0600),
    "F-10": (33.7077, 73.0420), "F-11": (33.7050, 73.0500),
    "F-8":  (33.7100, 73.0400), "I-8":  (33.6700, 73.0800),
    "E-11": (33.7150, 73.0300), "DHA":  (33.5400, 73.1200),
}

COMPLEXITY_RANK = {"basic": 1, "intermediate": 2, "complex": 3}

def haversine(lat1, lon1, lat2, lon2) -> float:
    R = 6371
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2-lat1)
    dl = math.radians(lon2-lon1)
    a = math.sin(dp/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

class ProviderMatcherAgent:
    def __init__(self, tracer):
        self.tracer = tracer
        self.db = get_supabase()

    async def find_providers(self, intent: ParsedIntent,
                             complexity: JobComplexity) -> List[Provider]:
        start = time.time()
        user_lat, user_lon = AREA_COORDS.get(intent.location, AREA_COORDS["G-13"])

        # Fetch from Supabase
        raw = self.db.table("providers")\
            .select("*")\
            .eq("service_category", intent.service_category)\
            .eq("is_available", True)\
            .execute().data

        if not raw:
            # Fallback: broader search
            raw = self.db.table("providers").select("*")\
                .eq("is_available", True).execute().data[:8]

        scored = []
        for p in raw:
            dist = haversine(user_lat, user_lon, p["latitude"], p["longitude"])
            score, factors = self._composite_score(p, dist, intent, complexity)
            scored.append((score, dist, p, factors))

        scored.sort(key=lambda x: x[0])

        providers = []
        for rank, (score, dist, p, factors) in enumerate(scored[:5]):
            reasoning = self._build_reasoning(rank, p, dist, factors, intent, complexity)
            providers.append(Provider(
                id=p["id"], name=p["name"],
                service_category=p["service_category"],
                specializations=p.get("specializations", []),
                area=p["area"], rating=float(p["rating"]),
                distance_km=round(dist, 1),
                on_time_score=float(p["on_time_score"]),
                cancellation_rate=float(p["cancellation_rate"]),
                experience_years=p["experience_years"],
                complexity_level=p["complexity_level"],
                hourly_rate=p["hourly_rate"],
                is_available=p["is_available"],
                jobs_today=p["jobs_today"],
                risk_score=float(p["risk_score"]),
                composite_score=round(score, 4),
                rank=rank+1,
                selection_reasoning=reasoning
            ))

        best = providers[0]
        self.tracer.log(
            agent_name="ProviderMatcherAgent",
            input_data={"service": intent.service_category, "location": intent.location,
                        "complexity": complexity.level, "budget": intent.budget_sensitivity},
            output_data={"total_found": len(raw), "ranked": len(providers),
                         "winner": best.name, "winner_score": best.composite_score},
            reasoning=f"Fetched {len(raw)} {intent.service_category} providers. Applied 6-factor scoring: "
                      f"distance(20%), reliability(20%), rating(18%), specialization(15%), "
                      f"availability(15%), price(12%). {best.name} ranked #1 with score {best.composite_score:.4f}.",
            decision=f"Selected {best.name} (score={best.composite_score:.4f}). "
                     f"{best.selection_reasoning}",
            confidence=0.91,
            start_time=start
        )
        return providers

    def _composite_score(self, p, dist, intent, complexity):
        # Factor 1: Distance (lower=better, normalize over 15km)
        f1 = min(dist / 15.0, 1.0)

        # Factor 2: Reliability (on_time_score, invert)
        f2 = 1.0 - float(p["on_time_score"])

        # Factor 3: Rating (weighted by recency, penalize recent negatives)
        rating_norm = (5.0 - float(p["rating"])) / 5.0
        recency_penalty = min(p.get("recent_negative_reviews", 0) * 0.05, 0.3)
        f3 = rating_norm + recency_penalty

        # Factor 4: Specialization match (lower=better)
        job_complexity_rank = COMPLEXITY_RANK.get(complexity.level, 2)
        provider_rank = COMPLEXITY_RANK.get(p.get("complexity_level", "basic"), 1)
        f4 = 0.0 if provider_rank >= job_complexity_rank else 0.5

        # Factor 5: Availability (capacity check)
        capacity_used = p["jobs_today"] / max(p["capacity"], 1)
        cancellation_penalty = float(p["cancellation_rate"]) * 2
        f5 = capacity_used * 0.5 + cancellation_penalty * 0.5

        # Factor 6: Price (if low_budget, penalize high rates)
        rate_norm = float(p["hourly_rate"]) / 2000.0
        if intent.budget_sensitivity == "low_budget":
            f6 = rate_norm
        elif intent.budget_sensitivity == "flexible":
            f6 = 0.0
        else:
            f6 = rate_norm * 0.5

        score = 0.20*f1 + 0.20*f2 + 0.18*f3 + 0.15*f4 + 0.15*f5 + 0.12*f6
        return score, {"distance": f1, "reliability": f2, "rating": f3,
                       "specialization": f4, "availability": f5, "price": f6}

    def _build_reasoning(self, rank, p, dist, factors, intent, complexity):
        parts = []
        if rank == 0:
            parts.append("Best overall match")
        if dist < 3:
            parts.append(f"very close ({dist:.1f}km)")
        if float(p["on_time_score"]) >= 0.95:
            parts.append(f"{p['on_time_score']*100:.0f}% on-time reliability")
        if float(p["rating"]) >= 4.7:
            parts.append(f"top-rated ({p['rating']}★)")
        if p.get("recent_negative_reviews", 0) > 2:
            parts.append(f"⚠️ {p['recent_negative_reviews']} recent complaints")
        if COMPLEXITY_RANK.get(p.get("complexity_level","basic"),1) >= COMPLEXITY_RANK.get(complexity.level,2):
            parts.append(f"certified for {complexity.level} jobs")
        if float(p["cancellation_rate"]) > 0.10:
            parts.append(f"⚠️ {p['cancellation_rate']*100:.0f}% cancellation rate")
        return " | ".join(parts) if parts else "Meets all requirements"