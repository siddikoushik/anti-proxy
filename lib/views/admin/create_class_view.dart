import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/class_model.dart';
import '../../services/class_service.dart';

class CreateClassView extends ConsumerStatefulWidget {
  const CreateClassView({super.key});

  @override
  ConsumerState<CreateClassView> createState() => _CreateClassViewState();
}

class _CreateClassViewState extends ConsumerState<CreateClassView> {
  String? _selectedYear;
  String? _selectedBranch;
  String? _selectedSection;
  
  void _showAddEditDialog(List<ClassModel> allClasses, [ClassModel? existingClass]) {
    final yearController = TextEditingController(text: existingClass?.year);
    final branchController = TextEditingController(text: existingClass?.branch);
    final sectionController = TextEditingController(text: existingClass?.section);
    final isEditing = existingClass != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Class' : 'Create Class'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: yearController,
                  decoration: const InputDecoration(labelText: 'Year / Grade'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: branchController,
                  decoration: const InputDecoration(labelText: 'Branch / Course'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sectionController,
                  decoration: const InputDecoration(labelText: 'Section'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Strict normalization to prevent duplicates
                final year = yearController.text.trim().toUpperCase();
                final branch = branchController.text.trim().toUpperCase();
                final section = sectionController.text.trim().toUpperCase();

                if (year.isEmpty || branch.isEmpty || section.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All fields are required.')),
                  );
                  return;
                }

                // Check for duplicates
                bool isDuplicate = allClasses.any((c) {
                  if (isEditing && c.id == existingClass.id) return false;
                  return c.year == year && c.branch == branch && c.section == section;
                });

                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                      content: Text('A class with $year - $branch Section $section already exists!'),
                      backgroundColor: Colors.red.shade800,
                    )
                  );
                  return;
                }

                final classModel = ClassModel(
                  id: existingClass?.id ?? '',
                  year: year,
                  branch: branch,
                  section: section,
                );
                
                if (isEditing) {
                  await ref.read(classServiceProvider).updateClass(classModel);
                } else {
                  await ref.read(classServiceProvider).addClass(classModel);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(isEditing ? 'Update' : 'Register'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final classService = ref.watch(classServiceProvider);

    return StreamBuilder<List<ClassModel>>(
      stream: classService.getClasses(),
      builder: (context, snapshot) {
        final classes = snapshot.data ?? [];
        
        // Generate unique items for dropdowns dynamically
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

        // Apply filters
        List<ClassModel> filteredClasses = classes.where((c) {
          if (_selectedYear != null && c.year != _selectedYear) return false;
          if (_selectedBranch != null && c.branch != _selectedBranch) return false;
          if (_selectedSection != null && c.section != _selectedSection) return false;
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          appBar: AppBar(
            title: const Text('Manage Classes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          body: snapshot.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : snapshot.hasError 
              ? Center(child: Text('Error: ${snapshot.error}'))
              : Column(
                  children: [
                    // Dynamic Filter Dropdowns
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
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
                      ),
                    ),
                    const Divider(height: 1),
                    
                    // Filtered List View
                    Expanded(
                      child: filteredClasses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.class_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(classes.isEmpty ? 'No classes exist. Add one!' : 'No classes match these filters.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredClasses.length,
                            itemBuilder: (context, index) {
                              final classItem = filteredClasses[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(classItem.year, style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text('${classItem.branch} - Sec ${classItem.section}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: const Text('Registered Class'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                    onPressed: () => _showAddEditDialog(classes, classItem),
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddEditDialog(classes),
            icon: const Icon(Icons.add),
            label: const Text('Add Class'),
            backgroundColor: Colors.blue.shade600,
          ),
        );
      },
    );
  }
}
