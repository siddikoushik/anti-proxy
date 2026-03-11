import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/session_model.dart';

class SubjectsView extends ConsumerWidget {
  const SubjectsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).value;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFF1A2E35), // Dark blue-grey background
      appBar: AppBar(
        title: const Text('Subjects', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _calculateAttendance(user.section ?? '', user.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data ?? {};
          final overallPercentage = stats['overall'] ?? 0.0;
          final subjectWise = stats['subjects'] as Map<String, dynamic>? ?? {};

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverallAttendance(overallPercentage),
                const SizedBox(height: 32),
                const Text(
                  'Subject wise',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: subjectWise.length,
                    itemBuilder: (context, index) {
                      final subject = subjectWise.keys.elementAt(index);
                      final percentage = subjectWise[subject] as double? ?? 0.0;
                      return _buildSubjectCard(subject, percentage);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverallAttendance(double percentage) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overall Attendance', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              CircularProgressIndicator(
                value: percentage,
                strokeWidth: 8,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(_getAttendanceColor(percentage)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(String subject, double percentage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              subject,
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
          Text(
            '${(percentage * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: _getAttendanceColor(percentage)
            ),
          ),
        ],
      ),
    );
  }

  Color _getAttendanceColor(double percentage) {
    if (percentage >= 0.75) return const Color(0xFF9DBD2E); // Green
    if (percentage >= 0.5) return Colors.orange;
    return const Color(0xFFE95433); // Red
  }

  Future<Map<String, dynamic>> _calculateAttendance(String section, String userId) async {
    // 1. Fetch sessions for this section
    final sessionsQuery = await FirebaseFirestore.instance
        .collection('class_sessions')
        .where('section', isEqualTo: section)
        .where('status', isEqualTo: 'closed')
        .get();

    final sessionsBySubject = <String, List<String>>{};
    for (var doc in sessionsQuery.docs) {
      final subject = doc['subject'] as String;
      if (!sessionsBySubject.containsKey(subject)) {
        sessionsBySubject[subject] = [];
      }
      sessionsBySubject[subject]!.add(doc.id);
    }

    // 2. Fetch all present marks for this user
    // We'll need to check each session's attendance subcollection
    // Alternatively, we could query for attendance marks where studentUserId == userId across ALL sessions if indexed
    // Since we don't have a cross-session attendance index, we'll iterate through sessions.

    double totalPresent = 0;
    double totalSessions = 0;
    final subjectStats = <String, double>{};

    for (var subject in sessionsBySubject.keys) {
      final sessionIds = sessionsBySubject[subject]!;
      double subjectPresent = 0;
      
      for (var sid in sessionIds) {
        final attendanceDoc = await FirebaseFirestore.instance
            .collection('class_sessions')
            .doc(sid)
            .collection('attendance')
            .doc(userId)
            .get();
        
        if (attendanceDoc.exists) {
          subjectPresent++;
          totalPresent++;
        }
        totalSessions++;
      }
      
      subjectStats[subject] = subjectPresent / sessionIds.length;
    }

    return {
      'overall': totalSessions > 0 ? totalPresent / totalSessions : 0.0,
      'subjects': subjectStats,
    };
  }
}
