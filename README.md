---
title: Khidmat AI
emoji: 🚀
colorFrom: blue
colorTo: green
sdk: docker
pinned: false
---

# Khidmat AI v2.0 🏠
### AISeekho2026 Antigravity Hackathon | Challenge 2: AI Service Orchestrator
> خدمت — A fully agentic service orchestrator that takes a messy real-world request in Urdu/Roman Urdu/English and autonomously handles matching, pricing, booking, follow-up, and dispute resolution end to end.

---

## 🏗️ Architecture

```
FLUTTER APP (Chrome/Mobile)
        ↓ HTTP REST
FASTAPI BACKEND
        ↓
AGENT ORCHESTRATOR
  1. IntentParserAgent      → Gemini 2.5 Flash
  2. ComplexityClassifier   → Gemini 2.5 Flash
  3. ProviderMatcherAgent   → Supabase + 6-factor scoring
  4. SchedulingAgent        → Supabase + conflict check
  5. PricingAgent           → Rule engine + Gemini
  6. BookingAgent           → Supabase write
  7. ServiceQualityAgent    → Supabase write
  8. DisputeAgent           → State machine + Gemini
        ↓
SUPABASE (providers, bookings, schedules, reviews, disputes, agent_logs)
```

---

## 🤖 Agent Pipeline

```
Request → IntentParser → ComplexityClassifier → ProviderMatcher →
SchedulingAgent → PricingAgent → BookingAgent → ServiceQualityAgent
                                                        ↓
                                               DisputeAgent (if triggered)
```

---

## 📊 Provider Matching — 6 Factors

```
SCORE = (
  0.20 × distance_score       # travel time from provider to job
  0.20 × reliability_score    # on-time % from past jobs
  0.18 × rating_score         # avg rating × recency weight
  0.15 × specialization_score # skill match to job complexity
  0.15 × availability_score   # slot open + buffer respected
  0.12 × price_score          # competitive rate vs user budget
)
```

---

## ⚡ Google Antigravity Usage

- **Development**: Antigravity IDE used as primary editor
- **Orchestration**: Agent Manager used to build and coordinate all 8 agents
- **Workflows**: `.agents/` folder with `AGENTS.md` and workflow files
- **Traces**: All agent reasoning logged to Supabase `agent_logs` table
- **Evidence**: Screenshots of Agent Manager tasks available in `/antigravity-screenshots/`

---

## 🌐 Languages Supported

| Language | Example |
|----------|---------|
| Roman Urdu | "AC bilkul kaam nahi kar raha, kal subah chahiye" |
| Urdu | "مجھے کل صبح G-13 میں ٹیکنیشن چاہیے" |
| English | "I need a plumber urgently in F-10" |
| Mixed | "Mujhe urgent electrician chahiye in G-9" |

---

## 🧪 Stress Tests Demonstrated

| Scenario | Input | Expected |
|----------|-------|----------|
| No provider | Unknown area | Fallback + suggestion |
| Ambiguous input | "kuch kaam karna hai" | Clarification question |
| Tight budget | Very low budget + high urgency | Alternative quote offered |
| Emergency | "pipe burst abhi chahiye" | Surge pricing + fastest slot |
| Dispute | Provider no-show | Auto-resolution by DisputeAgent |

---

## 🛠️ Stack (100% Free)

| Layer | Technology |
|-------|-----------|
| Mobile/Web | Flutter 3.41 |
| Backend | FastAPI + Python |
| Database | Supabase (free tier) |
| AI Model | Gemini 2.5 Flash via Vertex AI |
| IDE | Google Antigravity |
| Hosting | Railway (free tier) |

---

## 📈 Baseline Comparison

| Feature | Non-Agentic | Khidmat AI |
|---------|------------|------------|
| Matching factors | 1 (distance only) | 6 factors |
| Pricing | Fixed flat rate | Dynamic (demand + urgency + complexity) |
| Languages | English only | Urdu + Roman Urdu + English + Mixed |
| Dispute handling | None | Full resolution workflow |
| Complexity check | None | Auto-classify (basic/intermediate/complex) |
| Conflict prevention | None | Schedule lock with travel buffer |
| Reasoning | None | Full agent trace logged to DB |

---

## 🚀 Running Locally

### Backend
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
# API docs at http://localhost:8000/docs
```

### Flutter App
```bash
cd mobile/khidmat_app
flutter pub get
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

### Environment Variables
```
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_anon_key
GOOGLE_CLOUD_PROJECT=gen-lang-client-0765654837
```

---

## 📡 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/process-request` | Full 8-agent orchestration |
| POST | `/api/dispute` | Raise a dispute |
| POST | `/api/submit-feedback` | Rate a service |
| GET | `/api/providers` | List all providers |
| GET | `/api/bookings` | List all bookings |
| GET | `/api/agent-trace/{id}` | View agent reasoning logs |
| GET | `/api/stress-test/{scenario}` | Run demo edge cases |

---

## 💰 Cost Per Operation

- Gemini 2.5 Flash via Vertex AI: ~$0.002 per request
- Supabase free tier: 500MB, ~50k requests/month
- Total cost for hackathon demo: ~$0.00 (covered by $298 credits)

---

## 📏 Scalability

- **10x**: Railway hobby plan handles ~1000 req/day
- **100x**: Add Redis queue + multiple FastAPI workers
- **1000x**: Kubernetes + load balancer + Supabase Pro

---

## 🔒 Privacy Note

All provider data is mock/synthetic. No real personal data used. User names are optional. Phone numbers are not stored or shared externally.

---

## ⚠️ Limitations

- SMS/WhatsApp notifications are simulated
- Photo evidence is a placeholder
- Pricing is rule-based (not ML)
- Provider data is mock (16 providers, Islamabad only)

---

## 👨‍💻 Built By

**Roshan Faisal** 
AISeekho2026 | Google Antigravity Hackathon | Challenge 2
Built in 7 days | May 14–20, 2026

*In collaboration with Google for Developers, Telenor Pakistan & Ministry of IT & Telecom*