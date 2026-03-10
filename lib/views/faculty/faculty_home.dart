import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'create_session.dart';
import 'qr_generator.dart';
import 'live_attendance.dart';
import '../../models/session_model.dart';
import '../../services/auth_service.dart';

class FacultyHome extends ConsumerWidget {
  const FacultyHome({super.key});

  Stream<QuerySnapshot>? _getSafeSessionsStream(String? userId) {
    if (AuthService.isPrototypeMode) return const Stream<QuerySnapshot>.empty();

    try {
      return FirebaseFirestore.instance
          .collection('class_sessions')
          .where('faculty_user_id', isEqualTo: userId)
          .snapshots();
    } catch (e) {
      debugPrint("Firestore query skipped in prototype mode");
      return const Stream<QuerySnapshot>.empty();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authServiceProvider).signOut();
              Navigator.pop(context); // Go back to login
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getSafeSessionsStream(user?.userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                'Database Error: ${snapshot.error}\nIf this says missing index, please click the link in your web console.',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data?.docs.toList() ?? [];
          sessions.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['created_at'] as Timestamp?;
            final bTime = bData['created_at'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // Descending
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CreateSession())),
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Session'),
                ),
              ),
              Expanded(
                child: sessions.isEmpty
                    ? const Center(child: Text('No sessions created yet'))
                    : ListView.builder(
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = SessionModel.fromMap(
                              sessions[index].id,
                              sessions[index].data() as Map<String, dynamic>);
                          return ListTile(
                            title:
                                Text('${session.subject} - ${session.section}'),
                            subtitle:
                                Text('Status: ${session.status.toUpperCase()}'),
                            trailing: session.status == 'open'
                                ? IconButton(
                                    icon: const Icon(Icons.qr_code,
                                        color: Colors.blue),
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => QrGeneratorScreen(
                                                session: session))),
                                  )
                                : null,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => LiveAttendanceScreen(
                                        sessionId: session.sessionId,
                                        section: session.section))),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
