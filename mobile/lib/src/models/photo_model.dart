class PhotoModel {
  final int? id;
  final int serviceOrderId;
  final String filename;
  final String originalName;
  final String type;
  final double? latitude;
  final double? longitude;
  final String? annotations;
  final DateTime? takenAt;

  PhotoModel({
    this.id,
    required this.serviceOrderId,
    required this.filename,
    required this.originalName,
    required this.type,
    this.latitude,
    this.longitude,
    this.annotations,
    this.takenAt,
  });

  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    return PhotoModel(
      id: json['id'],
      serviceOrderId: json['serviceOrderId'] ?? 0,
      filename: json['filename'] ?? '',
      originalName: json['originalName'] ?? '',
      type: json['type'] ?? 'during',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      annotations: json['annotations']?.toString(),
      takenAt: json['takenAt'] != null ? DateTime.parse(json['takenAt']) : null,
    );
  }
}
