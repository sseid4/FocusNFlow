import 'package:flutter/material.dart';
import 'package:focusnflow/screens/auth/auth_gate.dart';
import 'package:focusnflow/screens/home/home_screen.dart';
import 'package:focusnflow/screens/map/study_map_screen.dart';
import 'package:focusnflow/screens/groups/study_groups_screen.dart';
import 'package:focusnflow/screens/profile/profile_screen.dart';
import 'package:focusnflow/screens/profile/analytics_dashboard_screen.dart';
import 'package:focusnflow/screens/profile/course_management_screen.dart';
import 'package:focusnflow/screens/profile/personalized_schedule_screen.dart';

class AppRoutes {
  static const String auth = '/';
  static const String home = '/home';
  static const String map = '/map';
  static const String groups = '/groups';
  static const String profile = '/profile';
  static const String analytics = '/analytics';
  static const String courseManagement = '/course-management';
  static const String personalizedSchedule = '/personalized-schedule';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case auth:
        return MaterialPageRoute(builder: (_) => const AuthGate());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case map:
        return MaterialPageRoute(builder: (_) => const StudyMapScreen());
      case groups:
        return MaterialPageRoute(builder: (_) => const StudyGroupsScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case analytics:
        return MaterialPageRoute(builder: (_) => const AnalyticsDashboardScreen());
      case courseManagement:
        return MaterialPageRoute(
          builder: (_) => const CourseManagementScreen(),
        );
      case personalizedSchedule:
        return MaterialPageRoute(
          builder: (_) => const PersonalizedScheduleScreen(),
        );
      default:
        return MaterialPageRoute(builder: (_) => const AuthGate());
    }
  }
}
