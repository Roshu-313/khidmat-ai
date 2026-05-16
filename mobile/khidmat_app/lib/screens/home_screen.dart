// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/sse_service.dart';
import '../theme.dart';
import 'result_screen.dart';

const _kGlowTeal = Color(0xFF2DD4BF);
const _kGlowBlue = Color(0xFF38BDF8);
const _kAgents = <({String name, String subtitle})>[
  (name: 'IntentParserAgent', subtitle: 'Parsing your multilingual request...'),
  (
    name: 'ComplexityClassifierAgent',
    subtitle: 'Classifying job complexity...'
  ),
  (
    name: 'ProviderMatcherAgent',
    subtitle: 'Ranking providers with 6-factor algorithm...'
  ),
  (name: 'SchedulingAgent', subtitle: 'Checking availability & conflicts...'),
  (name: 'PricingAgent', subtitle: 'Calculating dynamic price quote...'),
  (name: 'BookingAgent', subtitle: 'Confirming booking & locking slot...'),
  (name: 'ServiceQualityAgent', subtitle: 'Setting up service tracking...'),
  (name: 'DisputeAgent', subtitle: 'Preparing dispute resolution system...'),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = TextEditingController();

  final _scrollController = ScrollController();

  bool _loading = false;

  String? _error;

  String _activeScenario = '';

  Timer? _simulationTimer;

  int _activeAgentIndex = 0;

  final List<String> _completedAgentNames = [];

  double _simulatedProgress = 0;

  bool _overlayExiting = false;

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

  @override
  void dispose() {
    _simulationTimer?.cancel();

    _ctrl.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  void _startAgentSimulation() {
    _simulationTimer?.cancel();

    _activeAgentIndex = 0;

    _completedAgentNames.clear();

    _simulatedProgress = 0;

    _overlayExiting = false;

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;

      setState(() {
        if (_activeAgentIndex < _kAgents.length) {
          _completedAgentNames.add(_kAgents[_activeAgentIndex].name);

          _activeAgentIndex++;

          _simulatedProgress =
              (_completedAgentNames.length / _kAgents.length) * 100;
        }

        if (_completedAgentNames.length >= _kAgents.length) {
          _simulationTimer?.cancel();
        }
      });
    });
  }

  void _stopAgentSimulation() {
    _simulationTimer?.cancel();

    _simulationTimer = null;
  }

  Future<void> _finishAndNavigate(Map<String, dynamic> result) async {
    _stopAgentSimulation();

    while (_completedAgentNames.length < _kAgents.length) {
      if (!mounted) return;

      setState(() {
        if (_activeAgentIndex < _kAgents.length) {
          _completedAgentNames.add(_kAgents[_activeAgentIndex].name);

          _activeAgentIndex++;
        }

        _simulatedProgress =
            (_completedAgentNames.length / _kAgents.length) * 100;
      });

      await Future.delayed(const Duration(milliseconds: 80));
    }

    if (!mounted) return;

    setState(() {
      _simulatedProgress = 100;

      _overlayExiting = true;
    });

    await Future.delayed(const Duration(milliseconds: 480));

    if (!mounted) return;

    setState(() {
      _loading = false;

      _overlayExiting = false;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
    );
  }

  Future<void> _submit({String? stressScenario}) async {
    final input = _ctrl.text.trim();

    if (input.isEmpty && stressScenario == null) return;

    setState(() {
      _loading = true;

      _error = null;

      _activeScenario = stressScenario ?? '';
    });

    _startAgentSimulation();

    try {
      Map<String, dynamic>? result;

      if (stressScenario != null) {
        result = await ApiService.stressTest(stressScenario);
      } else {
        Map<String, dynamic>? finalResult;

        await for (final event in SseService.processRequest(input)) {
          if (!mounted) return;

          final type = event['type'] as String?;

          final data = event['data'];

          if (type == 'agent_start' && data is Map<String, dynamic>) {
            // Visual progress handled by simulated agent overlay
          } else if (type == 'agent_done' && data is Map<String, dynamic>) {
            // Visual progress handled by simulated agent overlay
          } else if (type == 'complete' && data is Map<String, dynamic>) {
            finalResult = Map<String, dynamic>.from(data);
          } else if (type == 'error' && data is Map<String, dynamic>) {
            throw Exception(data['message'] ?? 'Stream error');
          }
        }

        result = finalResult;

        if (result == null) {
          throw Exception(
              'Stream ended without a result. Is the backend running at $baseUrl?');
        }
      }

      if (!mounted) return;

      await _finishAndNavigate(result);
    } catch (e) {
      _stopAgentSimulation();

      if (mounted) {
        setState(() {
          _error = e.toString();

          _loading = false;

          _overlayExiting = false;

          _activeAgentIndex = 0;

          _completedAgentNames.clear();

          _simulatedProgress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final runningAgent = _activeAgentIndex < _kAgents.length
        ? _kAgents[_activeAgentIndex]
        : null;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kPrimary, kSecondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text('🏠', style: TextStyle(fontSize: 32)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Khidmat AI',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'خدمت — Agentic Service Orchestrator',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          _statChip('8 Agents'),
                          const SizedBox(width: 8),
                          _statChip('6-Factor Match'),
                          const SizedBox(width: 8),
                          _statChip('3 Languages'),
                        ]),
                      ],
                    ),
                  ).animate().fadeIn(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'What service do you need?',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const Text(
                                  'Urdu / Roman Urdu / English supported',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _ctrl,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText:
                                        '"AC bilkul kaam nahi kar raha, kal subah G-13..."',
                                    hintStyle: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: kBackground,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: _examples
                                      .map(
                                        (e) => ActionChip(
                                          label: Text(
                                            e.length > 35
                                                ? '${e.substring(0, 35)}…'
                                                : e,
                                            style:
                                                const TextStyle(fontSize: 10),
                                          ),
                                          onPressed: () =>
                                              setState(() => _ctrl.text = e),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _loading ? null : () => _submit(),
                                    icon: _loading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.auto_awesome),
                                    label: Text(_loading
                                        ? 'Running agents…'
                                        : 'Find & Book Service'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kPrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 100.ms),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Text('🧪',
                                      style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Stress Test Scenarios',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 4),
                                const Text(
                                  'Demo edge cases & fallback behavior',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _stressTests
                                      .map(
                                        (t) => ElevatedButton(
                                          onPressed: _loading
                                              ? null
                                              : () => _submit(
                                                    stressScenario: t.$2,
                                                  ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                _activeScenario == t.$2
                                                    ? kPrimary
                                                    : Colors.grey.shade100,
                                            foregroundColor:
                                                _activeScenario == t.$2
                                                    ? Colors.white
                                                    : Colors.black87,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text(
                                            t.$1,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                        if (_error != null)
                          Card(
                            color: Colors.red.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '⚠️ Error / Fallback Triggered',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
          if (_loading)
            _AgentLoadingOverlay(
              exiting: _overlayExiting,
              progress: _simulatedProgress,
              runningAgent: runningAgent,
              completedAgents: _completedAgentNames,
            ),
        ],
      ),
    );
  }

  Widget _statChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      );
}

class _AgentLoadingOverlay extends StatelessWidget {
  final bool exiting;

  final double progress;

  final ({String name, String subtitle})? runningAgent;

  final List<String> completedAgents;

  const _AgentLoadingOverlay({
    required this.exiting,
    required this.progress,
    required this.runningAgent,
    required this.completedAgents,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: exiting ? 0 : 1,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInCubic,
        child: AnimatedScale(
          scale: exiting ? 0.88 : 1,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeInCubic,
          child: Material(
            color: Colors.black.withValues(alpha: 0.85),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    _buildRobot(),
                    const SizedBox(height: 28),
                    _buildCircularProgress(),
                    const SizedBox(height: 32),
                    _buildActiveAgent(),
                    const SizedBox(height: 20),
                    Expanded(child: _buildCompletedLog()),
                    _buildBottomProgress(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRobot() => Text(
        '🤖',
        style: TextStyle(
          fontSize: 88,
          shadows: [
            Shadow(
              color: _kGlowTeal.withValues(alpha: 0.9),
              blurRadius: 28,
            ),
            Shadow(
              color: _kGlowBlue.withValues(alpha: 0.7),
              blurRadius: 48,
            ),
          ],
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(0.94, 0.94),
            end: const Offset(1.06, 1.06),
            duration: 1400.ms,
            curve: Curves.easeInOut,
          )
          .shimmer(
            duration: 2200.ms,
            color: _kGlowBlue.withValues(alpha: 0.45),
          );

  Widget _buildCircularProgress() => Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _kGlowTeal.withValues(alpha: 0.55),
              blurRadius: 24,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: _kGlowBlue.withValues(alpha: 0.35),
              blurRadius: 36,
              spreadRadius: 4,
            ),
          ],
        ),
        child: SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 5,
            color: _kGlowTeal,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ).animate(onPlay: (c) => c.repeat()).shimmer(
            duration: 1800.ms,
            color: _kGlowBlue.withValues(alpha: 0.35),
          );

  Widget _buildActiveAgent() {
    if (runningAgent == null) {
      return Text(
        'Pipeline complete',
        style: GoogleFonts.poppins(
          color: kAccent,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.2, end: 0, duration: 300.ms);
    }

    final agent = runningAgent!;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(agent.name),
        children: [
          Text(
            'Running: ${agent.name}',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: _kGlowTeal.withValues(alpha: 0.6),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            agent.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: _kGlowBlue.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedLog() {
    if (completedAgents.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: completedAgents.length,
      itemBuilder: (context, index) {
        final name = completedAgents[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: kAccent.withValues(alpha: 0.95),
                size: 18,
                shadows: [
                  Shadow(
                    color: kAccent.withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.poppins(
                    color: kAccent.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ).animate(key: ValueKey(name)).fadeIn(duration: 280.ms).slideX(
            begin: -0.08, end: 0, duration: 280.ms, curve: Curves.easeOut);
      },
    );
  }

  Widget _buildBottomProgress() {
    final pct = progress.clamp(0, 100).round();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Agent pipeline',
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$pct%',
              style: GoogleFonts.poppins(
                color: _kGlowTeal,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(
                    color: _kGlowTeal.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: _kGlowTeal.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress / 100),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                color: _kGlowTeal,
              ),
            ),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(
              duration: 1600.ms,
              color: _kGlowBlue.withValues(alpha: 0.4),
            ),
      ],
    );
  }
}
