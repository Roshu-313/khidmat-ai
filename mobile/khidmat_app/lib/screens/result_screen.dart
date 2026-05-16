// lib/screens/result_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../widgets/agent_trace_panel.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  const ResultScreen({super.key, required this.result});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  static const _stepDelay = Duration(milliseconds: 300);
  static const _entranceDuration = Duration(milliseconds: 450);
  static const _pipelineCardCount = 9;

  bool _showDispute = false;
  bool _submitted = false;
  final _disputeCtrl = TextEditingController();
  final _scrollController = ScrollController();
  String _disputeType = 'quality_complaint';

  int _revealedIndex = -1;
  int _checkedIndex = -1;
  bool _pipelineComplete = false;
  bool _disputeVisible = false;
  double _progress = 0;

  Map get intent => widget.result['parsed_intent'] ?? {};
  Map get complexity => widget.result['job_complexity'] ?? {};
  List get providers => widget.result['matched_providers'] ?? [];
  Map get selected => widget.result['selected_provider'] ?? {};
  Map get schedule => widget.result['schedule'] ?? {};
  Map get price => widget.result['price_quote'] ?? {};
  Map get booking => widget.result['booking'] ?? {};
  Map get followUp => widget.result['follow_up'] ?? {};
  List get trace => widget.result['agent_trace'] ?? [];
  Map get baseline => widget.result['baseline_comparison'] ?? {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPipelineSequence());
  }

  Future<void> _runPipelineSequence() async {
    for (var i = 0; i < _pipelineCardCount; i++) {
      if (!mounted) return;
      setState(() {
        _revealedIndex = i;
        _progress = (i + 1) / _pipelineCardCount;
      });
      await Future.delayed(_entranceDuration);
      if (!mounted) return;
      setState(() => _checkedIndex = i);
      if (i < _pipelineCardCount - 1) {
        await Future.delayed(_stepDelay);
      }
    }
    if (!mounted) return;
    setState(() {
      _pipelineComplete = true;
      _progress = 1;
      _disputeVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Result', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: kPrimary, foregroundColor: Colors.white,
        actions: [
          Padding(padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('Session: ${widget.result['session_id'] ?? ''}',
              style: const TextStyle(fontSize: 11, color: Colors.white70)))),
        ],
      ),
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _buildProgressBar(),
            const SizedBox(height: 14),
            _buildPipelineHeader(),
            const SizedBox(height: 16),
            _wrapPipelineCard(0, _intentCard()),
            const SizedBox(height: 12),
            _wrapPipelineCard(1, _complexityCard()),
            const SizedBox(height: 12),
            _wrapPipelineCard(2, _providerRankingCard()),
            const SizedBox(height: 12),
            _wrapPipelineCard(3, _priceCard()),
            const SizedBox(height: 12),
            _wrapPipelineCard(4, _bookingCard()),
            const SizedBox(height: 12),
            _wrapPipelineCard(5, _followUpCard()),
            const SizedBox(height: 12),
            _wrapPipelineCard(6, _serviceTrackerCard()),
            const SizedBox(height: 12),
            _wrapPipelineCard(7, _baselineCard()),
            const SizedBox(height: 12),
            _wrapPipelineCard(8, AgentTracePanel(trace: List<Map<String,dynamic>>.from(trace))),
            const SizedBox(height: 12),
            if (_disputeVisible)
              _disputeSection()
                .animate()
                .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                .slideY(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  Widget _buildProgressBar() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 4,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _progress),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => Stack(
              children: [
                Container(color: Colors.grey.shade200),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _pipelineComplete
                          ? [kAccent, kAccent.withValues(alpha: 0.75)]
                          : [kSecondary, kPrimary],
                      ),
                    ),
                  ).animate(target: _pipelineComplete ? 1 : 0)
                    .shimmer(
                      duration: _pipelineComplete ? 0.ms : 1200.ms,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          '${(_progress * 100).round()}%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _pipelineComplete ? kAccent : kSecondary,
          ),
        ),
      ),
    ],
  );

  Widget _buildPipelineHeader() {
    final running = !_pipelineComplete;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(running),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: running
              ? [kPrimary.withValues(alpha: 0.12), kSecondary.withValues(alpha: 0.08)]
              : [kAccent.withValues(alpha: 0.15), kAccent.withValues(alpha: 0.05)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: running
              ? kPrimary.withValues(alpha: 0.25)
              : kAccent.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Text(
              running ? '🤖' : '✅',
              style: const TextStyle(fontSize: 22),
            )
              .animate(onPlay: running ? (c) => c.repeat(reverse: true) : null)
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.08, 1.08),
                duration: 900.ms,
                curve: Curves.easeInOut,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                running ? 'Running Agent Pipeline...' : 'Booking Complete!',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: running ? kPrimary : kAccent,
                ),
              ),
            ),
            if (running)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kSecondary.withValues(alpha: 0.8),
                ),
              )
                .animate(onPlay: (c) => c.repeat())
                .rotate(duration: 1000.ms),
          ],
        ),
      ),
    );
  }

  Widget _wrapPipelineCard(int index, Widget child) {
    if (index > _revealedIndex) return const SizedBox.shrink();

    final checked = index <= _checkedIndex;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child
          .animate(key: ValueKey('card-$index'))
          .fadeIn(duration: _entranceDuration.inMilliseconds.ms, curve: Curves.easeOut)
          .slideY(
            begin: 0.18,
            end: 0,
            duration: _entranceDuration.inMilliseconds.ms,
            curve: Curves.easeOutCubic,
          ),
        if (checked)
          Positioned(
            top: -6,
            right: -6,
            child: _completionCheck(),
          ),
      ],
    );
  }

  Widget _completionCheck() => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: kAccent,
      boxShadow: [
        BoxShadow(
          color: kAccent.withValues(alpha: 0.55),
          blurRadius: 14,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: kAccent.withValues(alpha: 0.25),
          blurRadius: 24,
          spreadRadius: 4,
        ),
      ],
    ),
    child: const Icon(Icons.check, size: 16, color: Colors.white),
  )
    .animate(key: const ValueKey('check-pop'))
    .fadeIn(duration: 200.ms)
    .scale(
      begin: const Offset(0.4, 0.4),
      end: const Offset(1, 1),
      duration: 350.ms,
      curve: Curves.elasticOut,
    )
    .then()
    .animate(onPlay: (c) => c.repeat(reverse: true))
    .scale(
      begin: const Offset(1, 1),
      end: const Offset(1.12, 1.12),
      duration: 700.ms,
      curve: Curves.easeInOut,
    )
    .boxShadow(
      begin: BoxShadow(
        color: kAccent.withValues(alpha: 0.4),
        blurRadius: 8,
        spreadRadius: 0,
      ),
      end: BoxShadow(
        color: kAccent.withValues(alpha: 0.75),
        blurRadius: 18,
        spreadRadius: 3,
      ),
      duration: 700.ms,
    );

  Widget _intentCard() => _card(
    icon: '🧠', title: 'Intent Extracted',
    badge: '${((intent['confidence'] ?? 0.9) * 100).toInt()}% confident',
    badgeColor: (intent['confidence'] ?? 0.9) >= 0.8 ? kAccent : kWarning,
    child: Column(children: [
      _row('Service', intent['service_type'] ?? ''),
      _row('Location', intent['location'] ?? ''),
      _row('Time', (intent['requested_time'] ?? '').toString().replaceAll('_', ' ')),
      _row('Urgency', intent['urgency'] ?? ''),
      _row('Budget', intent['budget_sensitivity'] ?? ''),
      _row('Language', intent['detected_language'] ?? ''),
      if (intent['needs_clarification'] == true)
        Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: kWarning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8)),
          child: Text('❓ ${intent['clarification_question']}',
            style: TextStyle(color: Colors.orange.shade800, fontSize: 12))),
    ]),
  );

  Widget _complexityCard() => _card(
    icon: '⚙️', title: 'Job Complexity',
    badge: (complexity['level'] ?? '').toString().toUpperCase(),
    badgeColor: complexity['level'] == 'complex' ? kDanger
      : complexity['level'] == 'intermediate' ? kWarning : kAccent,
    child: Column(children: [
      _row('Level', complexity['level'] ?? ''),
      _row('Est. Duration', '${complexity['estimated_duration_hours'] ?? '?'} hours'),
      _row('Reasoning', complexity['reasoning'] ?? ''),
    ]),
  );

  Widget _providerRankingCard() => _card(
    icon: '📍', title: 'Provider Ranking (6-Factor)',
    badge: '${providers.length} found',
    badgeColor: kSecondary,
    child: Column(
      children: providers.asMap().entries.map((e) {
        final i = e.key; final p = e.value as Map;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: i == 0 ? kPrimary.withValues(alpha: 0.07) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: i == 0 ? Border.all(color: kPrimary, width: 1.5) : null),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(i == 0 ? '🥇 ' : '${i+1}. ', style: const TextStyle(fontSize: 14)),
              Expanded(child: Text(p['name'] ?? '', style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 13,
                color: i == 0 ? kPrimary : Colors.black87))),
              Text('Score: ${p['composite_score']?.toStringAsFixed(4) ?? '?'}',
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: [
              _chip('${p['distance_km']}km', Icons.location_on),
              _chip('${p['rating']}★', Icons.star),
              _chip('${((p['on_time_score'] ?? 0) * 100).toInt()}% on-time', Icons.timer),
              _chip(p['complexity_level'] ?? '', Icons.build),
            ]),
            if (p['selection_reasoning'] != null) ...[
              const SizedBox(height: 4),
              Text(p['selection_reasoning'], style: TextStyle(
                fontSize: 11, color: Colors.blue.shade700, fontStyle: FontStyle.italic)),
            ],
          ]),
        );
      }).toList(),
    ),
  );

  Widget _priceCard() => _card(
    icon: '💰', title: 'Dynamic Price Quote',
    badge: 'PKR ${price['total_price'] ?? '?'}',
    badgeColor: price['is_within_budget'] == true ? kAccent : kWarning,
    child: Column(children: [
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200)),
        child: Text(price['breakdown_text'] ?? '',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.6))),
      if (price['budget_alternative'] != null) ...[
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kAccent.withValues(alpha: 0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('💡 Budget Alternative', style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: kAccent)),
            Text('PKR ${price['budget_alternative']['total']} (Save PKR ${price['budget_alternative']['saving']})',
              style: const TextStyle(fontSize: 12)),
            Text(price['budget_alternative']['condition'],
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ])),
      ],
    ]),
  );

  Widget _bookingCard() {
    final bk = booking['booking_code'] ?? '';
    final pv = booking['provider'] ?? selected;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kPrimary, kSecondary],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('✅', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Text('Booking Confirmed', style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        _wRow('Booking Code', bk),
        _wRow('Provider', pv['name'] ?? ''),
        _wRow('Date', schedule['date'] ?? ''),
        _wRow('Time', schedule['time'] ?? ''),
        _wRow('Duration est.', '${complexity['estimated_duration_hours']}hrs'),
        _wRow('Total', 'PKR ${price['total_price']}'),
        _wRow('Job Type', complexity['level']?.toString().toUpperCase() ?? ''),
      ]),
    );
  }

  Widget _followUpCard() => _card(
    icon: '🔔', title: 'Follow-Up Scheduled',
    badgeColor: kAccent, badge: 'Active',
    child: Column(children: [
      _row('Reminder at', followUp['reminder_scheduled'] ?? followUp['reminder_scheduled_at'] ?? ''),
      _row('Message', followUp['reminder_message'] ?? ''),
      _row('Completion check', followUp['completion_check'] ?? ''),
    ]),
  );

  Widget _serviceTrackerCard() => _card(
    icon: '🔧', title: 'Service Progress (Simulated)',
    badgeColor: kAccent, badge: 'Completed',
    child: Column(children: [
      _stage('📍 En-route', 'Provider is on the way', true),
      _stage('🏠 Arrived', 'Provider arrived at location', true),
      _stage('🔨 In Progress', 'Service being performed', true),
      _stage('✅ Completed', 'Service complete. Awaiting feedback.', true),
    ]),
  );

  Widget _baselineCard() => _card(
    icon: '📊', title: 'Agentic vs Non-Agentic Comparison',
    badgeColor: kPrimary, badge: 'Judge View',
    child: Table(
      border: TableBorder.all(color: Colors.grey.shade200),
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2)},
      children: [
        _tableRow(['Feature', 'Non-Agentic', 'Khidmat AI'], isHeader: true),
        _tableRow(['Matching factors', '1 (distance)', '6 factors']),
        _tableRow(['Pricing', 'Fixed flat rate', 'Dynamic']),
        _tableRow(['Languages', 'English only', 'Urdu+RomanUrdu+EN']),
        _tableRow(['Dispute handling', 'None', 'Full workflow']),
        _tableRow(['Complexity check', 'None', 'Auto-classify']),
        _tableRow(['Conflict prevention', 'None', 'Schedule lock']),
      ],
    ),
  );

  Widget _disputeSection() => Card(child: Padding(padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('⚠️', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text('Dispute Resolution', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() => _showDispute = !_showDispute),
          child: Text(_showDispute ? 'Hide' : 'Raise Issue')),
      ]),
      if (_showDispute && !_submitted) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _disputeType,
          decoration: InputDecoration(labelText: 'Issue Type',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          items: const [
            DropdownMenuItem(value: 'no_show', child: Text('Provider No-Show')),
            DropdownMenuItem(value: 'quality_complaint', child: Text('Quality Issue')),
            DropdownMenuItem(value: 'price_disagreement', child: Text('Price Dispute')),
            DropdownMenuItem(value: 'cancellation', child: Text('Cancellation')),
            DropdownMenuItem(value: 'refund_request', child: Text('Refund Request')),
          ],
          onChanged: (v) => setState(() => _disputeType = v!),
        ),
        const SizedBox(height: 8),
        TextField(controller: _disputeCtrl, maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Describe your issue...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            final bId = booking['booking_id'] ?? '';
            if (bId.isEmpty) return;
            try {
              await ApiService.raiseDispute(bId, _disputeType, _disputeCtrl.text);
              setState(() => _submitted = true);
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white),
          child: const Text('Submit Dispute'),
        ),
      ],
      if (_submitted)
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
          child: const Text('✅ Dispute submitted. Agent will review within 24 hours.',
            style: TextStyle(color: kAccent))),
    ]),
  ));

  Widget _card({required String icon, required String title,
      required Widget child, String? badge, Color badgeColor = kAccent}) =>
    Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600, fontSize: 15))),
          if (badge != null) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Text(badge, style: TextStyle(
              color: badgeColor, fontSize: 11, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 12),
        child,
      ],
    )));

  Widget _row(String k, String v) => Padding(padding: const EdgeInsets.only(bottom: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text('$k:', style: const TextStyle(color: Colors.grey, fontSize: 12))),
      Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
    ]));

  Widget _wRow(String k, String v) => Padding(padding: const EdgeInsets.only(bottom: 7),
    child: Row(children: [
      SizedBox(width: 110, child: Text('$k:', style: const TextStyle(color: Colors.white70, fontSize: 12))),
      Expanded(child: Text(v, style: const TextStyle(color: Colors.white,
        fontSize: 12, fontWeight: FontWeight.w600))),
    ]));

  Widget _chip(String label, IconData icon) => Chip(
    label: Text(label, style: const TextStyle(fontSize: 10)),
    avatar: Icon(icon, size: 12),
    padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact);

  Widget _stage(String icon, String text, bool done) =>
    Padding(padding: const EdgeInsets.only(bottom: 8), child:
      Row(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: done ? kAccent : Colors.grey.shade200),
          child: Center(child: Icon(
            done ? Icons.check : Icons.circle_outlined,
            size: 14, color: done ? Colors.white : Colors.grey))),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ]));

  TableRow _tableRow(List<String> cells, {bool isHeader = false}) => TableRow(
    decoration: isHeader ? BoxDecoration(color: kPrimary.withValues(alpha: 0.08)) : null,
    children: cells.map((c) => Padding(padding: const EdgeInsets.all(6),
      child: Text(c, style: TextStyle(
        fontSize: 11, fontWeight: isHeader ? FontWeight.bold : FontWeight.normal)))).toList());
}
