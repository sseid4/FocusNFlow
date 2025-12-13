import 'package:flutter/material.dart';
import 'package:focusnflow/services/auth_service.dart';
import 'package:focusnflow/services/study_schedule_optimizer.dart';
import 'package:table_calendar/table_calendar.dart';

class PersonalizedScheduleScreen extends StatefulWidget {
  const PersonalizedScheduleScreen({super.key});

  @override
  State<PersonalizedScheduleScreen> createState() =>
      _PersonalizedScheduleScreenState();
}

class _PersonalizedScheduleScreenState
    extends State<PersonalizedScheduleScreen> {
  final StudyScheduleOptimizer _optimizer = StudyScheduleOptimizer();
  final AuthService _authService = AuthService();

  List<StudyBlock> _studyBlocks = [];
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final blocks = await _optimizer.getStudyBlocks(userId: user.uid);
        setState(() {
          _studyBlocks = blocks;
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading schedule: $e')),
          );
        }
      }
    }
  }

  List<StudyBlock> _getBlocksForDay(DateTime day) {
    return _studyBlocks.where((block) {
      return block.startTime.year == day.year &&
          block.startTime.month == day.month &&
          block.startTime.day == day.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedule,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<CalendarFormat>(
            icon: const Icon(Icons.view_agenda),
            onSelected: (format) {
              setState(() => _calendarFormat = format);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: CalendarFormat.week,
                child: Text('Week View'),
              ),
              const PopupMenuItem(
                value: CalendarFormat.twoWeeks,
                child: Text('2 Weeks View'),
              ),
              const PopupMenuItem(
                value: CalendarFormat.month,
                child: Text('Month View'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _studyBlocks.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildCalendar(),
                    const Divider(height: 1),
                    Expanded(child: _buildScheduleList()),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No study schedule yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add courses and assignments,',
            style: TextStyle(color: Colors.grey),
          ),
          const Text(
            'then generate a schedule',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/course-management');
            },
            icon: const Icon(Icons.add),
            label: const Text('Go to Course Management'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final blocksWithDates = <DateTime, List<StudyBlock>>{};
    for (final block in _studyBlocks) {
      final date = DateTime(
        block.startTime.year,
        block.startTime.month,
        block.startTime.day,
      );
      blocksWithDates.putIfAbsent(date, () => []).add(block);
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 7)),
        lastDay: DateTime.now().add(const Duration(days: 90)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: _calendarFormat,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          setState(() => _calendarFormat = format);
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        eventLoader: (day) {
          final normalizedDay = DateTime(day.year, day.month, day.day);
          return blocksWithDates[normalizedDay] ?? [];
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    final blocksForDay = _getBlocksForDay(_selectedDay);

    if (blocksForDay.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.free_breakfast, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No study blocks for ${_selectedDay.month}/${_selectedDay.day}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enjoy your free time!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: blocksForDay.length,
      itemBuilder: (context, index) {
        final block = blocksForDay[index];
        return _buildStudyBlockCard(block);
      },
    );
  }

  Widget _buildStudyBlockCard(StudyBlock block) {
    final startTime = TimeOfDay.fromDateTime(block.startTime);
    final endTime = TimeOfDay.fromDateTime(block.endTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStudyTypeColor(block.studyType),
          child: Icon(
            _getStudyTypeIcon(block.studyType),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          block.assignmentTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.school, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  block.courseCode,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${startTime.format(context)} - ${endTime.format(context)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${block.duration} min',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStudyTypeColor(block.studyType).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatStudyType(block.studyType),
                    style: TextStyle(
                      fontSize: 11,
                      color: _getStudyTypeColor(block.studyType),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (block.topic.isNotEmpty) ...[
                  const Text(
                    'Topics',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: block.topic.split(',').map((topic) {
                      return Chip(
                        label: Text(
                          topic.trim(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.blue[50],
                        padding: const EdgeInsets.all(4),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (block.resources.isNotEmpty) ...[
                  const Text(
                    'Resources',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...block.resources.map((resource) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.book, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              resource,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        // TODO: Start Pomodoro session
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Starting Pomodoro session...'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Start Session'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        // TODO: Mark as completed
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Study block completed!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Complete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStudyTypeColor(String type) {
    switch (type) {
      case 'exam-prep':
        return Colors.red;
      case 'deep-work':
        return Colors.purple;
      case 'review':
        return Colors.orange;
      case 'practice':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _getStudyTypeIcon(String type) {
    switch (type) {
      case 'exam-prep':
        return Icons.quiz;
      case 'deep-work':
        return Icons.psychology;
      case 'review':
        return Icons.refresh;
      case 'practice':
        return Icons.edit;
      default:
        return Icons.book;
    }
  }

  String _formatStudyType(String type) {
    return type
        .split('-')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
