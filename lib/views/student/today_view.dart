import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/session_model.dart';
import 'scanner_screen.dart';

class TodayView extends ConsumerWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).value;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dayName = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFF1A2E35), // Dark blue-grey background from screenshot
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 30),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ScannerScreen()),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    dayName,
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        'Your Sessions',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Yesterday', style: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {},
                        child: const Text('History', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('class_sessions')
                    .where('section', isEqualTo: user.section)
                    .where('date', isEqualTo: today)
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
                    return const Center(
                      child: Text('No sessions scheduled for today', style: TextStyle(color: Colors.white70)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _SessionCard(session: session, index: index + 1, userId: user.userId);
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
  final int index;
  final String userId;

  const _SessionCard({required this.session, required this.index, required this.userId});

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
        final isPresent = snapshot.data?.exists ?? false;
        final isClosed = session.status == 'closed';
        
        Color cardColor = const Color(0xFFD9D9D9); // Default grey
        if (isPresent) cardColor = const Color(0xFF9DBD2E); // Green
        else if (isClosed) cardColor = const Color(0xFFE95433); // Red/Orange

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListTile(
            leading: Text(
              '$index',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            title: Text(
              session.subject,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            subtitle: Text(
              'By, Swathi', // Placeholder faculty name if not in model
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            trailing: isPresent 
              ? const Icon(Icons.check, color: Colors.white)
              : isClosed ? const Icon(Icons.close, color: Colors.white) : null,
          ),
        );
      },
    );
  }
}
