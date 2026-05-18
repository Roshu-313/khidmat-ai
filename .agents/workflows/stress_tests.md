# .agents/workflows/stress_tests.md 
 
# Stress Test Scenarios for Demo 
 
## Scenario 1: No Provider Available 
Input: Service request for area with no providers 
Expected: Fallback triggered, error logged, suggestion to try nearby area 

## Scenario 2: Ambiguous Input 
Input: "kuch kaam karna hai" (very vague) 
Expected: Low confidence score, clarification question generated 

## Scenario 3: Budget Conflict 
Input: Very low budget with high urgency 
Expected: Budget alternative offered, trade-offs explained 

## Scenario 4: Emergency Request 
Input: "pipe burst emergency G-9 abhi chahiye" 
Expected: today_asap slot, emergency surcharge applied, fastest provider selected 

## Scenario 5: Provider Cancellation 
Trigger: /api/dispute with type "cancellation" 
Expected: DisputeAgent resolves, rebooking simulated, no penalty for user 

## How to Run in Demo 
Call: GET /api/stress-test/{scenario_name} 
Options: no_provider | ambiguous | budget | emergency | cancellation 