import 'package:flutter/material.dart';
import 'package:focusnflow/services/auth_service.dart';
import 'package:focusnflow/services/cognitive_load_analyzer.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final CognitiveLoadAnalyzer _analyzer = CognitiveLoadAnalyzer();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  Map<String, dynamic> _patterns = {};
  Map<String, dynamic> _attention = {};
  Map<String, dynamic> _burnout = {};
  Map<String, dynamic> _performance = {};
  Map<String, dynamic> _recommendation = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  void _loadAnalytics() async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;

      setState(() => _isLoading = true);

      final patterns = await _analyzer.analyzeStudyPatterns(userId: userId);
      final attention = await _analyzer.analyzeAttentionSpan(userId: userId);
      final burnout = await _analyzer.calculateBurnoutRisk(userId: userId);
      final performance =
          await _analyzer.calculatePerformanceMetrics(userId: userId);
      final recommendation =
          await _analyzer.getOptimalSessionRecommendation(userId: userId);

      if (mounted) {
        setState(() {
          _patterns = patterns;
          _attention = attention;
          _burnout = burnout;
          _performance = performance;
          _recommendation = recommendation;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Analytics'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _loadAnalytics(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBurnoutCard(),
                    const SizedBox(height: 20),
                    _buildStudyPatternsCard(),
                    const SizedBox(height: 20),
                    _buildAttentionSpanCard(),
                    const SizedBox(height: 20),
                    _buildPerformanceCard(),
                    const SizedBox(height: 20),
                    _buildRecommendationsCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBurnoutCard() {
    final isBurnout = _burnout['isBurnoutRisk'] as bool? ?? false;
    final riskScore = _burnout['burnoutRiskScore'] as String? ?? '0';
    final riskLevel = _burnout['riskLevel'] as String? ?? 'Unknown';

    Color riskColor = Colors.green;
    IconData riskIcon = Icons.check_circle;

    if (riskLevel == 'Moderate') {
      riskColor = Colors.orange;
      riskIcon = Icons.warning;
    } else if (riskLevel == 'High') {
      riskColor = Colors.orange[700]!;
      riskIcon = Icons.warning_amber;
    } else if (riskLevel == 'Critical') {
      riskColor = Colors.red;
      riskIcon = Icons.error;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(riskIcon, color: riskColor, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Burnout Risk',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Risk Score',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$riskScore%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    riskLevel,
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Contributing Factors',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            ..._buildFactorsList(),
            if (isBurnout)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: riskColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Take action to reduce burnout risk',
                          style: TextStyle(
                            color: riskColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFactorsList() {
    final factors = _burnout['factors'] as Map<String, dynamic>?;
    if (factors == null) return [];

    return factors.entries.map((entry) {
      final name = entry.key;
      final value = double.tryParse(entry.value as String? ?? '0') ?? 0;
      final displayName = name
          .replaceAll(RegExp(r'([A-Z])'), ' \$1')
          .trim()
          .replaceFirst(name[0].toUpperCase(), name[0]);

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                displayName,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value / 100,
                  minHeight: 6,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation(
                    value > 70
                        ? Colors.red
                        : value > 40
                            ? Colors.orange
                            : Colors.green,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${value.toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildStudyPatternsCard() {
    final avgLength = _patterns['averageSessionLength'] as int? ?? 0;
    final sessionsPerDay = _patterns['sessionsPerDay'] as double? ?? 0.0;
    final breakFreq = _patterns['breakFrequency'] as int? ?? 0;
    final totalSessions = _patterns['totalSessionsAnalyzed'] as int? ?? 0;
    final peakHour = _patterns['peakStudyHour'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, color: Color(0xFF6366F1), size: 24),
                SizedBox(width: 12),
                Text(
                  'Study Patterns',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow('Average Session', '$avgLength minutes'),
            _buildStatRow('Sessions/Day', '$sessionsPerDay'),
            _buildStatRow('Avg Break Length', '$breakFreq minutes'),
            _buildStatRow('Total Sessions', '$totalSessions'),
            _buildStatRow(
              'Peak Study Time',
              _formatHour(peakHour),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionSpanCard() {
    final focusTime = _attention['averageFocusTime'] as int? ?? 0;
    final degradation =
        _attention['performanceDegradation'] as String? ?? '0%';
    final variability =
        _attention['focusVariability'] as String? ?? '0%';
    final optimal =
        _attention['optimalSessionDuration'] as int? ?? 25;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology, color: Color(0xFF10B981), size: 24),
                SizedBox(width: 12),
                Text(
                  'Attention Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow('Focus Duration', '$focusTime cycles'),
            _buildStatRow(
              'Performance Degradation',
              degradation,
            ),
            _buildStatRow(
              'Focus Variability',
              variability,
            ),
            _buildStatRow(
              'Optimal Session Length',
              '$optimal minutes',
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    final comprehension =
        _performance['comprehensionScore'] as int? ?? 0;
    final completion =
        _performance['taskCompletionRate'] as double? ?? 0.0;
    final retention =
        _performance['knowledgeRetention'] as double? ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events, color: Color(0xFFEAB308), size: 24),
                SizedBox(width: 12),
                Text(
                  'Performance Metrics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow('Comprehension Score', '$comprehension/100'),
            _buildStatRow(
              'Task Completion',
              '${(completion * 100).toStringAsFixed(0)}%',
            ),
            _buildStatRow(
              'Knowledge Retention',
              '${(retention * 100).toStringAsFixed(0)}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    final burnoutRecommendations = _burnout['recommendations'] as List?;
    final sessionDuration =
        _recommendation['optimalSessionDuration'] as int? ?? 25;
    final sessionsPerDay =
        _recommendation['recommendedSessionsPerDay'] as int? ?? 3;
    final shouldReduce =
        _recommendation['shouldReduceLoad'] as bool? ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb, color: Color(0xFFF59E0B), size: 24),
                SizedBox(width: 12),
                Text(
                  'Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Optimal Session Settings',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Session Duration: $sessionDuration minutes',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Sessions per Day: $sessionsPerDay',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (shouldReduce)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '• ⚠️ Consider reducing study load',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (burnoutRecommendations != null &&
                burnoutRecommendations.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Action Items',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(burnoutRecommendations as List<String>)
                      .map((rec) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '→ ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                                Expanded(child: Text(rec)),
                              ],
                            ),
                          ))
                      .toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? const Color(0xFF6366F1) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }
}
