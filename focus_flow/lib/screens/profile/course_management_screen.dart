import 'package:flutter/material.dart';
import 'package:focusnflow/models/course_detail.dart';
import 'package:focusnflow/models/assignment.dart';
import 'package:focusnflow/services/auth_service.dart';
import 'package:focusnflow/services/course_management_service.dart';
import 'package:focusnflow/services/study_schedule_optimizer.dart';

class CourseManagementScreen extends StatefulWidget {
  const CourseManagementScreen({super.key});

  @override
  State<CourseManagementScreen> createState() => _CourseManagementScreenState();
}

class _CourseManagementScreenState extends State<CourseManagementScreen>
    with SingleTickerProviderStateMixin {
  final CourseManagementService _courseService = CourseManagementService();
  final StudyScheduleOptimizer _optimizer = StudyScheduleOptimizer();
  final AuthService _authService = AuthService();
  late TabController _tabController;

  List<CourseDetail> _courses = [];
  List<Assignment> _assignments = [];
  bool _isLoadingCourses = true;
  bool _isLoadingAssignments = true;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    _loadData();
    // Handle deep-link intents to open add dialogs or select tabs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['intent'] is String) {
        final intent = args['intent'] as String;
        if (intent == 'addCourse') {
          _tabController.index = 0;
          _selectedTabIndex = 0;
          _showAddCourseDialog();
        } else if (intent == 'addAssignment') {
          _tabController.index = 1;
          _selectedTabIndex = 1;
          _showAddAssignmentDialog();
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = _authService.currentUser;
    if (user != null) {
      await Future.wait([
        _loadCourses(user.uid),
        _loadAssignments(user.uid),
      ]);
    }
  }

  Future<void> _loadCourses(String userId) async {
    setState(() => _isLoadingCourses = true);
    try {
      final courses = await _courseService.getUserCourses(userId: userId);
      setState(() {
        _courses = courses;
        _isLoadingCourses = false;
      });
    } catch (e) {
      setState(() => _isLoadingCourses = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading courses: $e')),
        );
      }
    }
  }

  Future<void> _loadAssignments(String userId) async {
    setState(() => _isLoadingAssignments = true);
    try {
      final assignments =
          await _courseService.getUserAssignments(userId: userId);
      setState(() {
        _assignments = assignments;
        _isLoadingAssignments = false;
      });
    } catch (e) {
      setState(() => _isLoadingAssignments = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading assignments: $e')),
        );
      }
    }
  }

  Future<void> _showAddCourseDialog() async {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final instructorController = TextEditingController();
    final semesterController = TextEditingController();
    int credits = 3;
    String difficulty = 'medium';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Course'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Course Code *',
                    hintText: 'e.g., CSC 4320',
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Course Name *',
                    hintText: 'e.g., Software Engineering',
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: instructorController,
                  decoration: const InputDecoration(
                    labelText: 'Instructor',
                    hintText: 'e.g., Dr. Smith',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: semesterController,
                  decoration: const InputDecoration(
                    labelText: 'Semester *',
                    hintText: 'e.g., Fall 2024',
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: credits,
                  decoration: const InputDecoration(labelText: 'Credits'),
                  items: [1, 2, 3, 4, 5]
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text('$c'),
                          ))
                      .toList(),
                  onChanged: (v) => credits = v!,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: difficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items: ['easy', 'medium', 'hard']
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d[0].toUpperCase() + d.substring(1)),
                          ))
                      .toList(),
                  onChanged: (v) => difficulty = v!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final user = _authService.currentUser;
                if (user != null) {
                  final course = CourseDetail(
                    id: '',
                    code: codeController.text.trim(),
                    name: nameController.text.trim(),
                    instructor: instructorController.text.trim(),
                    semester: semesterController.text.trim(),
                    credits: credits,
                    difficulty: difficulty,
                    startDate: DateTime.now(),
                    endDate: DateTime.now().add(const Duration(days: 120)),
                  );

                  try {
                    await _courseService.saveCourse(
                        userId: user.uid, course: course);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Course added')),
                      );
                      _loadCourses(user.uid);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAssignmentDialog() async {
    if (_courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a course first')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    String? selectedCourseId = _courses.first.id;
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    String type = 'homework';
    double estimatedHours = 3.0;
    String difficulty = 'medium';
    int priority = 2;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Assignment'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCourseId,
                    decoration: const InputDecoration(labelText: 'Course *'),
                    items: _courses
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.code),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedCourseId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      hintText: 'e.g., Homework 3',
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Due Date'),
                    subtitle: Text(
                      '${dueDate.month}/${dueDate.day}/${dueDate.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: ['homework', 'exam', 'project', 'quiz', 'paper']
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t[0].toUpperCase() + t.substring(1)),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => type = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: estimatedHours.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Estimated Hours',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        estimatedHours = double.tryParse(v) ?? 3.0,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: difficulty,
                    decoration: const InputDecoration(labelText: 'Difficulty'),
                    items: ['easy', 'medium', 'hard']
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(d[0].toUpperCase() + d.substring(1)),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => difficulty = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: [1, 2, 3]
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p == 1
                                  ? 'Low'
                                  : p == 2
                                      ? 'Medium'
                                      : 'High'),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => priority = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final user = _authService.currentUser;
                  if (user != null && selectedCourseId != null) {
                    final assignment = Assignment(
                      id: '',
                      courseId: selectedCourseId!,
                      title: titleController.text.trim(),
                      dueDate: dueDate,
                      type: type,
                      estimatedHours: estimatedHours.round(),
                      difficulty: difficulty,
                      priority: priority,
                    );

                    try {
                      await _courseService.saveAssignment(
                        userId: user.uid,
                        assignment: assignment,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Assignment added')),
                        );
                        _loadAssignments(user.uid);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateSchedule() async {
    if (_courses.isEmpty || _assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add courses and assignments first'),
        ),
      );
      return;
    }

    final user = _authService.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await _optimizer.generateOptimizedSchedule(
        userId: user.uid,
        courses: _courses,
        assignments: _assignments.where((a) => !a.isCompleted).toList(),
        daysAhead: 14,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule generated! Check Personalized Schedule.'),
          ),
        );
        Navigator.pushNamed(context, '/personalized-schedule');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating schedule: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Courses'),
            Tab(text: 'Assignments'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: _generateSchedule,
            tooltip: 'Generate Study Schedule',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCoursesTab(),
          _buildAssignmentsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedTabIndex == 0
            ? _showAddCourseDialog
            : _showAddAssignmentDialog,
        icon: const Icon(Icons.add),
        label: Text(_selectedTabIndex == 0 ? 'Add Course' : 'Add Assignment'),
      ),
    );
  }

  Widget _buildCoursesTab() {
    if (_isLoadingCourses) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No courses yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to add your first course',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getDifficultyColor(course.difficulty),
              child: Text(
                course.code.split(' ').first.substring(0, 2).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            title: Text(course.code, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.name),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(course.instructor, style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(width: 12),
                    Icon(Icons.star, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${course.credits} credits', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final user = _authService.currentUser;
                if (user != null) {
                  try {
                    await _courseService.deleteCourse(
                      userId: user.uid,
                      courseId: course.id,
                    );
                    _loadCourses(user.uid);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignmentsTab() {
    if (_isLoadingAssignments) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No assignments yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to add your first assignment',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignments.length,
      itemBuilder: (context, index) {
        final assignment = _assignments[index];
        final course = _courses.firstWhere(
          (c) => c.id == assignment.courseId,
          orElse: () => CourseDetail(
            id: '',
            code: 'Unknown',
            name: '',
            semester: '',
            credits: 0,
            startDate: DateTime.now(),
            endDate: DateTime.now(),
          ),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getTypeIcon(assignment.type),
                  color: assignment.isOverdue
                      ? Colors.red
                      : assignment.isDueSoon
                          ? Colors.orange
                          : Colors.blue,
                ),
                const SizedBox(height: 4),
                Text(
                  '${assignment.daysUntilDue}d',
                  style: TextStyle(
                    fontSize: 10,
                    color: assignment.isOverdue ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ),
            title: Text(
              assignment.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: assignment.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.code),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Due: ${assignment.dueDate.month}/${assignment.dueDate.day}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${assignment.estimatedHours}h',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!assignment.isCompleted)
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: () async {
                      final user = _authService.currentUser;
                      if (user != null) {
                        try {
                          await _courseService.completeAssignment(
                            userId: user.uid,
                            assignmentId: assignment.id,
                          );
                          _loadAssignments(user.uid);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      }
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final user = _authService.currentUser;
                    if (user != null) {
                      try {
                        await _courseService.deleteAssignment(
                          userId: user.uid,
                          assignmentId: assignment.id,
                        );
                        _loadAssignments(user.uid);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return Colors.green;
      case 'hard':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'exam':
        return Icons.quiz;
      case 'project':
        return Icons.code;
      case 'quiz':
        return Icons.question_answer;
      case 'paper':
        return Icons.article;
      default:
        return Icons.assignment;
    }
  }
}
