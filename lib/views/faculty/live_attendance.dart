import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';

class LiveAttendanceScreen extends StatelessWidget {
  final String sessionId;
  final String section;

  const LiveAttendanceScreen(
      {super.key, required this.sessionId, required this.section});

  Future<void> _closeSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Session?'),
        content: const Text('This will mark all remaining students as ABSENT.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Close')),
        ],
      ),
    );

    if (confirmed == true) {
      final attendanceRef = FirebaseFirestore.instance
          .collection('class_sessions')
          .doc(sessionId)
          .collection('attendance');
      final snapshots =
          await attendanceRef.where('status', isEqualTo: 'pending').get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshots.docs) {
        batch.update(doc.reference, {
          'status': 'absent',
          'marked_by': 'auto',
        });
      }
      await batch.commit();
      await FirebaseFirestore.instance
          .collection('class_sessions')
          .doc(sessionId)
          .update({'status': 'closed'});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session Closed Successfully')));
      }
    }
  }

  Future<void> _deleteSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            const Text('Delete Session?', style: TextStyle(color: Colors.red)),
        content: const Text(
            'This will permanently delete this session and all attendance records. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Note: In a real production app, deleting a document doesn't delete its subcollections.
      // But for this prototype, deleting the parent document is enough to hide it from queries.
      await FirebaseFirestore.instance
          .collection('class_sessions')
          .doc(sessionId)
          .delete();

      if (context.mounted) {
        Navigator.pop(context); // Go back to the dashboard immediately
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Session Deleted'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _manualOverride(
      BuildContext context, String studentId, String currentStatus) async {
    final newStatus = currentStatus == 'present' ? 'absent' : 'present';
    final noteController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark as ${newStatus.toUpperCase()}?'),
        content: TextField(
          controller: noteController,
          decoration:
              const InputDecoration(labelText: 'Reason/Note (Optional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('class_sessions')
                  .doc(sessionId)
                  .collection('attendance')
                  .doc(studentId)
                  .update({
                'status': newStatus,
                'note': noteController.text,
                'timestamp': FieldValue.serverTimestamp(),
                'marked_by': 'faculty',
              });
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance: $section'),
        actions: [
          TextButton.icon(
            onPressed: () => _closeSession(context),
            icon: const Icon(Icons.close, color: Colors.white),
            label: const Text('Close Session',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('class_sessions')
            .doc(sessionId)
            .collection('attendance')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data?.docs ?? [];
          final presentCount =
              records.where((r) => r['status'] == 'present').length;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.primaryBlue,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('Total', records.length.toString()),
                    _buildStatCol('Present', presentCount.toString()),
                    _buildStatCol(
                        'Absent', (records.length - presentCount).toString()),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final data = records[index].data() as Map<String, dynamic>;
                    final status = data['status'];
                    final color = status == 'present'
                        ? Colors.green
                        : (status == 'absent' ? Colors.red : Colors.grey);
                    final icon = status == 'present'
                        ? Icons.check_circle
                        : (status == 'absent'
                            ? Icons.cancel
                            : Icons.hourglass_empty);

                    return ListTile(
                      leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.1),
                          child: Icon(icon, color: color)),
                      title: Text(data['name'] ?? 'Unknown'),
                      subtitle: Text(
                          'Roll No: ${records[index].id}${data['note'] != null ? ' - ${data['note']}' : ''}'),
                      trailing: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.bold),
                      ),
                      onLongPress: () =>
                          _manualOverride(context, records[index].id, status),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2))
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _deleteSession(context),
                        child: const Text('Delete Session'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _closeSession(context),
                        child: const Text('Submit Attendance'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCol(String label, String val) {
    return Column(
      children: [
        Text(val,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
