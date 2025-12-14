import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:focusnflow/services/cognitive_load_analyzer.dart';
import 'package:focusnflow/services/course_management_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CognitiveLoadAnalyzer _analyzer = CognitiveLoadAnalyzer();
  final CourseManagementService _courseService = CourseManagementService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Future<Map<String, dynamic>> _homeDataFuture;

  @override
  void initState() {
    super.initState();
    _homeDataFuture = _loadHomeData();
  }

  Future<void> _refreshHomeData() async {
    setState(() {
      _homeDataFuture = _loadHomeData();
    });
    await _homeDataFuture;
  }

  Future<Map<String, dynamic>> _loadHomeData() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final results = await Future.wait([
        _analyzer.analyzeStudyPatterns(userId: user.uid),
        _analyzer.analyzeAttentionSpan(userId: user.uid),
        _analyzer.calculateBurnoutRisk(userId: user.uid),
        _courseService.getUserCourses(userId: user.uid, activeOnly: true),
        _courseService.getUserAssignments(
          userId: user.uid,
          includeCompleted: false,
        ),
        _fetchTodaySessions(user.uid),
      ]);

      final patterns = results[0] as Map<String, dynamic>;
      final attention = results[1] as Map<String, dynamic>;
      final burnout = results[2] as Map<String, dynamic>;
      final courses = results[3] as List<dynamic>;
      final assignments = results[4] as List<dynamic>;
      final todaySessions = results[5] as List<Map<String, dynamic>>;

      // Get upcoming assignments (next 7 days)
      final upcomingAssignments = assignments
          .where(
            (a) =>
                a.daysUntilDue > 0 && a.daysUntilDue <= 7 && !a.isCompleted,
          )
          .toList()
        ..sort((a, b) => a.daysUntilDue.compareTo(b.daysUntilDue));

      return {
        'patterns': patterns,
        'attention': attention,
        'burnout': burnout,
        'courses': courses,
        'assignments': assignments,
        'upcomingAssignments': upcomingAssignments.take(3).toList(),
        'todaySessions': todaySessions,
        'todayCourses': _getTodayCourseMeetings(courses),
        'userName': user.email?.split('@').first.toUpperCase() ?? 'STUDENT',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTodaySessions(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collectionGroup('pomodoro_sessions')
        .where('startTime', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('startTime', isLessThan: endOfDay.toIso8601String())
        .where('participants.$userId.joinedAt', isGreaterThan: '')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final status = (data['status'] as String?) ?? 'active';
      final startTimeStr = data['startTime'] as String?;
      final startTime = startTimeStr != null ? DateTime.tryParse(startTimeStr) : null;
      final goal = (data['participants'][userId]?['goal'] as String?) ?? 'Pomodoro session';
      final groupId = data['groupId'] as String? ?? '';
      return {
        'id': data['id'] ?? doc.id,
        'groupId': groupId,
        'goal': goal,
        'status': status,
        'startTime': startTime,
      };
    }).toList()
      ..sort((a, b) {
        final aTime = a['startTime'] as DateTime? ?? DateTime.now();
        final bTime = b['startTime'] as DateTime? ?? DateTime.now();
        return aTime.compareTo(bTime);
      });
  }

  List<Map<String, String>> _getTodayCourseMeetings(List<dynamic> courses) {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon
    const dayKeys = {
      1: ['m', 'mon', 'monday'],
      2: ['tu', 'tue', 'tues', 'tuesday'],
      3: ['w', 'wed', 'wednesday'],
      4: ['th', 'thu', 'thur', 'thurs', 'thursday'],
      5: ['f', 'fri', 'friday'],
      6: ['sa', 'sat', 'saturday'],
      7: ['su', 'sun', 'sunday'],
    };

    bool occursToday(String meeting) {
      final lower = meeting.toLowerCase();
      final keys = dayKeys[weekday] ?? [];
      return keys.any((k) => lower.contains(k));
    }

    String extractTime(String meeting) {
      final parts = meeting.split(' ');
      if (parts.length >= 2) return parts.sublist(1).join(' ');
      return meeting;
    }

    return courses
        .where((c) => c.meetingTimes.isNotEmpty)
        .expand<Map<String, String>>((c) => c.meetingTimes
            .where((mt) => occursToday(mt))
            .map((mt) => {
                  'course': '${c.code} • ${c.name}',
                  'time': extractTime(mt),
                }))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FocusNFlow',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF0055B8), // GSU Blue
        
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _homeDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {};
          final burnoutRisk = data['burnout']?['isBurnoutRisk'] ?? false;
          final courses = data['courses'] ?? [];
          final upcomingAssignments = data['upcomingAssignments'] ?? [];
          final todaySessions = data['todaySessions'] as List<Map<String, dynamic>>? ?? [];
          final todayCourses = data['todayCourses'] as List<Map<String, String>>? ?? [];
          final userName = data['userName'] ?? 'STUDENT';

          return RefreshIndicator(
            onRefresh: _refreshHomeData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Hero Section with GSU Colors
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0055B8),
                          Color(0xFF003D7A),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $userName',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Georgia State University - Go Panthers! 🐾',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatCard(
                              icon: Icons.school,
                              label: 'Courses',
                              value: courses.length.toString(),
                            ),
                            _buildStatCard(
                              icon: Icons.assignment,
                              label: 'Assignments',
                              value: upcomingAssignments.length.toString(),
                            ),
                            _buildStatCard(
                              icon: Icons.favorite,
                              label: 'Health',
                              value: burnoutRisk ? '⚠️' : '✅',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (burnoutRisk)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.red[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Burnout Risk Detected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Consider taking a break and prioritizing rest',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.location_on,
                                label: 'Find Rooms',
                                color: const Color(0xFF10B981),
                                onTap: () => Navigator.pushNamed(context, '/map'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.group,
                                label: 'Study Groups',
                                color: const Color(0xFF8B5CF6),
                                onTap: () => Navigator.pushNamed(context, '/groups'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.schedule,
                                label: 'My Schedule',
                                color: const Color(0xFFF59E0B),
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/personalized-schedule',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.analytics,
                                label: 'Analytics',
                                color: const Color(0xFF6366F1),
                                onTap: () => Navigator.pushNamed(context, '/analytics'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.add_circle_outline,
                                label: 'Add Course',
                                color: const Color(0xFF0EA5E9),
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/course-management',
                                  arguments: {'intent': 'addCourse'},
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.playlist_add,
                                label: 'Add Assignment',
                                color: const Color(0xFF22C55E),
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/course-management',
                                  arguments: {'intent': 'addAssignment'},
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's Study Sessions",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (todaySessions.isEmpty)
                          Text(
                            'No sessions logged today. Start a Pomodoro from your study group.',
                            style: TextStyle(color: Colors.grey[600]),
                          )
                        else
                          ...todaySessions.take(3).map((s) => _buildSessionCard(s)),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/groups'),
                            icon: const Icon(Icons.play_circle_outline),
                            label: const Text('Open Study Groups to Start/End'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's Classes",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (todayCourses.isEmpty)
                          Text(
                            'No classes scheduled today.',
                            style: TextStyle(color: Colors.grey[600]),
                          )
                        else
                          ...todayCourses.map((c) => _buildClassCard(c)),
                        if (todayCourses.isEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                '/course-management',
                                arguments: {'intent': 'addCourse'},
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add a course'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nearby Study Rooms 📍',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 280,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('studyRooms')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return const Center(child: Text('Error loading map'));
                              }
                              if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              final rooms = snapshot.data!.docs;
                              if (rooms.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No study rooms available',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                );
                              }

                              final List<LatLng> locations = rooms.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final lat = (data['latitude'] ?? 0.0).toDouble();
                                final lng = (data['longitude'] ?? 0.0).toDouble();
                                return LatLng(lat, lng);
                              }).toList();

                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: locations[0],
                                    initialZoom: 15,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                                      subdomains: const ['a', 'b', 'c'],
                                    ),
                                    MarkerLayer(
                                      markers: locations.map((loc) {
                                        return Marker(
                                          point: loc,
                                          width: 40,
                                          height: 40,
                                          child: GestureDetector(
                                            onTap: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Study Room Available'),
                                                ),
                                              );
                                            },
                                            child: const Icon(
                                              Icons.location_on,
                                              color: Color(0xFF0055B8),
                                              size: 32,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap on a location to see details or navigate to the full map',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (upcomingAssignments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Due This Week 📅',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...upcomingAssignments.map((assignment) => _buildAssignmentCard(assignment)),
                        ],
                      ),
                    ),
                  if (upcomingAssignments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/course-management',
                            arguments: {'intent': 'addAssignment'},
                          ),
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('Add an assignment'),
                        ),
                      ),
                    ),

                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055B8).withValues(alpha: 0.1),
                      border: Border.all(color: const Color(0xFF0055B8)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '💡 Study Tip of the Day',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use the Pomodoro Technique: Study for 25 minutes, then take a 5-minute break. After 4 cycles, take a longer 15-30 minute break. This boosts focus and prevents burnout!',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          '🎓 "Eagles Rising" - Georgia State University',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          'Your success is our mission',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final status = (session['status'] as String?) ?? 'active';
    final start = session['startTime'] as DateTime?;
    String formatTime(DateTime? dt) {
      if (dt == null) return 'Today';
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final suffix = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour12:$minute $suffix';
    }

    final timeLabel = formatTime(start);

    Color chipColor;
    String chipLabel;
    if (status == 'completed') {
      chipColor = Colors.green;
      chipLabel = 'Completed';
    } else if (status == 'paused') {
      chipColor = Colors.orange;
      chipLabel = 'Paused';
    } else {
      chipColor = const Color(0xFF0055B8);
      chipLabel = 'Active';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: chipColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              chipLabel,
              style: TextStyle(color: chipColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session['goal'] as String? ?? 'Pomodoro session',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  timeLabel,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, String> course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.grey[50],
      ),
      child: Row(
        children: [
          const Icon(Icons.class_, color: Color(0xFF0055B8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course['course'] ?? 'Course',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  course['time'] ?? '',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(dynamic assignment) {
    final daysLeft = assignment.daysUntilDue;
    final isUrgent = daysLeft <= 2;
    final isDueSoon = daysLeft <= 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            width: 4,
            color: isUrgent
                ? Colors.red
                : isDueSoon
                ? Colors.orange
                : Colors.green,
          ),
        ),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  assignment.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? Colors.red[100]
                      : isDueSoon
                      ? Colors.orange[100]
                      : Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$daysLeft day${daysLeft != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isUrgent
                        ? Colors.red[700]
                        : isDueSoon
                        ? Colors.orange[700]
                        : Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Due: ${assignment.dueDate.month}/${assignment.dueDate.day}/${assignment.dueDate.year}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(width: 12),
              Icon(Icons.timer, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${assignment.estimatedHours}h',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
