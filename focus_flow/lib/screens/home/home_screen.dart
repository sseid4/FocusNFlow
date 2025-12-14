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

  late Future<Map<String, dynamic>> _homeDataFuture;

  @override
  void initState() {
    super.initState();
    _homeDataFuture = _loadHomeData();
  }

  Future<Map<String, dynamic>> _loadHomeData() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final [
        patterns,
        attention,
        burnout,
        courses,
        assignments,
      ] = await Future.wait([
        _analyzer.analyzeStudyPatterns(userId: user.uid),
        _analyzer.analyzeAttentionSpan(userId: user.uid),
        _analyzer.calculateBurnoutRisk(userId: user.uid),
        _courseService.getUserCourses(userId: user.uid, activeOnly: true),
        _courseService.getUserAssignments(
          userId: user.uid,
          includeCompleted: false,
        ),
      ]);

      // Get upcoming assignments (next 7 days)
      final upcomingAssignments =
          (assignments as List)
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
        'userName': user.email?.split('@').first.toUpperCase() ?? 'STUDENT',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
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
          final userName = data['userName'] ?? 'STUDENT';

          return SingleChildScrollView(
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
                      ], // GSU Blue gradient
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
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Quick Stats Row
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

                // Burnout Warning
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

                // Quick Action Cards
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
                              onTap: () =>
                                  Navigator.pushNamed(context, '/groups'),
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
                              onTap: () =>
                                  Navigator.pushNamed(context, '/analytics'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Mini Study Rooms Map
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
                              return const Center(
                                child: Text('Error loading map'),
                              );
                            }
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
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

                            // Convert Firestore documents to LatLng markers
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
                                    urlTemplate:
                                        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
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
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Study Room Available',
                                                ),
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

                // Upcoming Assignments
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
                        ...upcomingAssignments.map((assignment) {
                          return _buildAssignmentCard(assignment);
                        }),
                      ],
                    ),
                  ),

                // Study Tip
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0055B8).withOpacity(0.1),
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

                // GSU Motto Footer
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
            color: Colors.white.withOpacity(0.2),
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
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8)),
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
          color: color.withOpacity(0.1),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
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
