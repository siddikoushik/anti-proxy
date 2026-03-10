import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String sessionId;
  final String subject;
  final String section;
  final String facultyUserId;
  final String facultyAuthUid;
  final String date;
  final String timeSlot;
  final DateTime startTime; // Kept for backwards compatibility
  final DateTime endTime;
  final double lat;
  final double lng;
  final double radius;
  final String status; // 'open' or 'closed'
  final DateTime createdAt;

  SessionModel({
    required this.sessionId,
    required this.subject,
    required this.section,
    required this.facultyUserId,
    required this.facultyAuthUid,
    required this.date,
    required this.timeSlot,
    required this.startTime,
    required this.endTime,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.status,
    required this.createdAt,
  });

  factory SessionModel.fromMap(String id, Map<String, dynamic> map) {
    return SessionModel(
      sessionId: id,
      subject: map['subject'] ?? '',
      section: map['section'] ?? '',
      facultyUserId: map['faculty_user_id'] ?? '',
      facultyAuthUid: map['faculty_auth_uid'] ?? '',
      date: map['date'] ?? '',
      timeSlot: map['time_slot'] ?? '',
      startTime: (map['start_time'] as Timestamp).toDate(),
      endTime: (map['end_time'] as Timestamp).toDate(),
      lat: map['location']['lat']?.toDouble() ?? 0.0,
      lng: map['location']['lng']?.toDouble() ?? 0.0,
      radius: map['location']['radius_meters']?.toDouble() ?? 25.0,
      status: map['status'] ?? 'closed',
      createdAt: (map['created_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'section': section,
      'faculty_user_id': facultyUserId,
      'faculty_auth_uid': facultyAuthUid,
      'date': date,
      'time_slot': timeSlot,
      'start_time': Timestamp.fromDate(startTime),
      'end_time': Timestamp.fromDate(endTime),
      'location': {
        'lat': lat,
        'lng': lng,
        'radius_meters': radius,
      },
      'status': status,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
