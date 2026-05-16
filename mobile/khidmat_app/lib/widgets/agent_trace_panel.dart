// lib/widgets/agent_trace_panel.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class AgentTracePanel extends StatefulWidget {
  final List<Map<String, dynamic>> trace;
  const AgentTracePanel({super.key, required this.trace});
  @override State<AgentTracePanel> createState() => _AgentTracePanelState();
}

class _AgentTracePanelState extends State<AgentTracePanel> {
  bool _open = false;

  Color _color(String name) => switch (name) {
    'IntentParserAgent'         => Colors.purple,
    'ComplexityClassifierAgent' => Colors.orange,
    'ProviderMatcherAgent'      => Colors.blue,
    'SchedulingAgent'           => Colors.teal,
    'PricingAgent'              => Colors.green,
    'BookingAgent'              => Colors.indigo,
    'ServiceQualityAgent'       => Colors.pink,
    'DisputeAgent'              => Colors.red,
    _ => Colors.grey,
  };

  @override
  Widget build(BuildContext context) => Card(
    color: kDark,
    child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: Row(children: [
          const Text('🤖', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text('Agent Trace / Logs (${widget.trace.length} steps)',
            style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const Spacer(),
          Icon(_open ? Icons.expand_less : Icons.expand_more, color: Colors.white54),
        ]),
      ),
      if (_open) ...[
        const SizedBox(height: 12),
        ...widget.trace.map((log) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(
              color: _color(log['agent_name'] ?? ''), width: 3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _color(log['agent_name'] ?? '').withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4)),
                child: Text('Step ${log['step_number']}: ${log['agent_name']}',
                  style: GoogleFonts.firaCode(
                    color: _color(log['agent_name'] ?? ''), fontSize: 10))),
              const Spacer(),
              if (log['fallback_triggered'] == true)
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4)),
                  child: const Text('FALLBACK', style: TextStyle(
                    color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold))),
              const SizedBox(width: 6),
              Text('${log['execution_time_ms']}ms',
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ]),
            const SizedBox(height: 6),
            const Text('Reasoning:', style: TextStyle(color: Colors.white38, fontSize: 10)),
            Text(log['reasoning'] ?? '', style: GoogleFonts.firaCode(
              color: Colors.white70, fontSize: 10, height: 1.5)),
            const SizedBox(height: 4),
            const Text('Decision:', style: TextStyle(color: Colors.white38, fontSize: 10)),
            Text(log['decision'] ?? '', style: GoogleFonts.firaCode(
              color: Colors.greenAccent, fontSize: 10, height: 1.5)),
          ]),
        )),
      ],
    ])),
  );
}