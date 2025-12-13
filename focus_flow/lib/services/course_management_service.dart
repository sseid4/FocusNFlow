import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focusnflow/models/assignment.dart';
import 'package:focusnflow/models/course_detail.dart';

class CourseManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String usersCollection = 'users';
  static const String coursesSubcollection = 'courses';
  static const String assignmentsSubcollection = 'assignments';

  // Create or update course
  Future<String> saveCourse({
    required String userId,
    required CourseDetail course,
  }) async {
    try {
      final courseRef = _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(coursesSubcollection)
          .doc(course.id.isEmpty ? null : course.id);

      await courseRef.set(course.toJson());
      return courseRef.id;
    } catch (e) {
      throw Exception('Failed to save course: $e');
    }
  }

  // Get all user's courses
  Future<List<CourseDetail>> getUserCourses({
    required String userId,
    bool activeOnly = false,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(coursesSubcollection)
          .get();

      final courses = snapshot.docs
          .map((doc) => CourseDetail.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      if (activeOnly) {
        return courses.where((c) => c.isActive).toList();
      }

      return courses;
    } catch (e) {
      throw Exception('Failed to get courses: $e');
    }
  }

  // Delete course
  Future<void> deleteCourse({
    required String userId,
    required String courseId,
  }) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(coursesSubcollection)
          .doc(courseId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete course: $e');
    }
  }

  // Create or update assignment
  Future<String> saveAssignment({
    required String userId,
    required Assignment assignment,
  }) async {
    try {
      final assignmentRef = _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(assignmentsSubcollection)
          .doc(assignment.id.isEmpty ? null : assignment.id);

      await assignmentRef.set(assignment.toJson());
      return assignmentRef.id;
    } catch (e) {
      throw Exception('Failed to save assignment: $e');
    }
  }

  // Get all assignments
  Future<List<Assignment>> getUserAssignments({
    required String userId,
    String? courseId,
    bool includeCompleted = true,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(assignmentsSubcollection);

      if (courseId != null) {
        query = query.where('courseId', isEqualTo: courseId);
      }

      if (!includeCompleted) {
        query = query.where('isCompleted', isEqualTo: false);
      }

      final snapshot = await query.get();

      final assignments = snapshot.docs
          .map((doc) => Assignment.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Sort by urgency
      assignments.sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));

      return assignments;
    } catch (e) {
      throw Exception('Failed to get assignments: $e');
    }
  }

  // Mark assignment as completed
  Future<void> completeAssignment({
    required String userId,
    required String assignmentId,
  }) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(assignmentsSubcollection)
          .doc(assignmentId)
          .update({
        'isCompleted': true,
        'completedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to complete assignment: $e');
    }
  }

  // Delete assignment
  Future<void> deleteAssignment({
    required String userId,
    required String assignmentId,
  }) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(assignmentsSubcollection)
          .doc(assignmentId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete assignment: $e');
    }
  }

  // Get upcoming assignments (next 7 days)
  Future<List<Assignment>> getUpcomingAssignments({
    required String userId,
  }) async {
    try {
      final now = DateTime.now();
      final nextWeek = now.add(const Duration(days: 7));

      final snapshot = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(assignmentsSubcollection)
          .where('isCompleted', isEqualTo: false)
          .where('dueDate', 
              isGreaterThanOrEqualTo: now.toIso8601String())
          .where('dueDate', 
              isLessThanOrEqualTo: nextWeek.toIso8601String())
          .get();

      final assignments = snapshot.docs
          .map((doc) => Assignment.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      return assignments;
    } catch (e) {
      throw Exception('Failed to get upcoming assignments: $e');
    }
  }

  // Stream assignments for real-time updates
  Stream<List<Assignment>> streamUserAssignments({
    required String userId,
    bool includeCompleted = true,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(usersCollection)
        .doc(userId)
        .collection(assignmentsSubcollection);

    if (!includeCompleted) {
      query = query.where('isCompleted', isEqualTo: false);
    }

    return query.snapshots().map((snapshot) {
      final assignments = snapshot.docs
          .map((doc) => Assignment.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      assignments.sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));
      return assignments;
    });
  }
}
