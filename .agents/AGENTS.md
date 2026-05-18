# .agents/AGENTS.md 
 
# Khidmat AI — Antigravity Agent Orchestration 
 
## Project Overview 
An 8-agent agentic AI system for Pakistan's informal service economy. 
Built with Google Antigravity as the core orchestration platform. 
 
## Agent Roster 
 
| Agent | File | Responsibility | Tools | 
|-------|------|----------------|-------| 
| IntentParserAgent | agents/intent_parser.py | Multilingual NLP, confidence scoring | Gemini-2.5-flash 
Flash | 
| ComplexityClassifierAgent | agents/complexity_classifier.py | Job complexity: 
basic/intermediate/complex | Gemini 2.5 Flash | 
| ProviderMatcherAgent | agents/provider_matcher.py | 6-factor ranking algorithm | Supabase | 
| SchedulingAgent | agents/scheduling_agent.py | Conflict prevention, travel buffers | Supabase 
| 
| PricingAgent | agents/pricing_agent.py | Dynamic pricing with full breakdown | Rule engine + 
Gemini | 
| BookingAgent | agents/booking_agent.py | Booking simulation, notifications, receipt | 
Supabase | 
| ServiceQualityAgent | agents/service_quality_agent.py | Progress, feedback, reputation update 
| Supabase | 
| DisputeAgent | agents/dispute_agent.py | Dispute resolution state machine | Gemini + 
Supabase | 
 
## Orchestration Flow 
Request → IntentParser → ComplexityClassifier → ProviderMatcher → 
SchedulingAgent → PricingAgent → BookingAgent → ServiceQualityAgent 
                                                        ↓ 
                                                 DisputeAgent (if triggered) 
 
## Matching Algorithm (6 Factors) 
1. Distance / travel time (20%) 
2. On-time reliability score (20%) 
3. Rating + recency weight (18%) 
4. Skill specialization match (15%) 
5. Availability + cancellation rate (15%) 
6. Price vs user budget (12%) 
 
## Languages Supported - English - Roman Urdu (transliterated) - Urdu (Unicode) - Mixed / code-switched 
 
## Stress Test Scenarios 
See .agents/workflows/stress_tests.md 