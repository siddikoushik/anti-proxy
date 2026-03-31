import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import 'create_session.dart';
import 'qr_generator.dart';
import 'live_attendance.dart';
import '../../models/session_model.dart';
import '../../services/auth_service.dart';

class FacultyHome extends ConsumerStatefulWidget {
  const FacultyHome({super.key});

  @override
  ConsumerState<FacultyHome> createState() => _FacultyHomeState();
}

class _FacultyHomeState extends ConsumerState<FacultyHome> {
  DateTime _selectedDate = DateTime.now();

  Stream<QuerySnapshot>? _getSafeSessionsStream(String? userId, String formattedDate) {
    if (AuthService.isPrototypeMode) return const Stream<QuerySnapshot>.empty();

    try {
      return FirebaseFirestore.instance
          .collection('class_sessions')
          .where('faculty_user_id', isEqualTo: userId)
          .where('date', isEqualTo: formattedDate)
          .snapshots();
    } catch (e) {
      debugPrint("Firestore query skipped in prototype mode");
      return const Stream<QuerySnapshot>.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final formattedFilterDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Generate dates: 7 days back, 7 days forward centered around _selectedDate
    final dates = List.generate(
      15, 
      (index) => _selectedDate.subtract(const Duration(days: 7)).add(Duration(days: index))
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Faculty Schedule', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () {
              ref.read(authServiceProvider).signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSession())),
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
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
                    'Welcome back, ${user.name}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Schedule for ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_month, color: Colors.blueAccent),
                        tooltip: 'Select Specific Date',
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: Colors.blue.shade700, 
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null && picked != _selectedDate) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // HORIZONTAL DATE LIST
                  SizedBox(
                    height: 65,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: dates.length,
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
                stream: _getSafeSessionsStream(user.userId, formattedFilterDate),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SelectableText(
                        'Database Error: ${snapshot.error}\nNote: Check Firestore index if required.',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final sessions = snapshot.data?.docs.map((doc) => 
                    SessionModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)
                  ).toList() ?? [];

                  // Sort by start time if available
                  sessions.sort((a, b) => a.startTime.compareTo(b.startTime));

                  if (sessions.isEmpty) {
                    return Center(
                      child: Text('No sessions scheduled for this date.', 
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16)
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: 80), // Padding for FAB
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _FacultySessionCard(session: session);
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

class _FacultySessionCard extends StatelessWidget {
  final SessionModel session;

  const _FacultySessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final isOpen = session.status == 'open';
    final bgColor = isOpen ? const Color(0xFFE3F2FD) : const Color(0xFFF3F4F6); // Light Blue vs Grey
    final accentColor = isOpen ? const Color(0xFF1976D2) : const Color(0xFF9CA3AF);
    final statusText = isOpen ? 'Active (Open)' : 'Closed';
    final statusIcon = isOpen ? Icons.radio_button_checked : Icons.lock_outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveAttendanceScreen(
                sessionId: session.sessionId,
                section: session.section,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                          style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600),
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
                
                // Second Row: Subject and section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                              color: isOpen ? Colors.blue.shade900 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.groups, size: 16, color: Colors.black54),
                              const SizedBox(width: 4),
                              Text(
                                'Class: ${session.section.toUpperCase()}',
                                style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // QR Code icon if active
                    if (isOpen)
                      IconButton(
                        icon: const Icon(Icons.qr_code_2, size: 36, color: Colors.blueAccent),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QrGeneratorScreen(session: session),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

