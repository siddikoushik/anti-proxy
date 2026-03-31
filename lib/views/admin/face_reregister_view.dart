import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/class_model.dart';
import '../../services/class_service.dart';

class FaceReregisterView extends ConsumerStatefulWidget {
  const FaceReregisterView({super.key});

  @override
  ConsumerState<FaceReregisterView> createState() => _FaceReregisterViewState();
}

class _FaceReregisterViewState extends ConsumerState<FaceReregisterView> {
  String? _selectedYear;
  String? _selectedBranch;
  String? _selectedSection;

  Future<void> _wipeFaceData(String userId, String userName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force Re-Registration?'),
        content: Text('This will instantly invalidate the face data for $userName. They will be locked out of the student dashboard until they take a new selfie. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Invalidate Selfie', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'face_registered': false,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text('Successfully invalidated face data for $userName'),
           backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text('Error: $e'),
           backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classService = ref.watch(classServiceProvider);

    final String targetSection = '$_selectedYear-$_selectedBranch-$_selectedSection';
    final bool canSearch = _selectedYear != null && _selectedBranch != null && _selectedSection != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Face Re-Registration', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.face_retouching_natural_rounded, color: Colors.pink, size: 28),
                    const SizedBox(width: 12),
                    const Text('Select Target Class', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Choose a class to view its roster. You can individually force students to register a new selfie.', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 24),
                StreamBuilder<List<ClassModel>>(
                  stream: classService.getClasses(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final classes = snapshot.data!;
                    
                    final years = classes.map((c) => c.year).toSet().toList()..sort();
                    if (_selectedYear != null && !years.contains(_selectedYear)) {
                      _selectedYear = null; _selectedBranch = null; _selectedSection = null;
                    }
                    
                    final branches = _selectedYear != null
                        ? (classes.where((c) => c.year == _selectedYear).map((c) => c.branch).toSet().toList()..sort())
                        : <String>[];
                    if (_selectedBranch != null && !branches.contains(_selectedBranch)) {
                      _selectedBranch = null; _selectedSection = null;
                    }

                    final sections = (_selectedYear != null && _selectedBranch != null)
                        ? (classes.where((c) => c.year == _selectedYear && c.branch == _selectedBranch).map((c) => c.section).toSet().toList()..sort())
                        : <String>[];
                    if (_selectedSection != null && !sections.contains(_selectedSection)) {
                      _selectedSection = null;
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedYear,
                            decoration: InputDecoration(labelText: 'Year', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                            items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList()..insert(0, const DropdownMenuItem(value: null, child: Text('All'))),
                            onChanged: (val) => setState(() {
                              _selectedYear = val;
                              _selectedBranch = null;
                              _selectedSection = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedBranch,
                            decoration: InputDecoration(labelText: 'Branch', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                            items: branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList()..insert(0, const DropdownMenuItem(value: null, child: Text('All'))),
                            onChanged: _selectedYear != null ? (val) => setState(() {
                              _selectedBranch = val;
                              _selectedSection = null;
                            }) : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedSection,
                            decoration: InputDecoration(labelText: 'Section', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                            items: sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList()..insert(0, const DropdownMenuItem(value: null, child: Text('All'))),
                            onChanged: _selectedBranch != null ? (val) => setState(() => _selectedSection = val) : null,
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Student List
          Expanded(
             child: !canSearch 
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rule_rounded, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Select a fully specific class to load its students', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                    ],
                  ),
                )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').where('section', isEqualTo: targetSection).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                         return const Center(child: CircularProgressIndicator());
                      }
                      final students = snapshot.data?.docs ?? [];
                      if (students.isEmpty) {
                         return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off_rounded, size: 80, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('No students found in this class.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                            ],
                          ),
                        );
                      }
                      return Center(
                         child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: ListView.builder(
                               padding: const EdgeInsets.all(24),
                               itemCount: students.length,
                               itemBuilder: (context, index) {
                                  final data = students[index].data() as Map<String, dynamic>;
                                  final userId = students[index].id;
                                  final userName = data['name'] ?? 'Unknown';
                                  final bool isRegistered = data['face_registered'] ?? false;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.black.withOpacity(0.05))),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: isRegistered ? Colors.green.shade50 : Colors.red.shade50,
                                                  foregroundColor: isRegistered ? Colors.green : Colors.red,
                                                  radius: 24,
                                                  child: Icon(isRegistered ? Icons.face : Icons.no_photography_rounded),
                                                ),
                                                const SizedBox(width: 16),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                    Text('ID: $userId', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                                    const SizedBox(height: 4),
                                                    Container(
                                                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                       decoration: BoxDecoration(
                                                          color: isRegistered ? Colors.green.shade50 : Colors.red.shade50,
                                                          borderRadius: BorderRadius.circular(8),
                                                       ),
                                                       child: Text(
                                                          isRegistered ? 'Face Registered' : 'Needs Registration',
                                                          style: TextStyle(color: isRegistered ? Colors.green.shade700 : Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                                                       ),
                                                    )
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.delete_forever_rounded, size: 18),
                                            label: const Text('Wipe Face'),
                                            style: OutlinedButton.styleFrom(
                                               foregroundColor: Colors.pink.shade600,
                                               side: BorderSide(color: Colors.pink.shade200),
                                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: isRegistered ? () => _wipeFaceData(userId, userName) : null,
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
          ),
        ],
      )
    );
  }
}
