import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focusnflow/screens/groups/study_groups_screen.dart';
import 'package:focusnflow/screens/map/study_map_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final CollectionReference studyRoomsRef =
      FirebaseFirestore.instance.collection('studyRooms');

  LatLng calculateCenter(List<LatLng> locations) {
    if (locations.isEmpty) return LatLng(0, 0);
    double latSum = 0, lngSum = 0;
    for (var loc in locations) {
      latSum += loc.latitude;
      lngSum += loc.longitude;
    }
    return LatLng(latSum / locations.length, lngSum / locations.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to FocusNFlow GSU!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Study better by collaborating with your peers! Find available study groups that align with your workload and meet with members."
              ),
              const SizedBox(height: 16),

              // Mini map
              SizedBox(
                height: 400,
                width: 400,
                child: StreamBuilder<QuerySnapshot>(
                  stream: studyRoomsRef.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Error loading map'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final rooms = snapshot.data!.docs;
                    if (rooms.isEmpty) {
                      return const Center(child: Text('No study rooms available'));
                    }

                    // Convert Firestore documents to LatLng markers
                    final List<LatLng> locations = rooms.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final lat = (data['latitude'] ?? 0.0).toDouble();
                      final lng = (data['longitude'] ?? 0.0).toDouble();
                      return LatLng(lat, lng);
                    }).toList();

                    return FlutterMap(
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
                                    SnackBar(
                                      content:
                                          Text('Study Room at ${loc.latitude}, ${loc.longitude}'),
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 30,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
              ),


              const SizedBox(height: 32),

              // Navigation buttons
              const Text(
                'Get Started:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const StudyMapScreen()),
                      );
                    },
                    child: const Text('Find Study Rooms'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const StudyGroupsScreen()),
                      );
                    },
                    child: const Text('My Study Groups'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
