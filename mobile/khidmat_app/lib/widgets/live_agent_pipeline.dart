// lib/widgets/live_agent_pipeline.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class LiveAgentPipeline extends StatelessWidget {
  final List<AgentStep> steps;

  const LiveAgentPipeline({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('🤖', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('Agent Pipeline',
                style: GoogleFonts.firaCode(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
            ]),
            const SizedBox(height: 16),
            ...steps.asMap().entries.map((e) =>
              _AgentStepTile(step: e.value, index: e.key)
                .animate()
                .fadeIn(duration: 300.ms)
                .slideX(begin: -0.1)),
          ],
        ),
      ),
    );
  }
}

class _AgentStepTile extends StatelessWidget {
  final AgentStep step;
  final int index;

  const _AgentStepTile({required this.step, required this.index});

  Color get _agentColor => switch (step.agentName) {
    'IntentParserAgent'         => Colors.purple,
    'ComplexityClassifierAgent' => Colors.orange,
    'ProviderMatcherAgent'      => Colors.blue,
    'SchedulingAgent'           => Colors.teal,
    'PricingAgent'              => Colors.green,
    'BookingAgent'              => Colors.indigo,
    _                           => Colors.grey,
  };

  String get _agentEmoji => switch (step.agentName) {
    'IntentParserAgent'         => '🧠',
    'ComplexityClassifierAgent' => '⚙️',
    'ProviderMatcherAgent'      => '📍',
    'SchedulingAgent'           => '📅',
    'PricingAgent'              => '💰',
    'BookingAgent'              => '✅',
    _                           => '🤖',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + icon
          Column(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: step.status == AgentStatus.done
                  ? _agentColor
                  : step.status == AgentStatus.running
                    ? _agentColor.withValues(alpha: 0.3)
                    : Colors.white12,
                border: Border.all(
                  color: step.status == AgentStatus.pending
                    ? Colors.white24 : _agentColor,
                  width: 1.5)),
              child: Center(child: step.status == AgentStatus.running
                ? SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: _agentColor))
                : step.status == AgentStatus.done
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(_agentEmoji, style: const TextStyle(fontSize: 14))),
            ),
            if (index < 5) // connector line
              Container(width: 2, height: 20,
                color: step.status == AgentStatus.done
                  ? _agentColor.withValues(alpha: 0.5) : Colors.white12),
          ]),
          const SizedBox(width: 12),

          // Content
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(step.agentName.replaceAll('Agent', ''),
                  style: GoogleFonts.firaCode(
                    color: step.status == AgentStatus.pending
                      ? Colors.white38 : _agentColor,
                    fontSize: 12, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (step.durationMs != null)
                  Text('${step.durationMs}ms',
                    style: const TextStyle(
                      color: Colors.white38, fontSize: 10)),
                if (step.status == AgentStatus.running)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _agentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4)),
                    child: Text('RUNNING',
                      style: TextStyle(
                        color: _agentColor, fontSize: 9,
                        fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 2),
              Text(step.message,
                style: TextStyle(
                  color: step.status == AgentStatus.pending
                    ? Colors.white24 : Colors.white60,
                  fontSize: 11)),
              if (step.result != null && step.status == AgentStatus.done)
                ..._buildResult(step),
            ],
          )),
        ],
      ),
    );
  }

  List<Widget> _buildResult(AgentStep step) {
    final result = step.result!;
    String summary = '';

    switch (step.agentName) {
      case 'IntentParserAgent':
        summary = '${result['service_type']} · ${result['location']} · '
                  '${result['urgency']} urgency · '
                  '${((result['confidence'] ?? 0.9) * 100).toInt()}% confidence';
        break;
      case 'ComplexityClassifierAgent':
        summary = '${result['level']?.toString().toUpperCase()} job · '
                  '~${result['estimated_duration_hours']}hrs';
        break;
      case 'ProviderMatcherAgent':
        final providers = result as List?;
        summary = providers != null && providers.isNotEmpty
          ? '${providers[0]['name']} selected · '
            '${providers[0]['distance_km']}km · '
            '${providers[0]['rating']}★'
          : 'No providers found';
        break;
      case 'SchedulingAgent':
        summary = '${result['date']} at ${result['time']} · '
                  '${result['travel_buffer_minutes']}min buffer';
        break;
      case 'PricingAgent':
        summary = 'PKR ${result['total_price']} · '
                  '×${result['demand_multiplier']} demand';
        break;
      case 'BookingAgent':
        summary = '${result['booking_code']} CONFIRMED ✓';
        break;
    }

    return [
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6)),
        child: Text(summary,
          style: GoogleFonts.firaCode(
            color: Colors.white70, fontSize: 10)),
      ),
    ];
  }
}

// Data model
enum AgentStatus { pending, running, done, error }

class AgentStep {
  final String agentName;
  final String message;
  AgentStatus status;
  Map<String, dynamic>? result;
  int? durationMs;

  AgentStep({
    required this.agentName,
    required this.message,
    this.status = AgentStatus.pending,
    this.result,
    this.durationMs,
  });
}