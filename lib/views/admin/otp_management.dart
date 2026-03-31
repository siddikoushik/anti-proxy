import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OtpManagement extends StatelessWidget {
  const OtpManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('OTP Management', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pending_otps')
            .where('consumed', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Database Error: ${snapshot.error}'),
                    const SizedBox(height: 8),
                    const Text(
                        'Ensure Firebase is correctly configured for this project.',
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No Pending Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text('All faculty OTPs are currently resolved.', style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String userId = doc.id;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.black.withOpacity(0.05))),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                     CircleAvatar(
                                        backgroundColor: Colors.amber.shade50,
                                        foregroundColor: Colors.amber.shade800,
                                        child: const Icon(Icons.person),
                                     ),
                                     const SizedBox(width: 16),
                                     Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                           Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                           Text('ID: $userId', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                        ],
                                     )
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text('Requested: ${(data['requested_at'] as Timestamp?)?.toDate().toString().split('.').first ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (data['otp'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Text(
                                    data['otp'].toString(),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 4, color: Colors.green.shade700, fontFamily: 'monospace'),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Generate Token'),
                                style: OutlinedButton.styleFrom(
                                   foregroundColor: Colors.blue.shade600,
                                   side: BorderSide(color: Colors.blue.shade200),
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _issueOtp(context, userId),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _issueOtp(BuildContext context, String userId) async {
    // Generate simple 6-digit OTP
    String otp = (100000 + (DateTime.now().millisecond * 899))
        .toString()
        .padLeft(6, '0')
        .substring(0, 6);

    try {
      await FirebaseFirestore.instance
          .collection('pending_otps')
          .doc(userId)
          .update({
        'otp': otp,
        'issued_at': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('New OTP issued for $userId: $otp')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error updating OTP: $e'),
            backgroundColor: Colors.red));
      }
    }
  }
}
