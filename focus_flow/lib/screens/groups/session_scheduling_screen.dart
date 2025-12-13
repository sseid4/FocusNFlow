import 'package:flutter/material.dart';
import 'package:focusnflow/models/study_group.dart';
import 'package:focusnflow/models/study_session.dart';
import 'package:focusnflow/services/auth_service.dart';
import 'package:focusnflow/services/study_session_service.dart';

class SessionSchedulingScreen extends StatefulWidget {
  final StudyGroup group;

  const SessionSchedulingScreen({Key? key, required this.group})
      : super(key: key);

  @override
  State<SessionSchedulingScreen> createState() =>
      _SessionSchedulingScreenState();
}

class _SessionSchedulingScreenState extends State<SessionSchedulingScreen> {
  final StudySessionService _sessionService = StudySessionService();
  final AuthService _authService = AuthService();

  late DateTime _selectedDate;
  List<StudySession> _upcomingSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadSessions();
  }

  void _loadSessions() async {
    try {
      setState(() => _isLoading = true);
      final sessions =
          await _sessionService.getUpcomingSessions(widget.group.id);
      if (mounted) {
        setState(() {
          _upcomingSessions = sessions;
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

  void _showCreateSessionDialog() {
    String title = '';
    DateTime selectedStart = _selectedDate.add(const Duration(hours: 1));
    DateTime selectedEnd = selectedStart.add(const Duration(hours: 1));
    String? location;
    String? description;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Schedule Study Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                TextField(
                  onChanged: (value) => title = value,
                  decoration: InputDecoration(
                    labelText: 'Session Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'e.g., CS101 Study Group',
                  ),
                ),
                const SizedBox(height: 16),

                // Start Time
                ListTile(
                  title: const Text('Start Time'),
                  subtitle: Text(
                    '${selectedStart.month}/${selectedStart.day} ${selectedStart.hour}:${selectedStart.minute.toString().padLeft(2, '0')}',
                  ),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedStart,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 90)),
                    );
                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedStart),
                      );
                      if (pickedTime != null) {
                        setState(() {
                          selectedStart = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),

                // End Time
                ListTile(
                  title: const Text('End Time'),
                  subtitle: Text(
                    '${selectedEnd.month}/${selectedEnd.day} ${selectedEnd.hour}:${selectedEnd.minute.toString().padLeft(2, '0')}',
                  ),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedEnd,
                      firstDate: selectedStart,
                      lastDate:
                          DateTime.now().add(const Duration(days: 90)),
                    );
                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedEnd),
                      );
                      if (pickedTime != null) {
                        setState(() {
                          selectedEnd = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Location
                TextField(
                  onChanged: (value) => location = value,
                  decoration: InputDecoration(
                    labelText: 'Location (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'e.g., Library Room 101',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  onChanged: (value) => description = value,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'What will you discuss?',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a title')),
                  );
                  return;
                }

                try {
                  final user = _authService.currentUser;
                  if (user == null) return;

                  await _sessionService.createSession(
                    groupId: widget.group.id,
                    createdBy: user.uid,
                    title: title,
                    startTime: selectedStart,
                    endTime: selectedEnd,
                    location: location,
                    description: description,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    _loadSessions();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Session scheduled!')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
              ),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionDetails(StudySession session) {
    final user = _authService.currentUser;
    final isCreator = user?.uid == session.createdBy;
    final userRsvpStatus =
        session.rsvpStatus[user?.uid ?? ''] ?? 'not_responded';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  // Title
                  Text(
                    session.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          color: Color(0xFF6366F1)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'When',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${_formatDate(session.startTime)} at ${_formatTime(session.startTime)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              'Duration: ${session.endTime.difference(session.startTime).inHours}h ${(session.endTime.difference(session.startTime).inMinutes % 60)}m',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location
                  if (session.location != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            color: Color(0xFF6366F1)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(session.location!),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (session.location != null) const SizedBox(height: 16),

                  // Description
                  if (session.description != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.description_outlined,
                            color: Color(0xFF6366F1)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Description',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(session.description!),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (session.description != null) const SizedBox(height: 24),

                  // RSVP Status
                  const Text(
                    'Your RSVP',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildRsvpButton(
                        'Yes',
                        'yes',
                        userRsvpStatus,
                        () => _rsvpToSession(session, 'yes'),
                        Colors.green,
                      ),
                      _buildRsvpButton(
                        'Maybe',
                        'maybe',
                        userRsvpStatus,
                        () => _rsvpToSession(session, 'maybe'),
                        Colors.orange,
                      ),
                      _buildRsvpButton(
                        'No',
                        'no',
                        userRsvpStatus,
                        () => _rsvpToSession(session, 'no'),
                        Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Attendees
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attendees',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._buildAttendeesList(session),
                    ],
                  ),

                  if (isCreator) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () => _deleteSession(session),
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRsvpButton(
    String label,
    String status,
    String currentStatus,
    VoidCallback onPressed,
    Color color,
  ) {
    final isSelected = currentStatus == status;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? color : Colors.grey[200],
            foregroundColor: isSelected ? Colors.white : Colors.black,
          ),
          child: Text(label),
        ),
      ),
    );
  }

  List<Widget> _buildAttendeesList(StudySession session) {
    final yesRsvps = session.rsvpStatus.entries
        .where((e) => e.value == 'yes')
        .length;
    final maybeRsvps = session.rsvpStatus.entries
        .where((e) => e.value == 'maybe')
        .length;

    return [
      Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                'Y',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$yesRsvps going'),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$maybeRsvps maybe'),
        ],
      ),
    ];
  }

  void _rsvpToSession(StudySession session, String status) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      await _sessionService.rsvpToSession(
        groupId: widget.group.id,
        sessionId: session.id,
        userId: user.uid,
        status: status,
      );

      if (mounted) {
        Navigator.pop(context);
        _loadSessions();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _deleteSession(StudySession session) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      await _sessionService.deleteSession(
        groupId: widget.group.id,
        sessionId: session.id,
        userId: user.uid,
      );

      if (mounted) {
        Navigator.pop(context);
        _loadSessions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session deleted')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    } else if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'Tomorrow';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Sessions'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _upcomingSessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No sessions scheduled',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Schedule the first study session',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showCreateSessionDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Schedule Session'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _upcomingSessions.length,
                  itemBuilder: (context, index) {
                    final session = _upcomingSessions[index];
                    final user = _authService.currentUser;
                    final userRsvpStatus =
                        session.rsvpStatus[user?.uid ?? ''] ??
                            'not_responded';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        onTap: () => _showSessionDetails(session),
                        title: Text(session.title),
                        subtitle: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              '${_formatDate(session.startTime)} at ${_formatTime(session.startTime)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Duration: ${session.endTime.difference(session.startTime).inHours}h',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (userRsvpStatus == 'yes')
                                  Chip(
                                    label: const Text('You\'re going'),
                                    backgroundColor: Colors.green[100],
                                    labelStyle: const TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                                if (userRsvpStatus == 'maybe')
                                  Chip(
                                    label: const Text('Maybe'),
                                    backgroundColor: Colors.orange[100],
                                    labelStyle: const TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSessionDialog,
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add),
      ),
    );
  }
}
