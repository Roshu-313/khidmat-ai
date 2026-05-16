# backend/agents/pricing_agent.py
import time
from datetime import date
from models.schemas import ParsedIntent, Provider, JobComplexity, PriceQuote

URGENCY_SURCHARGE = {"low": 0, "medium": 100, "high": 250, "emergency": 500}
COMPLEXITY_CHARGE = {"basic": 0, "intermediate": 200, "complex": 500}
DEMAND_BY_TIME = {
    "today_asap": 1.3, "today_morning": 1.2, "today_afternoon": 1.0,
    "today_evening": 1.1, "tomorrow_morning": 1.0, "tomorrow_afternoon": 0.9,
    "this_week": 0.85, "flexible": 0.85
}

class PricingAgent:
    def __init__(self, tracer):
        self.tracer = tracer

    async def generate_quote(self, provider: Provider, intent: ParsedIntent,
                             complexity: JobComplexity) -> PriceQuote:
        start = time.time()

        # Base rate from provider
        base_rate = provider.hourly_rate

        # Distance charge: PKR 20/km after first 3km
        dist_charge = max(0, int((provider.distance_km - 3) * 20)) if provider.distance_km > 3 else 0

        # Urgency surcharge
        urgency_charge = URGENCY_SURCHARGE.get(intent.urgency, 0)

        # Complexity charge
        complexity_charge = COMPLEXITY_CHARGE.get(complexity.level, 0)

        # Demand multiplier
        demand_mult = DEMAND_BY_TIME.get(intent.requested_time, 1.0)

        # Loyalty discount (simulated — new user = 0)
        loyalty_discount = 0

        # Total calculation
        subtotal = base_rate + dist_charge + urgency_charge + complexity_charge - loyalty_discount
        total = int(subtotal * demand_mult)

        # Budget-sensitive alternative (off-peak slot = 15% cheaper)
        budget_alt = None
        if intent.budget_sensitivity == "low_budget" and intent.urgency != "emergency":
            alt_total = int(total * 0.85)
            budget_alt = {
                "total": alt_total,
                "saving": total - alt_total,
                "condition": "Book 3 PM slot (lower demand period)",
                "slot": "03:00 PM Tomorrow"
            }

        # Fairness check
        fair_to_provider = total >= provider.hourly_rate * 0.8
        within_budget = intent.budget_sensitivity != "low_budget" or total <= 1200

        breakdown = (
            f"Base rate: PKR {base_rate}\n"
            f"Distance surcharge: +PKR {dist_charge}\n"
            f"Urgency adjustment: +PKR {urgency_charge}\n"
            f"Job complexity: +PKR {complexity_charge}\n"
            f"Demand multiplier: ×{demand_mult}\n"
            f"Loyalty discount: -PKR {loyalty_discount}\n"
            f"─────────────────────\n"
            f"TOTAL: PKR {total}"
        )

        result = PriceQuote(
            base_rate=base_rate, distance_charge=dist_charge,
            urgency_surcharge=urgency_charge, complexity_charge=complexity_charge,
            demand_multiplier=demand_mult, loyalty_discount=loyalty_discount,
            total_price=total, breakdown_text=breakdown,
            budget_alternative=budget_alt,
            is_fair_to_provider=fair_to_provider,
            is_within_budget=within_budget
        )

        self.tracer.log(
            agent_name="PricingAgent",
            input_data={"provider": provider.name, "urgency": intent.urgency,
                        "complexity": complexity.level, "budget_pref": intent.budget_sensitivity},
            output_data={"total": total, "breakdown": breakdown, "has_alternative": budget_alt is not None},
            reasoning=f"Calculated price for {complexity.level} {intent.service_type} job. "
                      f"Base PKR {base_rate} + distance PKR {dist_charge} + urgency PKR {urgency_charge} "
                      f"+ complexity PKR {complexity_charge}, demand ×{demand_mult}. "
                      f"{'Budget alternative offered at PKR ' + str(budget_alt['total']) if budget_alt else 'No budget alternative needed.'}",
            decision=f"Final quote: PKR {total}. "
                     f"{'Fair to provider: YES' if fair_to_provider else 'NOTE: At provider minimum rate.'}. "
                     f"{'Within user budget.' if within_budget else 'Over user budget — alternative suggested.'}",
            confidence=0.93,
            start_time=start
        )
        return result