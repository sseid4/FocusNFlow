import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:focusnflow/models/study_room.dart';
import 'package:focusnflow/services/room_service.dart';

class StudyMapScreen extends StatefulWidget {
  const StudyMapScreen({Key? key}) : super(key: key);

  @override
  State<StudyMapScreen> createState() => _StudyMapScreenState();
}

class _StudyMapScreenState extends State<StudyMapScreen> {
  final _roomService = RoomService();
  late Stream<List<StudyRoom>> _roomsStream;
  final MapController _mapController = MapController();

  String _selectedFilter = 'all'; // all, available, full
  List<String> _selectedAmenities = [];
  final List<String> _availableAmenities = ['WiFi', 'Whiteboard', 'Projector', 'Outlets', 'Quiet'];
  bool _showListView = false;

  @override
  void initState() {
    super.initState();
    _roomsStream = _roomService.streamAllRooms();
  }

  List<StudyRoom> _filterRooms(List<StudyRoom> rooms) {
    List<StudyRoom> filtered = rooms;

    // Filter by availability
    if (_selectedFilter == 'available') {
      filtered = filtered.where((room) => room.hasSpace).toList();
    } else if (_selectedFilter == 'full') {
      filtered = filtered.where((room) => !room.hasSpace).toList();
    }

    // Filter by amenities
    if (_selectedAmenities.isNotEmpty) {
      filtered = filtered.where((room) =>
          _selectedAmenities.every((amenity) => room.amenities.contains(amenity))).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Rooms Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(_showListView ? Icons.map : Icons.list),
            onPressed: () {
              setState(() {
                _showListView = !_showListView;
              });
            },
            tooltip: _showListView ? 'Show Map' : 'Show List',
          ),
        ],
      ),
      body: StreamBuilder<List<StudyRoom>>(
        stream: _roomsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No study rooms available'));
          }

          final allRooms = snapshot.data!;
          final filteredRooms = _filterRooms(allRooms);

          if (filteredRooms.isEmpty) {
            return const Center(child: Text('No rooms match your filters'));
          }

          return _showListView
              ? _buildListView(filteredRooms)
              : _buildMapView(filteredRooms);
        },
      ),
    );
  }

  Widget _buildMapView(List<StudyRoom> rooms) {
    // Filter out rooms without coordinates
    final roomsWithCoords = rooms.where((r) => r.latitude != 0 && r.longitude != 0).toList();

    if (roomsWithCoords.isEmpty) {
      return const Center(child: Text('No rooms with location data available'));
    }

    final markers = roomsWithCoords.map((room) {
      final color = room.hasSpace ? Colors.green : Colors.red;
      return Marker(
        point: LatLng(room.latitude, room.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showRoomDetails(context, room),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }).toList();

    // Calculate center point from all rooms
    final centerLat = roomsWithCoords.map((r) => r.latitude).reduce((a, b) => a + b) / roomsWithCoords.length;
    final centerLng = roomsWithCoords.map((r) => r.longitude).reduce((a, b) => a + b) / roomsWithCoords.length;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(centerLat, centerLng),
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: const ['a', 'b', 'c'],
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        // Legend in top-right
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Available', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Full', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView(List<StudyRoom> rooms) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return _buildRoomCard(context, room);
      },
    );
  }

  Widget _buildRoomCard(BuildContext context, StudyRoom room) {
    final occupancyPercent = room.occupancyRate;
    final occupancyColor = occupancyPercent < 0.5
        ? Colors.green
        : occupancyPercent < 0.8
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showRoomDetails(context, room),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room name and building
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${room.building} - Room ${room.roomNumber}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: room.hasSpace ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      room.hasSpace ? 'Available' : 'Full',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Occupancy bar
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Occupancy',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              '${room.currentOccupancy}/${room.capacity}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: occupancyPercent,
                            minHeight: 8,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(occupancyColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Amenities
              if (room.amenities.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: room.amenities.map((amenity) {
                    return Chip(
                      label: Text(amenity),
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Rooms'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Availability',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...['all', 'available', 'full'].map((filter) {
                return RadioListTile<String>(
                  title: Text(filter == 'all'
                      ? 'All Rooms'
                      : filter == 'available'
                          ? 'Available Only'
                          : 'Full Only'),
                  value: filter,
                  groupValue: _selectedFilter,
                  onChanged: (value) {
                    setState(() => _selectedFilter = value!);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
              const SizedBox(height: 16),
              Text(
                'Amenities',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ..._availableAmenities.map((amenity) {
                return CheckboxListTile(
                  title: Text(amenity),
                  value: _selectedAmenities.contains(amenity),
                  onChanged: (value) {
                    setState(() {
                      if (value!) {
                        _selectedAmenities.add(amenity);
                      } else {
                        _selectedAmenities.remove(amenity);
                      }
                    });
                  },
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRoomDetails(BuildContext context, StudyRoom room) {
    final occupancyPercent = room.occupancyRate;
    final occupancyColor = occupancyPercent < 0.5
        ? Colors.green
        : occupancyPercent < 0.8
            ? Colors.orange
            : Colors.red;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with room name and close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.name,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${room.building} - Room ${room.roomNumber}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: room.hasSpace ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        room.hasSpace ? 'Available' : 'Full',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Occupancy Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Occupancy',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${room.currentOccupancy}/${room.capacity} seats occupied',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${(occupancyPercent * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: occupancyColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: occupancyPercent,
                          minHeight: 10,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(occupancyColor),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${room.availableSeats} seats available',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Amenities Section
                if (room.amenities.isNotEmpty) ...[
                  Text(
                    'Amenities',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: room.amenities.map((amenity) {
                      return Chip(
                        label: Text(amenity),
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 13,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // Location Section
                if (room.latitude != 0 && room.longitude != 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${room.latitude.toStringAsFixed(4)}, ${room.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Check-in Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✓ Checked in to ${room.name}'),
                          duration: const Duration(seconds: 3),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Check In to This Room'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // View on Map Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showListView = false;
                      });
                      Navigator.pop(context);
                      _mapController.move(
                        LatLng(room.latitude, room.longitude),
                        17,
                      );
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('View on Map'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
