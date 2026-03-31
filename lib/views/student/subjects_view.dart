import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class CourseStats {
  final String subjectName;
  int present = 0;
  int absent = 0;
  int notUpdated = 0;

  CourseStats(this.subjectName);

  int get totalMarked => present + absent;
  double get attendancePercentage => totalMarked == 0 ? 0.0 : (present / totalMarked);
}

class SubjectsView extends ConsumerWidget {
  const SubjectsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).value;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Academic Planning', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _calculateAttendance(user.section ?? '', user.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          final data = snapshot.data ?? {};
          final totalPresent = data['totalPresent'] as int? ?? 0;
          final totalAbsent = data['totalAbsent'] as int? ?? 0;
          final totalNotUpdated = data['totalNotUpdated'] as int? ?? 0;
          final totalMarked = totalPresent + totalAbsent;
          final overallPercentage = totalMarked == 0 ? 0.0 : (totalPresent / totalMarked);
          
          final subjectStats = data['subjectStats'] as List<CourseStats>? ?? [];
          
          // Fallback UI rendering colors
          const Color blueColor = Color(0xFF4285F4);
          const Color orangeColor = Color(0xFFE37A2F);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOP HEADER: Donut Chart and Overview
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Row(
                    children: [
                      // Donut Chart
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CustomPaint(
                          painter: _DonutChartPainter(
                            present: totalPresent,
                            absent: totalAbsent,
                            presentColor: blueColor,
                            absentColor: orangeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      
                      // Stat Breakdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.section?.toUpperCase() ?? 'SECTION',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF4A4E69)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Average Attendance ${(overallPercentage * 100).toStringAsFixed(2)} %',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                            const SizedBox(height: 12),
                            
                            // Present row
                            Row(
                              children: [
                                const CircleAvatar(radius: 5, backgroundColor: blueColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Present $totalPresent / $totalMarked | ${(overallPercentage * 100).toStringAsFixed(2)}%',
                                    style: const TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Absent row
                            Row(
                              children: [
                                const CircleAvatar(radius: 5, backgroundColor: orangeColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Absent $totalAbsent / $totalMarked | ${totalMarked == 0 ? '0.00' : ((totalAbsent / totalMarked) * 100).toStringAsFixed(2)}%',
                                    style: const TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '[ Not Updated $totalNotUpdated ]',
                              style: const TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // COURSE LIST TITLE
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Course List', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('${subjectStats.length} Courses', style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),

                // COURSE CARDS
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: subjectStats.length,
                  itemBuilder: (context, index) {
                    final stats = subjectStats[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stats.subjectName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF4A4E69)),
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Icon(Icons.menu_book, size: 16, color: Colors.black38),
                              SizedBox(width: 8),
                              Text('Theory | Regular', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.co_present, size: 16, color: Colors.black38),
                              const SizedBox(width: 8),
                              Text(
                                'Attendance : ${stats.present} / ${stats.totalMarked} | ${(stats.attendancePercentage * 100).toStringAsFixed(2)}%',
                                style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _calculateAttendance(String section, String userId) async {
    // Fetch all sessions for this section
    final sessionsQuery = await FirebaseFirestore.instance
        .collection('class_sessions')
        .where('section', isEqualTo: section)
        .get();

    final Map<String, CourseStats> statsMap = {};
    int totalPresent = 0;
    int totalAbsent = 0;
    int totalNotUpdated = 0;

    for (var doc in sessionsQuery.docs) {
      final subject = doc['subject'] as String;
      final sessionStatus = doc['status'] as String? ?? 'closed';
      final sessionId = doc.id;

      if (!statsMap.containsKey(subject)) {
        statsMap[subject] = CourseStats(subject);
      }
      final courseStats = statsMap[subject]!;

      // Fetch student attendance document
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('class_sessions')
          .doc(sessionId)
          .collection('attendance')
          .doc(userId)
          .get();

      if (attendanceDoc.exists) {
        final status = attendanceDoc.data()?['status'] as String?;
        if (status == 'present') {
          totalPresent++;
          courseStats.present++;
        } else if (status == 'absent') {
          // If the session is still "open", student is technically "Not Updated" because they could still scan
          // or the faculty hasn't closed the session yet.
          if (sessionStatus == 'open') {
            totalNotUpdated++;
            courseStats.notUpdated++;
          } else {
            totalAbsent++;
            courseStats.absent++;
          }
        } else {
          totalNotUpdated++;
          courseStats.notUpdated++;
        }
      } else {
        totalNotUpdated++;
        courseStats.notUpdated++;
      }
    }

    final sortedSubjects = statsMap.values.toList()..sort((a, b) => b.attendancePercentage.compareTo(a.attendancePercentage));

    return {
      'totalPresent': totalPresent,
      'totalAbsent': totalAbsent,
      'totalNotUpdated': totalNotUpdated,
      'subjectStats': sortedSubjects,
    };
  }
}

class _DonutChartPainter extends CustomPainter {
  final int present;
  final int absent;
  final Color presentColor;
  final Color absentColor;

  _DonutChartPainter({
    required this.present,
    required this.absent,
    required this.presentColor,
    required this.absentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (present == 0 && absent == 0) {
      // Draw empty grey ring if no data
      final paint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.butt;
      
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - 10, paint);
      return;
    }

    final double total = (present + absent).toDouble();
    final double presentSweepAngle = (present / total) * 2 * pi;
    final double absentSweepAngle = (absent / total) * 2 * pi;
    
    final Rect rect = Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2 - 10);
    
    // Draw Absent (Orange)
    final Paint absentPaint = Paint()
      ..color = absentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.butt;
      
    // Start angle: top is -pi/2
    canvas.drawArc(rect, -pi / 2, absentSweepAngle, false, absentPaint);

    // Draw Present (Blue)
    final Paint presentPaint = Paint()
      ..color = presentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.butt;
      
    // Start after absent
    canvas.drawArc(rect, -pi / 2 + absentSweepAngle, presentSweepAngle, false, presentPaint);
    
    // Draw separator lines if both exist
    if (present > 0 && absent > 0) {
      final Paint separatorPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
        
      // Draw separator at top
      canvas.drawArc(rect, -pi / 2 - 0.05, 0.1, false, separatorPaint);
      // Draw separator at boundary
      canvas.drawArc(rect, -pi / 2 + absentSweepAngle - 0.05, 0.1, false, separatorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.present != present || oldDelegate.absent != absent;
  }
}
