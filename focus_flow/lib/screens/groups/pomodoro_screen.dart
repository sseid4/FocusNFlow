import 'dart:async';

import 'package:flutter/material.dart';
import 'package:focusnflow/models/study_group.dart';
import 'package:focusnflow/services/auth_service.dart';
import 'package:focusnflow/services/pomodoro_service.dart';

class PomodoroScreen extends StatefulWidget {
  final StudyGroup group;

  const PomodoroScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  final PomodoroService _pomodoroService = PomodoroService();
  final AuthService _authService = AuthService();

  late Timer _timer;
  int _secondsRemaining = 0;
  bool _isRunning = false;
  String _currentPhase = 'work'; // work, short_break, long_break
  Map<String, dynamic>? _activeSession;
  String? _currentSessionId;
  String? _goalInput;

  @override
  void initState() {
    super.initState();
    _loadActiveSession();
  }

  void _loadActiveSession() async {
    try {
      final session = await _pomodoroService
          .getActivePomodoroSession(widget.group.id);
      if (mounted) {
        setState(() {
          _activeSession = session;
          if (session != null) {
            _currentSessionId = session['id'];
            _currentPhase = session['phase'] ?? 'work';
            _isRunning = session['status'] == 'active';
            _calculateSecondsRemaining();
            if (_isRunning) {
              _startTimer();
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _calculateSecondsRemaining() {
    if (_activeSession == null) return;

    final phaseStartTime =
        DateTime.parse(_activeSession!['phaseStartTime'] as String);
    final now = DateTime.now();
    final elapsed = now.difference(phaseStartTime).inSeconds;

    final phaseDuration = _currentPhase.contains('break')
        ? _activeSession!['breakDuration'] as int
        : _activeSession!['workDuration'] as int;

    _secondsRemaining = (phaseDuration - elapsed).clamp(0, phaseDuration);
  }

  void _startTimer() {
    if (_isRunning) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (mounted) {
        setState(() {
          _secondsRemaining--;
        });

        if (_secondsRemaining <= 0) {
          _timer.cancel();
          _transitionPhase();
        }
      }
    });

    setState(() => _isRunning = true);
  }

  void _pauseTimer() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    setState(() => _isRunning = false);

    if (_currentSessionId != null) {
      _pomodoroService.pauseSession(
        groupId: widget.group.id,
        sessionId: _currentSessionId!,
      );
    }
  }

  void _resumeTimer() {
    setState(() => _isRunning = true);

    if (_currentSessionId != null) {
      _pomodoroService.resumeSession(
        groupId: widget.group.id,
        sessionId: _currentSessionId!,
      );
    }

    _startTimer();
  }

  void _transitionPhase() async {
    late String newPhase;
    late int newDuration;

    if (_currentPhase == 'work') {
      final completedCycles =
          (_activeSession!['completedCycles'] as int? ?? 0) + 1;
      newPhase =
          completedCycles % 4 == 0 ? 'long_break' : 'short_break';
      newDuration = completedCycles % 4 == 0
          ? PomodoroService.longBreakDuration
          : PomodoroService.defaultBreakDuration;
    } else {
      newPhase = 'work';
      newDuration = _activeSession!['workDuration'] as int;
    }

    if (_currentSessionId != null) {
      try {
        await _pomodoroService.updatePhase(
          groupId: widget.group.id,
          sessionId: _currentSessionId!,
          newPhase: newPhase,
          nextPhaseDuration: newDuration,
        );

        if (mounted) {
          setState(() {
            _currentPhase = newPhase;
            _secondsRemaining = newDuration;
          });

          // Show notification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _currentPhase.contains('break')
                    ? 'Break time! Take a rest.'
                    : 'Time to focus!',
              ),
              duration: const Duration(seconds: 2),
            ),
          );

          _startTimer();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _stopSession() async {
    if (_timer.isActive) {
      _timer.cancel();
    }

    if (_currentSessionId != null) {
      try {
        await _pomodoroService.completeSession(
          groupId: widget.group.id,
          sessionId: _currentSessionId!,
        );

        if (mounted) {
          setState(() {
            _activeSession = null;
            _currentSessionId = null;
            _secondsRemaining = 0;
            _isRunning = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session completed!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _startNewSession() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final sessionId = await _pomodoroService.startPomodoroSession(
        groupId: widget.group.id,
        userId: user.uid,
        userName: user.email?.split('@').first ?? 'User',
        goal: _goalInput,
      );

      if (mounted) {
        setState(() {
          _currentSessionId = sessionId;
          _secondsRemaining = PomodoroService.defaultWorkDuration;
          _currentPhase = 'work';
          _goalInput = null;
        });

        _loadActiveSession();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _getPhaseName(String phase) {
    switch (phase) {
      case 'work':
        return 'Work';
      case 'short_break':
        return 'Short Break';
      case 'long_break':
        return 'Long Break';
      default:
        return 'Work';
    }
  }

  Color _getPhaseColor(String phase) {
    switch (phase) {
      case 'work':
        return const Color(0xFF6366F1); // Indigo
      case 'short_break':
        return const Color(0xFF10B981); // Green
      case 'long_break':
        return const Color(0xFF3B82F6); // Blue
      default:
        return const Color(0xFF6366F1);
    }
  }

  @override
  void dispose() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro Timer'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _activeSession == null
          ? _buildStartSessionView()
          : _buildActiveSessionView(),
    );
  }

  Widget _buildStartSessionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.timer_outlined,
              size: 80,
              color: Color(0xFF6366F1),
            ),
            const SizedBox(height: 24),
            const Text(
              'Start a Pomodoro Session',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Focus for 25 minutes with your group',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              onChanged: (value) => _goalInput = value,
              decoration: InputDecoration(
                hintText: 'What\'s your goal? (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.flag_outlined),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startNewSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Start Session',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionView() {
    final phaseColor = _getPhaseColor(_currentPhase);

    return RefreshIndicator(
      onRefresh: () async => _loadActiveSession(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Phase indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: phaseColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getPhaseName(_currentPhase),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: phaseColor,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Timer display
                Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: phaseColor.withOpacity(0.1),
                  ),
                  child: Text(
                    _formatTime(_secondsRemaining),
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: phaseColor,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Cycle counter
                if (_activeSession != null)
                  Text(
                    'Cycle ${_activeSession!['cycleCount'] ?? 1} • Completed: ${_activeSession!['completedCycles'] ?? 0} cycles',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),

                const SizedBox(height: 48),

                // Participants list
                if (_activeSession != null &&
                    (_activeSession!['participants'] as Map?)?.isNotEmpty ==
                        true)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Participants',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...((_activeSession!['participants'] as Map<String, dynamic>)
                              .entries
                          .where((e) =>
                              e.value['isActive'] == true)
                          .toList())
                          .map((entry) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(entry.value['name'] ?? 'User'),
                                    if (entry.value['goal'] != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 8),
                                        child: Text(
                                          '• ${entry.value['goal']}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ))
                          .toList(),
                      const SizedBox(height: 24),
                    ],
                  ),

                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Pause/Resume
                    FloatingActionButton.extended(
                      onPressed: _isRunning ? _pauseTimer : _resumeTimer,
                      icon: Icon(
                          _isRunning ? Icons.pause : Icons.play_arrow),
                      label: Text(_isRunning ? 'Pause' : 'Resume'),
                      backgroundColor: phaseColor,
                      foregroundColor: Colors.white,
                    ),

                    // Stop
                    FloatingActionButton.extended(
                      onPressed: _stopSession,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
