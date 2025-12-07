import 'package:flutter/material.dart';
import 'package:focusnflow/screens/home/home_screen.dart';
import 'package:focusnflow/screens/map/study_map_screen.dart';
import 'package:focusnflow/screens/groups/study_groups_screen.dart';
import 'package:focusnflow/screens/profile/profile_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String map = '/map';
  static const String groups = '/groups';
  static const String profile = '/profile';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case map:
        return MaterialPageRoute(builder: (_) => const StudyMapScreen());
      case groups:
        return MaterialPageRoute(builder: (_) => const StudyGroupsScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
