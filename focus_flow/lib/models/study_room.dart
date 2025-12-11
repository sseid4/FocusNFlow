class StudyRoom {
  final String id;
  final String name;
  final String building;
  final String roomNumber;
  final int capacity;
  final int currentOccupancy;
  final List<String> amenities; // WiFi, Whiteboard, Projector, etc.
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final bool isAvailable;
  final DateTime? lastUpdated;

  StudyRoom({
    required this.id,
    required this.name,
    required this.building,
    required this.roomNumber,
    required this.capacity,
    this.currentOccupancy = 0,
    this.amenities = const [],
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.isAvailable = true,
    this.lastUpdated,
  });

  factory StudyRoom.fromJson(Map<String, dynamic> json) {
    return StudyRoom(
      id: json['id'] as String,
      name: json['name'] as String,
      building: json['building'] as String,
      roomNumber: json['roomNumber'] as String,
      capacity: json['capacity'] as int,
      currentOccupancy: json['currentOccupancy'] as int? ?? 0,
      amenities: List<String>.from(json['amenities'] ?? []),
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      imageUrl: json['imageUrl'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'building': building,
      'roomNumber': roomNumber,
      'capacity': capacity,
      'currentOccupancy': currentOccupancy,
      'amenities': amenities,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  bool get hasSpace => currentOccupancy < capacity;
  double get occupancyRate => capacity > 0 ? currentOccupancy / capacity : 0;
  int get availableSeats => capacity - currentOccupancy;
}
