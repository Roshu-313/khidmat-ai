// lib/screens/home_screen.dart — UPDATED
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/live_agent_pipeline.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = false;
  bool _showPipeline = false;
  String? _error;
  String _activeScenario = '';
  late List<AgentStep> _agentSteps = _createAgentSteps();

  final _examples = [
    "AC bilkul kaam nahi kar raha, kal subah G-13 mein technician chahiye, budget zyada nahi hai",
    "I need a plumber urgently, pipe burst in F-10",
    "Bijli ka kaam karna hai G-9 mein kal afternoon",
    "Mujhe maths tutor chahiye G-11 mein tomorrow",
  ];

  final _stressTests = [
    ("🚫 No Provider", "no_provider"),
    ("❓ Ambiguous Input", "ambiguous"),
    ("💰 Tight Budget", "budget"),
    ("🚨 Emergency", "emergency"),
  ];

  static List<AgentStep> _createAgentSteps() => [
    AgentStep(agentName: 'IntentParserAgent', message: 'Waiting...'),
    AgentStep(agentName: 'ComplexityClassifierAgent', message: 'Waiting...'),
    AgentStep(agentName: 'ProviderMatcherAgent', message: 'Waiting...'),
    AgentStep(agentName: 'SchedulingAgent', message: 'Waiting...'),
    AgentStep(agentName: 'PricingAgent', message: 'Waiting...'),
    AgentStep(agentName: 'BookingAgent', message: 'Waiting...'),
  ];

  void _resetAgentSteps() {
    _agentSteps = _createAgentSteps();
  }

  AgentStep? _findStep(String agentName) {
    for (final step in _agentSteps) {
      if (step.agentName == agentName) return step;
    }
    return null;
  }

  void _applyAgentResult(AgentStep step, dynamic result) {
    step.result = result;
  }

  Future<void> _processWithStream(String input) async {
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('${ApiService.apiBaseUrl}/api/process-stream'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = jsonEncode({
        'user_input': input,
        'user_name': 'Guest',
      });

      final streamed = await client.send(request);
      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        throw Exception('Error ${streamed.statusCode}: $body');
      }

      var buffer = '';
      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final events = buffer.split('\n\n');
        buffer = events.removeLast();

        for (final event in events) {
          for (final line in event.split('\n')) {
            if (!line.startsWith('data: ')) continue;
            final payload = jsonDecode(line.substring(6)) as Map<String, dynamic>;
            final type = payload['type'] as String?;
            final data = payload['data'];

            if (type == 'agent_start' && data is Map) {
              final agent = data['agent'] as String?;
              final step = agent != null ? _findStep(agent) : null;
              if (step != null) {
                setState(() {
                  step.status = AgentStatus.running;
                  step.stepMessage =
                      data['message'] as String? ?? 'Running...';
                });
              }
            } else if (type == 'agent_done' && data is Map) {
              final agent = data['agent'] as String?;
              final step = agent != null ? _findStep(agent) : null;
              if (step != null) {
                setState(() {
                  step.status = AgentStatus.done;
                  step.stepMessage = 'Complete';
                  _applyAgentResult(step, data['result']);
                });
              }
            } else if (type == 'complete' && data is Map) {
              if (!mounted) return;
              final result = Map<String, dynamic>.from(
                Map<dynamic, dynamic>.from(data),
              );
              setState(() {
                _loading = false;
                _showPipeline = false;
              });
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ResultScreen(result: result),
                ),
              );
              return;
            } else if (type == 'error' && data is Map) {
              throw Exception(data['message']?.toString() ?? 'Stream failed');
            }
          }
        }
      }
    } finally {
      client.close();
    }
  }

  Future<void> _submit({String? stressScenario}) async {
    final input = _ctrl.text.trim();
    if (input.isEmpty && stressScenario == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _activeScenario = stressScenario ?? '';
      _showPipeline = stressScenario == null;
      if (stressScenario == null) _resetAgentSteps();
    });

    try {
      if (stressScenario != null) {
        final result = await ApiService.stressTest(stressScenario);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
        );
      } else {
        await _processWithStream(input);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _showPipeline = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(children: [
              // Hero Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimary, kSecondary],
                    begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('🏠', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Khidmat AI', style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      Text(
                        'خدمت — Agentic Service Orchestrator',
                        style: GoogleFonts.notoSansArabic(
                          textStyle: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    _statChip('8 Agents'),
                    const SizedBox(width: 8),
                    _statChip('6-Factor Match'),
                    const SizedBox(width: 8),
                    _statChip('3 Languages'),
                  ]),
                ]),
              ).animate().fadeIn(),

              Padding(padding: const EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showPipeline) ...[
                    LiveAgentPipeline(steps: _agentSteps),
                    const SizedBox(height: 16),
                  ],

                  // Input
                  Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What service do you need?', style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 16)),
                      const Text('Urdu / Roman Urdu / English supported',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ctrl, maxLines: 3,
                        decoration: InputDecoration(
                          hintText: '"AC bilkul kaam nahi kar raha, kal subah G-13..."',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true, fillColor: kBackground,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 4,
                        children: _examples.map((e) => ActionChip(
                          label: Text(e.length > 35 ? '${e.substring(0,35)}…' : e,
                            style: const TextStyle(fontSize: 10)),
                          onPressed: _loading ? null : () => setState(() => _ctrl.text = e),
                        )).toList()),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : () => _submit(),
                          icon: _loading
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome),
                          label: Text(_loading ? 'Running 8 Agents...' : 'Find & Book Service'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        )),
                    ],
                  ))).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 16),

                  Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('🧪', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text('Stress Test Scenarios', style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                      ]),
                      const SizedBox(height: 4),
                      const Text('Demo edge cases & fallback behavior',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8,
                        children: _stressTests.map((t) => ElevatedButton(
                          onPressed: _loading ? null : () => _submit(stressScenario: t.$2),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _activeScenario == t.$2
                              ? kPrimary : Colors.grey.shade100,
                            foregroundColor: _activeScenario == t.$2
                              ? Colors.white : Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(t.$1, style: const TextStyle(fontSize: 12)),
                        )).toList()),
                    ],
                  ))).animate().fadeIn(delay: 200.ms),

                  if (_error != null)
                    Card(color: Colors.red.shade50, child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('⚠️ Error / Fallback Triggered',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(height: 4),
                        Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                      ]),
                    )),
                ],
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _statChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
  );
}
