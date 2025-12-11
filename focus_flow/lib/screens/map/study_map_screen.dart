import 'package:flutter/material.dart';
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
  
  String _selectedFilter = 'all'; // all, available, full
  List<String> _selectedAmenities = [];
  final List<String> _availableAmenities = ['WiFi', 'Whiteboard', 'Projector', 'Outlets', 'Quiet'];

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
        title: const Text('Study Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
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

          return filteredRooms.isEmpty
              ? const Center(child: Text('No rooms match your filters'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredRooms.length,
                  itemBuilder: (context, index) {
                    final room = filteredRooms[index];
                    return _buildRoomCard(context, room);
                  },
                );
        },
      ),
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
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${room.building} Room ${room.roomNumber}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Capacity: ${room.capacity} • Available: ${room.availableSeats}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: room.occupancyRate,
              minHeight: 8,
            ),
            const SizedBox(height: 16),
            if (room.amenities.isNotEmpty) ...[
              Text(
                'Amenities',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: room.amenities
                    .map((a) => Chip(label: Text(a)))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Checked in to ${room.name}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('Check In'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
