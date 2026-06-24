class ServiceOrder {
  final int? id;
  final String clientName;
  final String clientAddress;
  final String? clientPhone;
  final String? description;
  final String status;
  final String? notes;
  final String? serviceCategory;
  final bool preExistingDamage;
  final String? recommendations;
  final String? clientSignature;
  final int userId;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final List<dynamic>? photos;

  ServiceOrder({
    this.id,
    required this.clientName,
    required this.clientAddress,
    this.clientPhone,
    this.description,
    this.status = 'pending',
    this.notes,
    this.serviceCategory,
    this.preExistingDamage = false,
    this.recommendations,
    this.clientSignature,
    required this.userId,
    this.createdAt,
    this.completedAt,
    this.photos,
  });

  factory ServiceOrder.fromJson(Map<String, dynamic> json) {
    return ServiceOrder(
      id: json['id'],
      clientName: json['clientName'] ?? '',
      clientAddress: json['clientAddress'] ?? '',
      clientPhone: json['clientPhone'],
      description: json['description'],
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      serviceCategory: json['serviceCategory'],
      preExistingDamage: json['preExistingDamage'] ?? false,
      recommendations: json['recommendations'],
      clientSignature: json['clientSignature'],
      userId: json['userId'] ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      photos: json['Photos'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientName': clientName,
      'clientAddress': clientAddress,
      'clientPhone': clientPhone,
      'description': description,
      'status': status,
      'notes': notes,
      'serviceCategory': serviceCategory,
      'preExistingDamage': preExistingDamage,
      'recommendations': recommendations,
      'clientSignature': clientSignature,
    };
  }
}
