import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/class_model.dart';
import '../../services/class_service.dart';

class AnalyticsView extends ConsumerStatefulWidget {
  const AnalyticsView({super.key});

  @override
  ConsumerState<AnalyticsView> createState() => _AnalyticsViewState();
}

class StudentAnalytics {
  final String id;
  final String name;
  final String section;
  int presentCount = 0;
  int totalSessions = 0;

  StudentAnalytics({required this.id, required this.name, required this.section});

  double get attendancePercentage => totalSessions == 0 ? 0 : (presentCount / totalSessions) * 100;
}

enum AttendanceFilter { all, below65, below75, above75 }

class _AnalyticsViewState extends ConsumerState<AnalyticsView> {
  bool _isLoading = true;
  AttendanceFilter _selectedFilter = AttendanceFilter.all;
  
  String? _selectedYear;
  String? _selectedBranch;
  String? _selectedSection;

  List<StudentAnalytics> _analyticsData = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch all students
      final usersSnap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').get();
      Map<String, StudentAnalytics> studentMap = {};
      for (var doc in usersSnap.docs) {
        final data = doc.data();
        studentMap[doc.id] = StudentAnalytics(
          id: doc.id,
          name: data['name'] ?? 'Unknown',
          section: data['section'] ?? 'Unassigned',
        );
      }

      // Fetch closed sessions and attendance
      final sessionsSnap = await FirebaseFirestore.instance.collection('class_sessions').where('status', isEqualTo: 'closed').get();
      for (var sessionDoc in sessionsSnap.docs) {
        final attendanceSnap = await sessionDoc.reference.collection('attendance').get();
        for (var attDoc in attendanceSnap.docs) {
          final studentId = attDoc.id;
          final status = attDoc.data()['status'];
          if (studentMap.containsKey(studentId)) {
            studentMap[studentId]!.totalSessions += 1;
            if (status == 'present') {
              studentMap[studentId]!.presentCount += 1;
            }
          }
        }
      }

      setState(() {
        _analyticsData = studentMap.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generatePdf(List<StudentAnalytics> data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Attendance Analytics Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Generated on: ${DateTime.now().toIso8601String().split('T')[0]}'),
              pw.Text('Filters: Year: ${_selectedYear ?? 'All'}, Branch: ${_selectedBranch ?? 'All'}, Section: ${_selectedSection ?? 'All'}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Roll No', 'Name', 'Section', 'Total', 'Present', '%'],
                data: data.map((s) => [
                  s.id,
                  s.name,
                  s.section,
                  s.totalSessions.toString(),
                  s.presentCount.toString(),
                  '${s.attendancePercentage.toStringAsFixed(1)}%'
                ]).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classService = ref.watch(classServiceProvider);

    List<StudentAnalytics> filteredData = _analyticsData.where((s) {
      List<String> parts = s.section.split('-');
      String sy = parts.isNotEmpty ? parts[0] : '';
      String sb = parts.length > 1 ? parts[1] : '';
      String ss = parts.length > 2 ? parts[2] : '';

      if (_selectedYear != null && _selectedYear != sy) return false;
      if (_selectedBranch != null && _selectedBranch != sb) return false;
      if (_selectedSection != null && _selectedSection != ss) return false;

      if (_selectedFilter == AttendanceFilter.below65 && s.attendancePercentage >= 65.0) return false;
      if (_selectedFilter == AttendanceFilter.below75 && s.attendancePercentage >= 75.0) return false;
      if (_selectedFilter == AttendanceFilter.above75 && s.attendancePercentage < 75.0) return false;
      
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export as PDF',
            onPressed: () => _generatePdf(filteredData),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Class Dropdowns in a Row
                    StreamBuilder<List<ClassModel>>(
                      stream: classService.getClasses(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
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
                                decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList()..insert(0, const DropdownMenuItem(value: null, child: Text('All'))),
                                onChanged: (val) => setState(() {
                                  _selectedYear = val;
                                  _selectedBranch = null;
                                  _selectedSection = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedBranch,
                                decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                items: branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList()..insert(0, const DropdownMenuItem(value: null, child: Text('All'))),
                                onChanged: _selectedYear != null ? (val) => setState(() {
                                  _selectedBranch = val;
                                  _selectedSection = null;
                                }) : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedSection,
                                decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                items: sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList()..insert(0, const DropdownMenuItem(value: null, child: Text('All'))),
                                onChanged: _selectedBranch != null ? (val) => setState(() => _selectedSection = val) : null,
                              ),
                            ),
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 16),
                    // Filter Chips
                    Wrap(
                      spacing: 8.0,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _selectedFilter == AttendanceFilter.all,
                          onSelected: (val) => setState(() => _selectedFilter = AttendanceFilter.all),
                        ),
                        ChoiceChip(
                          label: const Text('< 65%'),
                          selected: _selectedFilter == AttendanceFilter.below65,
                          selectedColor: Colors.red.withValues(alpha: 0.2),
                          onSelected: (val) => setState(() => _selectedFilter = AttendanceFilter.below65),
                        ),
                        ChoiceChip(
                          label: const Text('< 75%'),
                          selected: _selectedFilter == AttendanceFilter.below75,
                          selectedColor: Colors.orange.withValues(alpha: 0.2),
                          onSelected: (val) => setState(() => _selectedFilter = AttendanceFilter.below75),
                        ),
                        ChoiceChip(
                          label: const Text('>= 75%'),
                          selected: _selectedFilter == AttendanceFilter.above75,
                          selectedColor: Colors.green.withValues(alpha: 0.2),
                          onSelected: (val) => setState(() => _selectedFilter = AttendanceFilter.above75),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Roll No')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Section')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('Present')),
                        DataColumn(label: Text('%')),
                      ],
                      rows: filteredData.map((s) {
                        final color = s.attendancePercentage < 65.0 
                            ? Colors.red 
                            : (s.attendancePercentage < 75.0 ? Colors.orange : Colors.green);
                        return DataRow(cells: [
                          DataCell(Text(s.id)),
                          DataCell(Text(s.name)),
                          DataCell(Text(s.section)),
                          DataCell(Text(s.totalSessions.toString())),
                          DataCell(Text(s.presentCount.toString())),
                          DataCell(Text(
                            '${s.attendancePercentage.toStringAsFixed(1)}%',
                            style: TextStyle(color: color, fontWeight: FontWeight.bold),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _generatePdf(filteredData),
        icon: const Icon(Icons.download),
        label: const Text('Download PDF'),
      ),
    );
  }
}
