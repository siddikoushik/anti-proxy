import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/session_model.dart';
import 'scanner_screen.dart';

class TodayView extends ConsumerStatefulWidget {
  const TodayView({super.key});

  @override
  ConsumerState<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends ConsumerState<TodayView> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final formattedFilterDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Generate dates: 7 days back, 7 days forward
    final dates = List.generate(
      15, 
      (index) => DateTime.now().subtract(const Duration(days: 7)).add(Duration(days: index))
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9), // Light background to match screenshot vibe better, or stick to white
      appBar: AppBar(
        title: const Text('Academic Planning', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello ${user.name}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Viewing schedule for ${DateFormat('MMM d').format(_selectedDate)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  // HORIZONTAL DATE LIST
                  SizedBox(
                    height: 65,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: dates.length,
                      // Jump near center:
                      itemBuilder: (context, index) {
                        final date = dates[index];
                        final isSelected = date.year == _selectedDate.year &&
                            date.month == _selectedDate.month &&
                            date.day == _selectedDate.day;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedDate = date),
                          child: Container(
                            width: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.shade50 : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('E').format(date).toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  DateFormat('d').format(date),
                                  style: TextStyle(
                                    color: isSelected ? Colors.blue.shade600 : Colors.black87,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 30),
                ],
              ),
            ),
            
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('class_sessions')
                    .where('section', isEqualTo: user.section)
                    .where('date', isEqualTo: formattedFilterDate)
                    .orderBy('start_time', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final sessions = snapshot.data?.docs.map((doc) => 
                    SessionModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)
                  ).toList() ?? [];

                  if (sessions.isEmpty) {
                    return Center(
                      child: Text('No lectures scheduled for this date.', 
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16)
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _SessionCard(session: session, userId: user.userId);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionModel session;
  final String userId;

  const _SessionCard({required this.session, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('class_sessions')
          .doc(session.sessionId)
          .collection('attendance')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        final isPresent = snapshot.hasData && snapshot.data!.exists && (snapshot.data!.data() as Map<String, dynamic>?)?['status'] == 'present';
        final isAbsent = snapshot.hasData && snapshot.data!.exists && (snapshot.data!.data() as Map<String, dynamic>?)?['status'] == 'absent';
        final isClosed = session.status == 'closed';
        
        // Determine the card style based on state
        Color bgColor = const Color(0xFFFEF3E2); // Default Cream (Not yet updated)
        Color accentColor = const Color(0xFFE5A93D); // Orange Accent
        String statusText = 'Not Yet Updated';
        IconData statusIcon = Icons.hourglass_empty;

        if (isPresent) {
          bgColor = const Color(0xFFE8F5E9); // Light Green
          accentColor = const Color(0xFF4CAF50); // Green Accent
          statusText = 'Present';
          statusIcon = Icons.check_circle_outline;
        } else if (isAbsent || isClosed) {
          bgColor = const Color(0xFFF3F4F6); // Light Grey
          accentColor = const Color(0xFF9CA3AF); // Grey Accent
          statusText = 'Absent';
          statusIcon = Icons.cancel_outlined;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Time and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Row(
                     children: [
                       const Icon(Icons.access_time, size: 16, color: Colors.black54),
                       const SizedBox(width: 6),
                       Text(
                         session.timeSlot,
                         style: const TextStyle(fontSize: 14, color: Colors.black87),
                       ),
                     ],
                   ),
                   Row(
                     children: [
                       Icon(statusIcon, size: 16, color: accentColor),
                       const SizedBox(width: 4),
                       Text(
                         statusText,
                         style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                       ),
                     ],
                   ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Second Row: Subject and inline scanner
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.subject.toUpperCase(),
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold, 
                            color: accentColor == const Color(0xFFE5A93D) ? Colors.orange.shade800 : accentColor // slight text darkening for orange
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.section.toUpperCase(),
                          style: const TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.black54),
                            const SizedBox(width: 6),
                            Text(
                              'Faculty ID: ${session.facultyUserId}',
                              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Inline Scanner Button
                  if (!isPresent && !isClosed)
                    InkWell(
                      onTap: () {
                         Navigator.push(
                           context,
                           MaterialPageRoute(builder: (_) => const ScannerScreen()),
                         );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: const Icon(Icons.qr_code_scanner, color: Colors.blueAccent, size: 30),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
