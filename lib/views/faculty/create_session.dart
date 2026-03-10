import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/session_model.dart';
import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';

class CreateSession extends ConsumerStatefulWidget {
  const CreateSession({super.key});

  @override
  ConsumerState<CreateSession> createState() => _CreateSessionState();
}

class _CreateSessionState extends ConsumerState<CreateSession> {
  final _subjectController = TextEditingController();
  final _sectionController = TextEditingController();
  final _radiusController = TextEditingController(text: '25');
  DateTime _selectedDate = DateTime.now();
  String _selectedTimeSlot = '09:00 AM - 10:00 AM';

  final List<String> _timeSlots = [
    '08:00 AM - 09:00 AM',
    '09:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
    '11:00 AM - 12:00 PM',
    '12:00 PM - 01:00 PM',
    '01:00 PM - 02:00 PM',
    '02:00 PM - 03:00 PM',
    '03:00 PM - 04:00 PM',
    '04:00 PM - 05:00 PM',
  ];

  Position? _currentPosition;
  bool _isLoading = false;

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() => _currentPosition = position);
  }

  Future<void> _submit() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please get current location first')));
      return;
    }

    final user = ref.read(userProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User profile not loaded')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final session = SessionModel(
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        subject: _subjectController.text,
        section: _sectionController.text,
        facultyUserId: user.userId, // Use the real, logged-in user ID
        facultyAuthUid: user.authUid ?? 'unknown',
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        timeSlot: _selectedTimeSlot,
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
        radius: double.parse(_radiusController.text),
        status: 'open',
        createdAt: DateTime.now(),
      );

      if (!AuthService.isPrototypeMode) {
        await FirebaseFirestore.instance
            .collection('class_sessions')
            .add(session.toMap());
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Session created successfully in Firebase'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error creating session: $e'),
          backgroundColor: Colors.red,
        ));
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Class Session')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
                controller: _subjectController,
                decoration: const InputDecoration(
                    labelText: 'Subject (e.g. Mathematics)')),
            const SizedBox(height: 16),
            TextField(
                controller: _sectionController,
                decoration:
                    const InputDecoration(labelText: 'Section (e.g. CSE-A)')),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Session Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null && picked != _selectedDate) {
                  setState(() {
                    _selectedDate = picked;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Time Slot'),
              initialValue: _selectedTimeSlot,
              items: _timeSlots.map((String slot) {
                return DropdownMenuItem<String>(
                  value: slot,
                  child: Text(slot),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedTimeSlot = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
                controller: _radiusController,
                decoration: const InputDecoration(labelText: 'Radius (meters)'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            ListTile(
              title: Text(_currentPosition == null
                  ? 'Location not set'
                  : 'Location Captured'),
              subtitle: Text(_currentPosition == null
                  ? 'Tap button to get GPS'
                  : 'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}'),
              trailing: IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: _getCurrentLocation),
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submit, child: const Text('Create Session')),
          ],
        ),
      ),
    );
  }
}
